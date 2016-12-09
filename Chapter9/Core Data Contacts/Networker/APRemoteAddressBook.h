//
//  APRemoteAddressBook.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APRemoteAddressBookInterface.h"

@class APRemoteAddressBook;

@protocol APRemoteAddressBookDelegate <NSObject>
- (void) addressBookDidDisconnect: (APRemoteAddressBook *) book;
@end

@interface APRemoteAddressBook : NSObject <APRemoteAddressBook, NSStreamDelegate>
- (id) initWithResolvedService: (NSNetService *) resolvedService
                      delegate: (id<APRemoteAddressBookDelegate>) delegate;
@end