//
//  APAppDelegate.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-15.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APAppDelegate.h"
#import "APAddressBookImporter.h"

@implementation APAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (void) awakeFromNib
{
    SEL compareSelector = @selector(caseInsensitiveCompare:);
    if ( _personSortDescriptors == nil )
    {
        NSSortDescriptor * sortLast = nil, * sortFirst = nil;
        sortLast = [NSSortDescriptor sortDescriptorWithKey: @"lastName"
                                                 ascending: YES
                                                  selector: compareSelector];
        sortFirst = [NSSortDescriptor sortDescriptorWithKey: @"firstName"
                                                  ascending: YES
                                                   selector: compareSelector];
        
        [self willChangeValueForKey: @"personSortDescriptors"];
        _personSortDescriptors = @[sortLast, sortFirst];
        [self didChangeValueForKey: @"personSortDescriptors"];
    }
    if ( _labelSortDescriptors == nil )
    {
        NSSortDescriptor * sortLabel = nil;
        sortLabel = [NSSortDescriptor sortDescriptorWithKey: @"label"
                                                  ascending: YES
                                                   selector: compareSelector];
        [self willChangeValueForKey: @"labelSortDescriptors"];
        _labelSortDescriptors = @[sortLabel];
        [self didChangeValueForKey: @"labelSortDescriptors"];
    }
}

- (void)importAddressBookData
{
    APAddressBookImporter * importer = [[APAddressBookImporter alloc] initWithParentObjectContext: self.managedObjectContext];
    [importer beginImportingWithCompletion: ^(NSError *error) {
        if ( error != nil )
        {
            [NSApp presentError: error];
        }
        
        if ( [self.managedObjectContext hasChanges] )
        {
            [self.managedObjectContext performBlock: ^{
                NSError * saveError = nil;
                if ( [self.managedObjectContext save: &saveError] == NO )
                    [NSApp presentError: saveError];
            }];
        }
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
    // simple request: we just want all Person objects, so no predicates
    
    // we actually only want to know how many there are, so we use this special
    // method on NSManagedObjectContext:
    NSManagedObjectContext * context = [self managedObjectContext];
    [context performBlock: ^{
        // we don't care about the error-- if something goes wrong, we still
        // need to pull in some data
        NSUInteger count = [context countForFetchRequest: request error: NULL];
        if ( count == 0 )
        {
            // back out to the main thread-- don't hog the context's queue
            dispatch_async(dispatch_get_main_queue(), ^{
                [self importAddressBookData];
            });
        }
    }];
}

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "com.apress.beginning-objective-c.Core_Data_Contacts" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"com.apress.beginning-objective-c.Core_Data_Contacts"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Core_Data_Contacts" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Core_Data_Contacts_Simple.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _persistentStoreCoordinator = coordinator;
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];

    return _managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    [[self managedObjectContext] performBlock:^{
        NSError *error = nil;
        
        if (![[self managedObjectContext] commitEditing]) {
            NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
        }
        
        if (![[self managedObjectContext] save:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSApplication sharedApplication] presentError:error];
            });
        }
    }];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    __block NSApplicationTerminateReply reply = NSTerminateLater;
    [[self managedObjectContext] performBlockAndWait: ^{
        if (![[self managedObjectContext] commitEditing]) {
            NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
            reply = NSTerminateCancel;
        }
    }];
    
    if ( reply != NSTerminateLater )
        return reply;
    
    [[self managedObjectContext] performBlockAndWait: ^{
        if (![[self managedObjectContext] hasChanges]) {
            reply = NSTerminateNow;
        }
    }];
    
    if ( reply != NSTerminateLater )
        return reply;
    
    [[self managedObjectContext] performBlock: ^{
        NSError *error = nil;
        if (![[self managedObjectContext] save:&error]) {
            // failed to save the context-- jump back to the main thread
            // to perform UI work to make the decision. This can be either sync
            // or async, but async is generally a better idea.
            dispatch_async(dispatch_get_main_queue(), ^{
                // Customize this code block to include application-specific recovery steps.
                BOOL result = [sender presentError:error];
                if (result) {
                    // cancel termination, as before
                    [sender replyToApplicationShouldTerminate: NO];
                    return;
                }
                
                // Present a confirmation dialog to the user, and let them
                // make the decision for us.
                NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
                NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
                NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
                NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:question];
                [alert setInformativeText:info];
                [alert addButtonWithTitle:quitButton];
                [alert addButtonWithTitle:cancelButton];
                
                NSInteger answer = [alert runModal];
                
                // if the answer is NSAlertDefaultReturn then they clicked
                // the Quit button.
                [sender replyToApplicationShouldTerminate: (answer == NSAlertDefaultReturn)];
            });
        } else {
            // the context saved successfully, so we can terminate
            [sender replyToApplicationShouldTerminate: YES];
        }
    }];

    // we've dispatched an async save operation-- we'll decide if we can terminate
    // once we know how that turns out.
    return NSTerminateLater;
}

@end
