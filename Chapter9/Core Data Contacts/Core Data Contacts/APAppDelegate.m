//
//  APAppDelegate.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-15.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APAppDelegate.h"
#import "APAddressBookImporter.h"
#import "APRemoteAddressBook.h"
#import "APRemoteAddressBookWindowController.h"

#import "Person.h"
#import "MailingAddress.h"
#import "EmailAddress.h"
#import "PhoneNumber.h"

// APRemoteAddressBook.m isn't a member of this target, so we will have to
// define this constant here so the app still links
NSString * const APRemoteAddressBookCommandPersonIDKey = @"personID";

@implementation APAppDelegate
{
    NSXPCConnection *               _xpcConnection;
    id<APRemoteAddressBookBrowser>  _browser;
    
    APRemoteBrowserWindowController *_browserWindow;
    NSMutableSet *                  _remoteBookWindows;
    NSMutableDictionary *           _remoteBookObservers;
}

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (void) awakeFromNib
{
    _remoteBookWindows = [NSMutableSet new];
    _remoteBookObservers = [NSMutableDictionary new];
    
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
#if 0
        if ( count != 0 )
        {
            for ( NSManagedObject * object in [context executeFetchRequest: request error: NULL] )
            {
                [context deleteObject: object];
            }
            
            [context save: NULL];
            count = 0;
        }
#endif
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
    
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Core_Data_Contacts.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];

    // see if we've successfully opened the store using ubiquity options before,
    // and if so, use them.
    NSDictionary * options = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"DataStoreUbiquityOptions"];
    NSPersistentStore * store = nil;
    store = [coordinator addPersistentStoreWithType: NSSQLiteStoreType
                                      configuration: nil
                                                URL: url
                                            options: options
                                              error: &error];
    if ( store == nil )
    {
        NSLog(@"Unable to initialize data store: %@", error);
        
        // if we passed in some iCloud options, try again without them
        if ( options != nil )
        {
            store = [coordinator addPersistentStoreWithType: NSSQLiteStoreType
                                              configuration: nil
                                                        URL: url
                                                    options: nil
                                                      error: &error];
            if ( store != nil )
            {
                // it worked, so zap the log directory for the Core Data sync
                // and we'll retry it with a different version later
                NSURL * containerURL = options[NSPersistentStoreUbiquitousContentURLKey];
                containerURL = [containerURL URLByAppendingPathComponent: options[NSPersistentStoreUbiquitousContentNameKey] isDirectory: YES];
                
                // delete this folder in a coordinated fashion
                NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
                [coordinator coordinateWritingItemAtURL: containerURL options: NSFileCoordinatorWritingForDeleting error: &error byAccessor:^(NSURL *newURL) {
                    NSError * fileError = nil;
                    if ( [[NSFileManager defaultManager] removeItemAtURL: newURL error: &fileError] == NO )
                    {
                        NSLog(@"Failed to remove transaction log folder: %@", fileError);
                    }
                }];
                
                // set this to nil to trigger a retry
                options = nil;
            }
        }
        
        if ( store == nil )
        {
            // it still didn't work!
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    // perhaps we can setup iCloud support now?
    if ( options == nil && [[NSFileManager defaultManager] ubiquityIdentityToken] != nil )
    {
        [self initializeUbiquityForStore: store];
    }

    _persistentStoreCoordinator = coordinator;

    return _persistentStoreCoordinator;
}

- (void) initializeUbiquityForStore: (NSPersistentStore *) store
{
    // fetching a ubiquity container URL from NSFileManager should not be
    // performed on the main thread, or so the documentation tells us
    // let's do this on a low-priority queue, then
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // passing 'nil' uses the first item in your app's container list
        NSURL * url = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier: nil];
        if ( url == nil )
            return;     // no ubiquity container
        
        NSURL * storeURL = [store URL];
        
        // see if we stored a ubiquity name already
        NSString * name = [[NSUserDefaults standardUserDefaults] stringForKey: @"UbiquitousContentName"];
        if ( name == nil )
        {
            // a unique name
            name = [[NSUUID UUID] UUIDString];
            // store it for later use
            [[NSUserDefaults standardUserDefaults] setObject: name forKey: @"UbiquitousContentName"];
        }
        
        // the options dictionary itself:
        NSDictionary * options = @{
            NSPersistentStoreUbiquitousContentNameKey : name,
            NSPersistentStoreUbiquitousContentURLKey : url
        };

        // remove the current store & re-add it with the new options
        // do all this in a context perform block to ensure nothing else
        // is modifying the store's contents during the swap
        NSManagedObjectContext * moc = self.managedObjectContext;
        [moc performBlock:^{
            if ( [moc hasChanges] )
            {
                NSError * saveError = nil;
                if ( [moc save: &saveError] == NO )
                    NSLog(@"Failed to save before upgrading store to iCloud: %@", saveError);
            }

            // remove the store while we're synchronized with the context
            NSError *storeError = nil;
            if ( [[moc persistentStoreCoordinator] removePersistentStore: store error: &storeError] == NO )
            {
                // if we fail to remove, we can't re-add with iCloud options
                NSLog(@"Failed to remove local store: %@", storeError);
                return;
            }

            NSPersistentStore * newStore = nil;
            newStore = [[moc persistentStoreCoordinator] addPersistentStoreWithType: NSSQLiteStoreType
                                                                      configuration: nil
                                                                                URL: storeURL
                                                                            options: options
                                                                              error: &storeError];
            if ( newStore == nil )
            {
                NSLog(@"Failed to add iCloud to store: %@", storeError);
                
                // re-open without iCloud -- we know this works
                [[moc persistentStoreCoordinator] addPersistentStoreWithType: NSSQLiteStoreType
                                                               configuration: nil
                                                                         URL: storeURL
                                                                     options: nil
                                                                       error: NULL];
                return;
            }

            // it opened successfully, so store the options dictionary for quick
            // retrieval upon next launch
            [[NSUserDefaults standardUserDefaults] setObject: options forKey: @"DataStoreUbiquityOptions"];
        }];
    });
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

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return ( YES );
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

