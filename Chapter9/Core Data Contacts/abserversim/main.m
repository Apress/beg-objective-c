//
//  main.m
//  abserversim
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <sysexits.h>
#import "APRemoteAddressBookBrowser.h"
#import "APRemoteAddressBook.h"
#import "NSError+APDictionaryRepresentation.h"

@interface APSystemAddressBook : NSObject <APAddressBook>
@end

@implementation APSystemAddressBook
{
    ABAddressBook *     _addressBook;
}

- (id) init
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _addressBook = [ABAddressBook addressBook];
    
    return ( self );
}

- (void) allPeople: (void (^)(NSArray *, NSError *)) reply
{
    NSMutableArray * result = [NSMutableArray new];
    for ( ABPerson * person in [[ABAddressBook addressBook] people] )
    {
        NSMutableDictionary * dict = [NSMutableDictionary new];
        dict[APRemoteAddressBookCommandPersonIDKey] = [person uniqueId];
        
        NSString * first = [person valueForProperty: kABFirstNameProperty];
        NSString * last = [person valueForProperty: kABLastNameProperty];
        
        if ( first != nil )
            dict[@"firstName"] = first;
        if ( last != nil )
            dict[@"lastName"] = last;
        
        [result addObject: [dict copy]];
    }
    
    reply(result, nil);
}

- (void) mailingAddressesForPersonWithIdentifier: (NSString *) identifier
                                           reply: (void (^)(NSArray *, NSError *)) reply
{
    ABPerson * person = (ABPerson *)[[ABAddressBook addressBook] recordForUniqueId: identifier];
    if ( person == nil )
    {
        reply([NSArray array], nil);
        return;
    }
    
    NSMutableArray * result = [NSMutableArray new];
    ABMultiValue * addresses = [person valueForProperty: kABAddressProperty];
    for ( NSUInteger i = 0, max = [addresses count]; i < max; i++ )
    {
        NSDictionary * addressInfo = [addresses valueAtIndex: i];
        
        NSMutableDictionary * address = [NSMutableDictionary new];
        address[@"label"] = ABLocalizedPropertyOrLabel([addresses labelAtIndex: i]);
        
        NSString * street = addressInfo[kABAddressStreetKey];
        NSString * city = addressInfo[kABAddressCityKey];
        NSString * region = addressInfo[kABAddressStateKey];
        NSString * country = addressInfo[kABAddressCountryKey];
        
        if ( street != nil )
            address[@"street"] = street;
        if ( city != nil )
            address[@"city"] = city;
        if ( region != nil )
            address[@"region"] = region;
        if ( country != nil )
            address[@"country"] = country;
        
        [result addObject: [address copy]];
    }
    
    reply(result, nil);
}

- (void) emailAddressesForPersonWithIdentifier: (NSString *) identifier
                                         reply: (void (^)(NSArray *, NSError *)) reply
{
    ABPerson * person = (ABPerson *)[[ABAddressBook addressBook] recordForUniqueId: identifier];
    if ( person == nil )
    {
        reply([NSArray array], nil);
        return;
    }
    
    NSMutableArray * result = [NSMutableArray new];
    ABMultiValue * emails = [person valueForProperty: kABEmailProperty];
    for ( NSUInteger i = 0, max = [emails count]; i < max; i++ )
    {
        NSMutableDictionary * email = [NSMutableDictionary new];
        email[@"label"] = ABLocalizedPropertyOrLabel([emails labelAtIndex: i]);
        email[@"email"] = [emails valueAtIndex: i];
        [result addObject: [email copy]];
    }
    
    reply(result, nil);
}

- (void) phoneNumbersForPersonWithIdentifier: (NSString *) identifier
                                       reply: (void (^)(NSArray *, NSError *)) reply
{
    ABPerson * person = (ABPerson *)[[ABAddressBook addressBook] recordForUniqueId: identifier];
    if ( person == nil )
    {
        reply([NSArray array], nil);
        return;
    }
    
    NSMutableArray * result = [NSMutableArray new];
    ABMultiValue * phones = [person valueForProperty: kABPhoneProperty];
    for ( NSUInteger i = 0, max = [phones count]; i < max; i++ )
    {
        NSMutableDictionary * phone = [NSMutableDictionary new];
        phone[@"label"] = ABLocalizedPropertyOrLabel([phones labelAtIndex: i]);
        phone[@"phoneNumber"] = [phones valueAtIndex: i];
        [result addObject: [phone copy]];
    }
    
    reply(result, nil);
}

@end

#pragma mark -

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        APSystemAddressBook * systemAddressBook = nil;
        systemAddressBook = [APSystemAddressBook new];
        
        APRemoteAddressBookBrowser * browser = nil;
        browser = [APRemoteAddressBookBrowser new];
        
        // this will cause it to advertise on the network, if it works
        [browser vendAddressBook: systemAddressBook errorHandler: ^(NSError * error) {
            if ( error != nil )
            {
                NSLog(@"Error vending service: %@", error);
                exit(EX_IOERR);
            }
        }];
        
        // handle SIGINT and SIGTERM
        __block BOOL stop = NO;
        dispatch_block_t terminator = ^{ stop = YES; };
        
        dispatch_source_t intSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,
                                                             SIGINT, 0,
                                                             dispatch_get_main_queue());
        dispatch_source_t termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,
                                                              SIGTERM, 0,
                                                              dispatch_get_main_queue());
        dispatch_source_set_event_handler(intSource, terminator);
        dispatch_source_set_event_handler(termSource, terminator);
        dispatch_resume(intSource);
        dispatch_resume(termSource);
        
        while (stop == NO )
        {
            @autoreleasepool
            {
                // this method returns each time a source is handled
                [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                         beforeDate: [NSDate distantFuture]];
            }
        }
        
        dispatch_source_cancel(intSource);
        dispatch_source_cancel(termSource);
    }
    
    return ( EX_OK );
}

