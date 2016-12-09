//
//  EmailAddress.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-16.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Address.h"

@class Person;

@interface EmailAddress : Address

@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) Person *person;

@end
