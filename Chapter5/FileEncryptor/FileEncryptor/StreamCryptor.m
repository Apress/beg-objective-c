//
//  StreamCryptor.m
//  FileEncryptor
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "StreamCryptor.h"
#import "SHAEncryptor.h"

@implementation StreamCryptor
{
    NSInputStream * _input;
    NSFileHandle * _output; // for simplicity vs. NSOutputStream for now
    SHAEncryptor * _cryptor;
    BOOL _encrypt;
}

- (id) initWithInputURL: (NSURL *) input outputURL: (NSURL *) output passPhrase: (NSString *) passPhrase encrypting: (BOOL) encrypting
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _input = [[NSInputStream alloc] initWithURL: input];
    
    if ( [[NSFileManager defaultManager] fileExistsAtPath: [output path]] == NO )
    {
        NSString * parentPath = [[output URLByDeletingLastPathComponent] path];
        if ( [[NSFileManager defaultManager] fileExistsAtPath: parentPath] == NO )
        {
            [[NSFileManager defaultManager] createDirectoryAtPath: parentPath withIntermediateDirectories: YES attributes: nil error: NULL];
        }
        
        // create the file so NSFileHandle can open it
        [[NSData data] writeToURL: output options: 0 error: NULL];
    }
    
    _output = [NSFileHandle fileHandleForWritingToURL: output error: NULL];
    
    _cryptor = [[SHAEncryptor alloc] initWithPassPhrase: passPhrase];
    _encrypt = encrypting;
    
    return ( self );
}

- (void) run
{
    [_input setDelegate: self];
    [_input scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
    [_input open];
}

- (void) stream: (NSStream *) aStream handleEvent: (NSStreamEvent) eventCode
{
    switch ( eventCode )
    {
        case NSStreamEventHasBytesAvailable:
        {
#define BUFLEN 8192
            uint8_t buf[BUFLEN];
            NSInteger numRead = [_input read: buf maxLength: BUFLEN];
            if ( numRead < 0 )
            {
                // signal an error and exit
                fprintf(stderr, "Unknown error reading from file!\n");
                CFRunLoopStop(CFRunLoopGetMain());
                break;
            }
            
            NSData * data = [[NSData alloc] initWithBytesNoCopy: buf length: numRead freeWhenDone: NO];
            if ( _encrypt )
                [_output writeData: [_cryptor encryptData: data]];
            else
                [_output writeData: [_cryptor decryptData: data]];
            
            break;
        }
            
        case NSStreamEventErrorOccurred:
        {
            // report the error and exit
            fprintf(stderr, "Error reading from file: %s\n", [[[aStream streamError] localizedDescription] UTF8String]);
            CFRunLoopStop(CFRunLoopGetMain());
            break;
        }
            
        case NSStreamEventEndEncountered:
        {
            // stop processing
            [_input close];
            NSData * finalData = [_cryptor finalData];
            if ( [finalData length] != 0 )
                [_output writeData: finalData];
            [_output synchronizeFile];
            [_output closeFile];
            CFRunLoopStop(CFRunLoopGetMain());
            break;
        }
            
        default:
            break;
    }
}

@end
