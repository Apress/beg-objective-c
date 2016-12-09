//
//  NSError+APDictionaryRepresentation.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-08-01.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "NSError+APDictionaryRepresentation.h"

// Base-64 encode/decode
#import <Security/SecEncodeTransform.h>
#import <Security/SecDecodeTransform.h>

static NSString * APErrorDictionaryCodeKey = @"Code";
static NSString * APErrorDictionaryDomainKey = @"Domain";
static NSString * APErrorDictionaryUserInfoKey = @"UserInfo";
static NSString * APErrorEncodedKeyPrefix = @"com.apress.beginning-objective-c.base64.";

static NSString * Base64String(id<NSCoding> object)
{
    NSData * coded = [NSKeyedArchiver archivedDataWithRootObject: object];
    if ( coded == nil )
        return ( nil );
    
    SecTransformRef tx = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
    SecTransformSetAttribute(tx, kSecEncodeLineLengthAttribute, kSecLineLength64, NULL);
    SecTransformSetAttribute(tx, kSecTransformInputAttributeName, (__bridge CFDataRef)coded, NULL);
    
    CFErrorRef err = NULL;
    NSData * data = CFBridgingRelease(SecTransformExecute(tx, &err));
    CFRelease(tx);
    if ( data == nil )
    {
        NSLog(@"Base64 Encode Error: %@. Object = %@", err, object);
        return ( nil );
    }
    
    // render the data as a string
    return ( [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] );
}

static id Base64Decode(NSString * string)
{
    NSData * data = [string dataUsingEncoding: NSUTF8StringEncoding];
    SecTransformRef tx = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
    SecTransformSetAttribute(tx, kSecTransformInputAttributeName, (__bridge CFDataRef)data, NULL);
    
    CFErrorRef err = NULL;
    NSData * decoded = CFBridgingRelease(SecTransformExecute(tx, &err));
    CFRelease(tx);
    if ( data == nil )
    {
        NSLog(@"Base64 Encode Error: %@. Data = %@", err, data);
        return ( nil );
    }
    
    return ( [NSKeyedUnarchiver unarchiveObjectWithData: decoded] );
}

NSDictionary * EncodedDictionary(NSDictionary * source)
{
    NSMutableDictionary * result = [NSMutableDictionary new];
    [source enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        if ( [NSJSONSerialization isValidJSONObject: obj] == NO )
        {
            if ( [obj conformsToProtocol: @protocol(NSCoding)] == NO )
            {
                // use the description instead
                obj = [obj description];
            }
            else
            {
                // encode the object if possible
                NSString * str = Base64String(obj);
                if ( str == nil )
                {
                    // error encoding somewhere further down the chain
                    // use the description again
                    obj = [obj description];
                }
                else
                {
                    // it encoded nicely
                    obj = str;
                    
                    // modify the key to denote that this value is encoded
                    key = [APErrorEncodedKeyPrefix stringByAppendingString: key];
                }
            }
        }
        
        // place the key & value into the dictionary
        result[key] = obj;
    }];
    
    return ( result );
}

@implementation NSError (APDictionaryRepresentation)

+ (NSError *) errorWithJSONDictionaryRepresentation: (NSDictionary *) dictionary
{
    NSMutableDictionary * userInfo = [dictionary[APErrorDictionaryUserInfoKey] mutableCopy];
    if ( userInfo != nil )
    {
        NSArray * keys = [[userInfo allKeys] filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return ( [evaluatedObject hasPrefix: APErrorEncodedKeyPrefix] );
        }]];
        
        // declared __strong so we can modify key in ARC code
        for ( __strong NSString * key in keys )
        {
            NSString * encoded = userInfo[key];
            [userInfo removeObjectForKey: key];
            
            // get the original key...
            key = [key substringFromIndex: [APErrorEncodedKeyPrefix length]];
            // ... and the original value
            userInfo[key] = Base64Decode(encoded);
        }
    }
    
    return ( [NSError errorWithDomain: dictionary[APErrorDictionaryDomainKey]
                                 code: [dictionary[APErrorDictionaryCodeKey] integerValue]
                             userInfo: userInfo] );
}

- (NSDictionary *) jsonDictionaryRepresentation
{
    NSMutableDictionary * dict = [NSMutableDictionary new];
    dict[APErrorDictionaryCodeKey] = @([self code]);
    dict[APErrorDictionaryDomainKey] = [self domain];
    if ( [self userInfo] != nil )
    {
        dict[APErrorDictionaryUserInfoKey] = [self userInfo];
        
        if ( [NSJSONSerialization isValidJSONObject: dict] == NO )
            dict[APErrorDictionaryUserInfoKey] = EncodedDictionary([self userInfo]);
    }
    
    return ( [dict copy] );
}

@end
