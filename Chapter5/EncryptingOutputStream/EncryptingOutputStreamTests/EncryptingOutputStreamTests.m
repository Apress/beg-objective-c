//
//  EncryptingOutputStreamTests.m
//  EncryptingOutputStreamTests
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "EncryptingOutputStreamTests.h"
#import <EncryptingOutputStream/EncryptingOutputStream.h>
#import <CommonCrypto/CommonCryptor.h>
#import <pwd.h>
#import <grp.h>

static NSString * const kSecretMessage = @"A Secret Message";
static NSString * const kRunLoopMode = @"TestingStreamRunLoopMode";
static NSString * const kPassPhrase = @"Password";

@implementation EncryptingOutputStreamTests
{
    NSData * _data;
    NSUInteger _numSent;
}

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void) testStream
{
    NSURL * url = [NSURL fileURLWithPathComponents: @[NSHomeDirectory(), @"encryptionTest"]];
    EncryptingOutputStream * stream = [[EncryptingOutputStream alloc] initWithFileURL: url passPhrase: kPassPhrase];
    
    [stream setDelegate: self];
    [stream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: kRunLoopMode];
    [stream open];
    
    _data = [kSecretMessage dataUsingEncoding: NSUTF8StringEncoding];
    
    // run the runloop in our special mode until we're done
    do
    {
        @autoreleasepool
        {
            [[NSRunLoop currentRunLoop] runMode: kRunLoopMode beforeDate: [NSDate distantFuture]];
        }
        
    } while (_numSent < [_data length]);
    
    [stream close];     // writes the last blob of data
    
    // now open the output file directly and read it all
    NSData * data = [NSData dataWithContentsOfURL: url];
    NSMutableData * key = [[kPassPhrase dataUsingEncoding: NSUTF8StringEncoding] mutableCopy];
    [key setLength: kCCKeySizeAES256];
    
    NSMutableData * decrypted = [[NSMutableData alloc] initWithLength: [data length]];
    size_t dataOutMoved = 0;
    
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, [key bytes], [key length], NULL, [data bytes], [data length], [decrypted mutableBytes], [decrypted length], &dataOutMoved);
    STAssertEquals(status, kCCSuccess, @"Decryption failed!");
    
    [decrypted setLength: dataOutMoved];
    
    NSString * decryptedString = [[NSString alloc] initWithData: decrypted encoding: NSUTF8StringEncoding];
    STAssertEqualObjects(kSecretMessage, decryptedString, @"Expected decrypted message to be %@, but got %@", kSecretMessage, decryptedString);
    
    // clean up the test file
    if ( [[NSFileManager defaultManager] fileExistsAtPath: [url path]] )
        [[NSFileManager defaultManager] removeItemAtURL: url error: NULL];
}

- (NSString *) relativePathOfURL: (NSURL *) url forEnumerationLevel: (NSUInteger) level
{
    NSArray * components = [url pathComponents];
    NSRange r = {0};
    r.location = [components count] - (level + 1);
    r.length = ([components count] - r.location) - 1;
    return ( [NSString pathWithComponents: [components subarrayWithRange: r]] );
}

- (void) stream: (NSStream *) aStream handleEvent: (NSStreamEvent) eventCode
{
    NSOutputStream * output = (NSOutputStream *)aStream;
    switch ( eventCode )
    {
        case NSStreamEventHasSpaceAvailable:
        {
            NSInteger written = [output write: [_data bytes] maxLength: [_data length]];
            if ( written <= 0 )
            {
                _numSent = [_data length];
                STFail(@"Failed to write some data!");
                [aStream close];
                break;
            }
            
            _numSent += written;
            break;
        }
            
        case NSStreamEventErrorOccurred:
        {
            STFail(@"Stream error encountered: %@", [aStream streamError]);
            _numSent = [_data length];
            break;
        }
            
        default:
            break;
    }
}

@end
