//
//  APAppDelegate.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-15.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface APAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (readonly, strong, nonatomic) NSArray * personSortDescriptors;
@property (readonly, strong, nonatomic) NSArray * labelSortDescriptors;

- (IBAction)saveAction:(id)sender;

@end
