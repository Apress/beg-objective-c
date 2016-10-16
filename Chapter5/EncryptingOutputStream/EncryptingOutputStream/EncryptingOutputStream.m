//
//  EncryptingOutputStream.m
//  EncryptingOutputStream
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "EncryptingOutputStream.h"
#import "SimpleRunLoopSource.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation EncryptingOutputStream
{
    CCCryptorRef            _cryptor;
    NSFileHandle *          _output;
    SimpleRunLoopSource *   _source;
    id<NSStreamDelegate>    _delegate __weak;
    NSStreamEvent           _currentEvent;
    NSStreamStatus          _status;
    NSError *               _error;
}

- (id) initWithFileURL: (NSURL *) fileURL passPhrase: (NSString *) passPhrase
{
    NSParameterAssert([fileURL isFileURL]);
    NSParameterAssert([passPhrase length] != 0);
    
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    // get the password as data, padded/truncated to the AES256 key size
    NSMutableData * passData = [[passPhrase dataUsingEncoding: NSUTF8StringEncoding] mutableCopy];
    [passData setLength: kCCKeySizeAES256];
    
    if ( CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                         [passData bytes], [passData length], NULL, &_cryptor) != kCCSuccess )
    {
        return ( nil );
    }
    
    // NSFileHandle can't open a file that isn't there. Ensure the destination exists.
    if ( [[NSFileManager defaultManager] fileExistsAtPath: [fileURL path]] == NO )
        [[NSData data] writeToURL: fileURL options: 0 error: NULL];
    
    // open the output file
    _output = [NSFileHandle fileHandleForWritingToURL: fileURL error: NULL];
    
    // create the runloop source, with a simple handler
    _source = [[SimpleRunLoopSource alloc] initWithSourceHandler: ^{
        if ( _currentEvent == NSStreamEventOpenCompleted )
            _status = NSStreamStatusOpen;
        
        [_delegate stream: self handleEvent: _currentEvent];
        
        // always signal space-available for NSFileHandle-based streams, since NSFileHandles can always be written to
        _currentEvent = NSStreamEventHasSpaceAvailable;
        [_source signal];
    }];
    
    // the initial status of the stream
    _status = NSStreamStatusNotOpen;
    
    return ( self );
}

- (void) dealloc
{
    if ( _cryptor != NULL )
        CCCryptorRelease(_cryptor);
}

- (void) open
{
    _status = NSStreamStatusOpening;
    _currentEvent = NSStreamEventOpenCompleted;
    [_source signal];
}

- (NSInteger) write: (const uint8_t *) buffer maxLength: (NSUInteger) len
{
    // update our status to indicate we're in the middle of a write operation
    _status = NSStreamStatusWriting;
    
    // encrypt the data
    NSMutableData * encrypted = [[NSMutableData alloc] initWithLength: len];
    size_t numWritten = 0;
    CCCryptorStatus status = CCCryptorUpdate(_cryptor, buffer, len, [encrypted mutableBytes], len, &numWritten);
    if ( status != kCCSuccess )
    {
        // an error occurred-- note it, signal the condition, and return -1
        _error = [NSError errorWithDomain: @"CoreCryptoErrorDomain" code: status userInfo: nil];
        _status = NSStreamStatusError;
        _currentEvent = NSStreamEventErrorOccurred;
        [_source signal];       // tell the delegate about it
        return ( -1 );
    }
    
    // write this data out via the superclass
    [_output writeData: encrypted];
    
    // reset our status and return the length of the data we wrote (we wrote all of it)
    _status = NSStreamStatusOpen;
    return ( len );
}

- (void) close
{
    // write any final data first
    NSMutableData * final = [[NSMutableData alloc] initWithLength: kCCBlockSizeAES128];
    size_t numWritten = 0;
    if ( CCCryptorFinal(_cryptor, [final mutableBytes], [final length], &numWritten) == kCCSuccess && numWritten != 0 )
        [_output writeData: final];
    
    // flush any filesystem buffers to the disk and close the file
    [_output synchronizeFile];
    [_output closeFile];
    
    // update our status
    _status = NSStreamStatusClosed;
}

- (void) setDelegate: (id<NSStreamDelegate>) delegate
{
    _delegate = delegate;
}

- (id<NSStreamDelegate>) delegate
{
    return ( _delegate );
}

- (void) scheduleInRunLoop: (NSRunLoop *) aRunLoop forMode: (NSString *) mode
{
    [_source addToRunLoop: aRunLoop forMode: mode];
}

- (void) removeFromRunLoop: (NSRunLoop *) aRunLoop forMode: (NSString *) mode
{
    [_source removeFromRunLoop: aRunLoop forMode: mode];
}

- (NSStreamStatus) streamStatus
{
    return ( _status );
}

- (NSError *) streamError
{
    return ( _error );
}

@end
