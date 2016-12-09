//
//  APAddressBookClient.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APAddressBookClient.h"

@implementation APAddressBookClient
{
    id<APAddressBookClientDelegate> _delegate __weak;
    dispatch_io_t                   _io;
    
    NSUInteger                      _inputSize;
    dispatch_data_t                 _inputData;
}

- (id) initWithSocket: (CFSocketNativeHandle) sock
             delegate: (id<APAddressBookClientDelegate>) delegate
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    NSLog(@"Client attached");
    
    _io = dispatch_io_create(DISPATCH_IO_STREAM, sock,
                        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                        ^(int error) { close(sock); });
    [self initializeReader];
    
    _delegate = delegate;
    
    _inputSize = NSNotFound;        // 'not currently reading a message'
    _inputData = dispatch_data_empty;
    
    return ( self );
}

- (void) initializeReader
{
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    APAddressBookClient * weakSelf = self;
    dispatch_io_read(_io, 0, SIZE_MAX, q, ^(bool done, dispatch_data_t data, int err) {
        APAddressBookClient * client = weakSelf;
        if ( done )
        {
            id<APAddressBookClientDelegate> delegate = client->_delegate;
            NSError * error = nil;
            if ( err != 0 )
            {
                error = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: err
                                        userInfo: nil];
            }
            
            [delegate clientDisconnected: client withError: error];
            return;
        }
        
        if ( data != nil )
        {
            // append the data & trigger processing
            _inputData = dispatch_data_create_concat(_inputData, data);
            [self tryToProcessData];
        }
    });
}

- (BOOL) consumeInputOfLength: (size_t) length intoBuffer: (uint8_t *) buf
{
    NSParameterAssert(length != 0);
    NSParameterAssert(buf != NULL);
    
    size_t avail = dispatch_data_get_size(_inputData);
    if ( avail < length )
        return ( NO );
    
    __block size_t off = 0;
    dispatch_data_apply(_inputData, ^bool(dispatch_data_t region, size_t offset,
                                          const void *buffer, size_t size) {
        size_t left = length - off;
        memcpy(buf + off, buffer, left);
        off += left;
        return ( off < length );
    });
    
    size_t newLen = avail - length;
    if ( newLen == 0 )
        _inputData = dispatch_data_empty;
    else
        _inputData = dispatch_data_create_subrange(_inputData, length, newLen);
    
    return ( YES );
}

- (void) tryToProcessData
{
    if ( _inputSize == NSNotFound )
    {
        // need to read four bytes of size first
        union {
            uint32_t messageSize;
            uint8_t buf[4];
        } messageBuf;
        
        if ( [self consumeInputOfLength: 4 intoBuffer: messageBuf.buf] == NO )
            return;
        
        _inputSize = ntohl(messageBuf.messageSize);
    }
    
    // see if we already have enough data
    if ( dispatch_data_get_size(_inputData) < _inputSize )
        return;     // not enough there yet
    
    // otherwise, we can read the whole thing
    NSMutableData * data = [[NSMutableData alloc] initWithLength: _inputSize];
    [self consumeInputOfLength: _inputSize intoBuffer: [data mutableBytes]];
    
    // we've read everything, so dispatch the message and reset our ivars
    NSError * jsonError = nil;
    NSDictionary * message = [NSJSONSerialization JSONObjectWithData: data
                                                             options: 0
                                                               error: &jsonError];
    
    // set our size marker
    _inputSize = NSNotFound;
    
    if ( message == nil )
    {
        NSLog(@"Failed to decode message: %@", jsonError);
    }
    else
    {
        // dispatch the message
        [_delegate client: self handleMessage: message];
    }
    
    // is there more data? If so, recurse to handle it
    if ( dispatch_data_get_size(_inputData) > 0 )
        [self tryToProcessData];
}

- (void) sendData: (NSData *) data
{
    // the queue for all blocks here
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // we want a dispatch_data_t referencing this NSData object
    // the logical thing is to have the dispatch cleanup block reference & release
    //  the NSData, except we can't call -release on it under ARC. The solution is to
    //  bridge-cast the NSData to a manually-counted CFDataRef, which we can release.
    CFDataRef cfData = CFBridgingRetain(data);
    dispatch_data_t ddata = dispatch_data_create(CFDataGetBytePtr(cfData),
                                                 CFDataGetLength(cfData),
                                                 q, ^{ CFRelease(cfData); });
    
    dispatch_io_write(_io, 0, ddata, q, ^(bool done, dispatch_data_t d, int err) {
        if ( err != 0 )
        {
            NSError * error = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                  code: err
                                              userInfo: nil];
            NSLog(@"Failed to send data: %@", error);
            return;
        }
        else if ( done )
        {
            NSLog(@"Sent %lu bytes of data", CFDataGetLength(cfData));
        }
    });
}

@end
