//
//  SHAEncryptor.m
//  FileEncryptor
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "SHAEncryptor.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation SHAEncryptor
{
    NSData * _passPhrase;
    
    // these are created on-demand
    CCCryptorRef _encryptor;
    CCCryptorRef _decryptor;
}

+ (NSString *) stringFromCryptorStatus: (CCCryptorStatus) status
{
    switch ( status )
    {
        case kCCSuccess:
            return ( @"Operation completed normally" );
        case kCCParamError:
            return ( @"Illegal parameter value" );
        case kCCBufferTooSmall:
            return ( @"Insufficient buffer provided for specified operation" );
        case kCCMemoryFailure:
            return ( @"Memory allocation failure" );
        case kCCAlignmentError:
            return ( @"Input size was not aligned properly" );
        case kCCDecodeError:
            return ( @"Input data did not decode or encrypt properly" );
        case kCCUnimplemented:
            return ( @"The requested function was not implemented for the current agorithm" );
        case kCCOverflow:
            return ( @"A buffer overrun was detected" );
        default:
            break;
    }
    
    return ( [NSString stringWithFormat: @"Unknown error %d", status] );
}

- (id) initWithPassPhrase: (NSString *) passPhrase
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    NSMutableData * passData = [[passPhrase dataUsingEncoding: NSUTF8StringEncoding] mutableCopy];
    // truncate, or pad with zeroes, to the right key length
    [passData setLength: kCCKeySizeAES256];
    _passPhrase = [passData copy];
    
    return ( self );
}

- (void) dealloc
{
    if ( _encryptor != NULL )
        CCCryptorRelease(_encryptor);
    if ( _decryptor != NULL )
        CCCryptorRelease(_decryptor);
}

- (NSData *) encryptData: (NSData *) data
{
    if ( _encryptor == NULL )
    {
        CCCryptorStatus status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, [_passPhrase bytes], kCCKeySizeAES256, NULL, &_encryptor);
        if ( status != kCCSuccess )
        {
            [NSException raise: NSInternalInconsistencyException format: @"Failed to create cryptor: %@.", [SHAEncryptor stringFromCryptorStatus: status]];
        }
    }
    
    // create a buffer to store the encrypted data
    NSMutableData * encrypted = [[NSMutableData alloc] initWithLength: [data length]];
    size_t numBytesEncrypted = 0;
    
    // encrypt and write the encrypted bytes into our buffer
    CCCryptorUpdate(_encryptor, [data bytes], [data length], [encrypted mutableBytes], [encrypted length], &numBytesEncrypted);
    
    // adjust the size of our data object to match the number of bytes returned
    [encrypted setLength: numBytesEncrypted];
    
    return ( [encrypted copy] );
}

- (NSData *) decryptData: (NSData *) data
{
    if ( _decryptor == NULL )
    {
        CCCryptorStatus status = CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, [_passPhrase bytes], kCCKeySizeAES256, NULL, &_decryptor);
        if ( status != kCCSuccess )
        {
            [NSException raise: NSInternalInconsistencyException format: @"Failed to create cryptor: %@.", [SHAEncryptor stringFromCryptorStatus: status]];
        }
    }
    
    // create a buffer to store the decrypted data
    NSMutableData * decrypted = [[NSMutableData alloc] initWithLength: [data length]];
    size_t numBytesDecrypted = 0;
    
    // encrypt and write the decrypted bytes into our buffer
    CCCryptorUpdate(_decryptor, [data bytes], [data length], [decrypted mutableBytes], [decrypted length], &numBytesDecrypted);
    
    // adjust the size of our data object to match the number of bytes returned
    [decrypted setLength: numBytesDecrypted];
    
    return ( [decrypted copy] );
}

- (NSData *) finalData
{
    CCCryptorRef cryptor = _encryptor;
    if ( cryptor == NULL )
        cryptor = _decryptor;
    if ( cryptor == NULL )
        return ( nil );
    
    // no more than a single block will be returned by CCCryptorFinal()
    NSMutableData * finalData = [[NSMutableData alloc] initWithLength: kCCBlockSizeAES128];
    size_t numReturned = 0;
    CCCryptorFinal(cryptor, [finalData mutableBytes], [finalData length], &numReturned);
    
    if ( numReturned == 0 )
        return ( nil );
    
    [finalData setLength: numReturned];
    return ( [finalData copy] );
}

@end
