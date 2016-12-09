//
//  APAppDelegate.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-15.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "APRemoteAddressBookInterface.h"
#import "APRemoteBrowserWindowController.h"

@interface APAppDelegate : NSObject <NSApplicationDelegate, APAddressBook,
                                     NSTableViewDelegate, APRemoteBrowserDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSArrayController *peopleController;

@property (nonatomic, readonly) NSArray *personSortDescriptors;
@property (nonatomic, readonly) NSArray *labelSortDescriptors;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)saveAction:(id)sender;

- (IBAction)vendAddressBook:(id)sender;
- (IBAction)browseRemoteStores:(id)sender;
- (void)attachToRemoteAddressBookWithName:(NSString *)name
                                  handler:(void (^)(id<APRemoteAddressBook>, NSError *)) handler;

@end
