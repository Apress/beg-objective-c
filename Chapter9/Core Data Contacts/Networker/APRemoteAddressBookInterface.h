//
//  APRemoteAddressBookInterface.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// NSError domain
extern NSString * const APRemoteAddressBookErrorDomain;

// error codes within our domain
typedef NS_ENUM(NSInteger, APRemoteAddressBookError)
{
    APRemoteAddressBookNoError,
    APRemoteAddressBookErrorServiceNotFound,
};

// defines the methods used to retrieve address book data, whether from the local
// instance via XPC or a remote instance via XPC and network.
@protocol APAddressBook <NSObject>
- (void) allPeople: (void (^)(NSArray *, NSError *)) reply;
- (void) mailingAddressesForPersonWithIdentifier: (NSString *) identifier
                                           reply: (void (^)(NSArray *, NSError *)) reply;
- (void) emailAddressesForPersonWithIdentifier: (NSString *) identifier
                                         reply: (void (^)(NSArray *, NSError *)) reply;
- (void) phoneNumbersForPersonWithIdentifier: (NSString *) identifier
                                       reply: (void (^)(NSArray *, NSError *)) reply;
@end

// A remote address book instance needs an additional command to shut down its network
// connection and reclaim any resources on both client and server sides.
@protocol APRemoteAddressBook <APAddressBook>
- (void) disconnect;
@end

// This is the primary interface vended by the XPC service
@protocol APRemoteAddressBookBrowser <NSObject>
- (void) vendAddressBook: (id<APAddressBook>) addressBook
            errorHandler: (void (^)(NSError *)) errorHandler;
- (void) availableServiceNames: (void (^)(NSArray *, NSError *)) reply;
- (void) connectToServiceWithName: (NSString *) name
                     replyHandler: (void (^)(id<APRemoteAddressBook>, NSError *)) replyHandler;
@end

#pragma mark - Implementation Details

// command keys
extern NSString * const APRemoteAddressBookCommandNameKey;
extern NSString * const APRemoteAddressBookCommandUUIDKey;
extern NSString * const APRemoteAddressBookCommandPersonIDKey;
extern NSString * const APRemoteAddressBookCommandValueKey;
extern NSString * const APRemoteAddressBookCommandErrorKey;

// command names
extern NSString * const APRemoteAddressBookCommandAllPeople;
extern NSString * const APRemoteAddressBookCommandGetMailingAddresses;
extern NSString * const APRemoteAddressBookCommandGetEmailAddresses;
extern NSString * const APRemoteAddressBookCommandGetPhoneNumbers;
extern NSString * const APRemoteAddressBookCommandReply;
