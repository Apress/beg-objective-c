//
//  MailingAddress.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-16.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Address.h"

@class Person;

@interface MailingAddress : Address

@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * postalCode;
@property (nonatomic, retain) NSString * region;
@property (nonatomic, retain) NSString * street;
@property (nonatomic, retain) Person *person;

@end