#pragma mark - NSTableView Delegation

- (NSView *) tableView: (NSTableView *) tableView viewForTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row
{
    // this is the only way I can find to be able to look at the bound values here...
    NSDictionary * bindingInfo = [tableView infoForBinding: @"content"];
    id valueObject = bindingInfo[NSObservedObjectKey][row];
    if ( valueObject == nil )
        return ( nil );
    
    if ( [valueObject isKindOfClass: [MailingAddress class]] )
    {
        return ( [tableView makeViewWithIdentifier: @"Address" owner: self] );
    }
    else if ( [valueObject isKindOfClass: [EmailAddress class]] )
    {
        return ( [tableView makeViewWithIdentifier: @"Email" owner: self] );
    }
    else if ( [valueObject isKindOfClass: [PhoneNumber class]] )
    {
        return ( [tableView makeViewWithIdentifier: @"Phone" owner: self] );
    }
    
    return ( nil );
}

#pragma mark - Networked Stores

- (void) _initializeNetworker
{
    NSXPCInterface * interface = [NSXPCInterface interfaceWithProtocol: @protocol(APRemoteAddressBookBrowser)];
    
    // add proxy details for the return value of -connectToServiceWithName:
    NSXPCInterface * remoteBookInterface = [NSXPCInterface interfaceWithProtocol: @protocol(APRemoteAddressBook)];
    // first argument of the reply block is to be sent as a proxy
    [interface setInterface: remoteBookInterface
                forSelector: @selector(connectToServiceWithName:replyHandler:)
              argumentIndex: 0
                    ofReply: YES];
    
    // proxy details for the commandHandler object sent to -setCommandHandler:
    NSXPCInterface * localBookInterface = [NSXPCInterface interfaceWithProtocol: @protocol(APAddressBook)];
    // first argument to the function is a proxy object
    [interface setInterface: localBookInterface
                forSelector: @selector(setCommandHandler:errorHandler:)
              argumentIndex: 0
                    ofReply: NO];
    
    _xpcConnection = [[NSXPCConnection alloc] initWithServiceName: @"com.apress.beginning-objective-c.Networker"];
    _xpcConnection.remoteObjectInterface = interface;
    [_xpcConnection resume];
    _browser = [_xpcConnection remoteObjectProxyWithErrorHandler: ^(NSError * error) {
        _browser = nil;
        [NSApp presentError: error];
    }];
}

