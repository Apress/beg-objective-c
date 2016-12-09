//
//  APRemoteAddressBookWindowController.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-27.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "APRemoteAddressBookInterface.h"

@interface APRemoteAddressBookWindowController : NSWindowController <NSTableViewDelegate>

- (id) initWithRemoteAddressBook: (id<APRemoteAddressBook>) remoteAddressBook
                            name: (NSString *) serviceName;

@property (nonatomic, readonly) NSString * serviceName;
@property (nonatomic, assign) IBOutlet NSArrayController * peopleController;

@property (nonatomic, readonly) NSArray *personSortDescriptors;
@property (nonatomic, readonly) NSArray *labelSortDescriptors;

@property (nonatomic, readonly, getter=isLoadingPeople) BOOL loadingPeople;

@end
