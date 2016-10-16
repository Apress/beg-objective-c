//
//  Person.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-16.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class EmailAddress, MailingAddress;

@interface Person : NSManagedObject

@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, readonly) NSString * fullName;      // transient property
@property (nonatomic, retain) NSSet *emailAddresses;
@property (nonatomic, retain) NSSet *mailingAddresses;
@property (nonatomic, retain) NSSet *phoneNumbers;
@end

@interface Person (CoreDataGeneratedAccessors)

- (void)addEmailAddressesObject:(EmailAddress *)value;
- (void)removeEmailAddressesObject:(EmailAddress *)value;
- (void)addEmailAddresses:(NSSet *)values;
- (void)removeEmailAddresses:(NSSet *)values;

- (void)addMailingAddressesObject:(MailingAddress *)value;
- (void)removeMailingAddressesObject:(MailingAddress *)value;
- (void)addMailingAddresses:(NSSet *)values;
- (void)removeMailingAddresses:(NSSet *)values;

- (void)addPhoneNumbersObject:(NSManagedObject *)value;
- (void)removePhoneNumbersObject:(NSManagedObject *)value;
- (void)addPhoneNumbers:(NSSet *)values;
- (void)removePhoneNumbers:(NSSet *)values;

@end