- (IBAction)vendAddressBook:(id)sender
{
    if ( _browser == nil )
        [self _initializeNetworker];
    
    // this will vend us on the network
    [_browser vendAddressBook: self errorHandler: ^(NSError *error) {
        if ( error != nil )
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp presentError: error];
            });
        }
    }];
}

- (IBAction)browseRemoteStores:(id)sender
{
    if ( _browser == nil )
        [self _initializeNetworker];
    
    [_browser availableServiceNames: ^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error != nil )
            {
                [NSApp presentError: error];
            }
            else
            {
                _browserWindow = [[APRemoteBrowserWindowController alloc] initWithServiceNames: result delegate: self];
                [_browserWindow showWindow: self];
            }
        });
    }];
}

- (void)attachToRemoteAddressBookWithName:(NSString *)name
                                  handler:(void (^)(id<APRemoteAddressBook>, NSError *)) handler;
{
    if ( _browser == nil )
        [self _initializeNetworker];
    
    [_browser connectToServiceWithName: name replyHandler: handler];
}

- (void) remoteBrowser: (APRemoteBrowserWindowController *) browser
 connectToServiceNamed: (NSString *) serviceName
{
    [self attachToRemoteAddressBookWithName: serviceName handler: ^(id<APRemoteAddressBook> book, NSError *error) {
        // we're modifying the UI, so do everything on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error != nil )
            {
                [NSApp presentError: error];
                return;
            }
            
            APRemoteAddressBookWindowController * remote = nil;
            remote = [[APRemoteAddressBookWindowController alloc] initWithRemoteAddressBook: book
                                                                                       name: serviceName];
            
            // close the browser window once we connect
            if ( remote != nil )
            {
                [browser close];
                if ( _browserWindow == browser )
                    _browserWindow = nil;
            }
            
            // show the remote window
            [remote showWindow: self];
            
            __weak APAppDelegate * weakSelf = self;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName: NSWindowWillCloseNotification object: [remote window] queue: [NSOperationQueue mainQueue] usingBlock: ^(NSNotification *note) {
                APAppDelegate * strongSelf = weakSelf;
                if ( strongSelf == nil )
                    return;
                
                [strongSelf->_remoteBookObservers removeObjectForKey: serviceName];
                [_remoteBookWindows removeObject: remote];
            }];
            
            // keep these alive
            [_remoteBookWindows addObject: remote];
            _remoteBookObservers[serviceName] = observer;
        });
    }];
}

- (NSString *) identifierForObject: (NSManagedObject *) object
                             error: (NSError **) error
{
    NSManagedObjectID * objectID = [object objectID];
    if ( [objectID isTemporaryID] )
    {
        // this might actually change, so request a permanent one
        if ( [self.managedObjectContext obtainPermanentIDsForObjects: @[object]
                                                               error: error] == NO )
        {
            // can't get a permanent ID, so return nil and the error
            return ( nil );
        }
        
        // get the new permanent objectID
        objectID = [object objectID];
    }
    
    return ( [[objectID URIRepresentation] absoluteString] );
}

- (NSManagedObjectID *) objectIDFromIdentifier: (NSString *) identifier
                                         error: (NSError **) error
{
    NSURL * objectURI = [[NSURL alloc] initWithString: identifier];
    if ( objectURI == nil )
    {
        if ( error != nil )
        {
            *error = [NSError errorWithDomain: NSURLErrorDomain
                                         code: NSURLErrorBadURL
                                     userInfo: nil];
        }
        
        return ( nil );
    }
    
    NSManagedObjectID * objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation: objectURI];
    if ( objectID == nil )
    {
        if ( error != nil )
        {
            *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                         code: NSManagedObjectReferentialIntegrityError
                                     userInfo: nil];
        }
        
        return ( nil );
    }
    
    return ( objectID );
}

- (void) allPeople: (void (^)(NSArray *, NSError *)) reply
{
    NSFetchRequest * req = [NSFetchRequest fetchRequestWithEntityName: @"Person"];
    [req setFetchBatchSize: 25];
    
    // ensure the reply block is on the heap
    reply = [reply copy];
    
    // no ordering, etc-- just fetch every Person instance
    [[self managedObjectContext] performBlock: ^{
        NSMutableArray * result = [NSMutableArray new];
        NSError * error = nil;
        NSArray * people = [[self managedObjectContext] executeFetchRequest: req
                                                                      error: &error];
        for ( Person * person in people )
        {
            NSString * identifier = [self identifierForObject: person error: NULL];
            if ( identifier == nil )
                continue;
            
            NSMutableDictionary * personInfo = [NSMutableDictionary new];
            personInfo[APRemoteAddressBookCommandPersonIDKey] = identifier;
            if ( person.firstName != nil )
                personInfo[@"firstName"] = person.firstName;
            if ( person.lastName != nil )
                personInfo[@"lastName"] = person.lastName;
            [result addObject: personInfo];
        }
        
        if ( [result count] == 0 )
            result = nil;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            reply(result, error);
        });
    }];
}

- (void) sendAttributesOfAddressEntityNamed: (NSString *) entityName
           associatedWithPersonIdentifiedBy: (NSString *) personID
                                    toBlock: (void (^)(NSArray *, NSError *)) reply
{
    NSError * error = nil;
    NSManagedObjectID * objectID = [self objectIDFromIdentifier: personID
                                                          error: &error];
    if ( objectID == nil )
    {
        reply(nil, error);
        return;
    }
    
    NSEntityDescription * entity = [NSEntityDescription entityForName: entityName
                                               inManagedObjectContext: self.managedObjectContext];
    
    NSFetchRequest * req = [NSFetchRequest new];
    [req setEntity: entity];
    [req setResultType: NSDictionaryResultType];
    [req setPropertiesToFetch: [[entity attributesByName] allKeys]];
    [req setPredicate: [NSPredicate predicateWithFormat: @"person == %@", objectID]];
    
    // ensure the reply block is on the heap
    reply = [reply copy];
    
    [self.managedObjectContext performBlock: ^{
        // the fetch request will return an array of dictionaries for us, all ready
        // to send to our caller
        NSError * error = nil;
        NSArray * result = [self.managedObjectContext executeFetchRequest: req
                                                                    error: &error];
        
        // let the object context carry on while doing XPC transfers
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            reply(result, error);
        });
    }];
}

- (void) mailingAddressesForPersonWithIdentifier: (NSString *) identifier
                                           reply: (void (^)(NSArray *, NSError *)) reply
{
    [self sendAttributesOfAddressEntityNamed: @"MailingAddress"
            associatedWithPersonIdentifiedBy: identifier
                                     toBlock: reply];
}

- (void) emailAddressesForPersonWithIdentifier: (NSString *) identifier
                                         reply: (void (^)(NSArray *, NSError *)) reply
{
    [self sendAttributesOfAddressEntityNamed: @"EmailAddress"
            associatedWithPersonIdentifiedBy: identifier
                                     toBlock: reply];
}

- (void) phoneNumbersForPersonWithIdentifier: (NSString *) identifier
                                       reply: (void (^)(NSArray *, NSError *)) reply
{
    [self sendAttributesOfAddressEntityNamed: @"PhoneNumber"
            associatedWithPersonIdentifiedBy: identifier
                                     toBlock: reply];
}

@end
