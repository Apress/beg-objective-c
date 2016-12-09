//
//  APRemoteAddressBookBrowser.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APRemoteAddressBookBrowser.h"
#import "APRemoteAddressBook.h"
#import "APAddressBookClient.h"
#import "APServerSocket.h"
#import "NSError+APDictionaryRepresentation.h"

@implementation APRemoteAddressBookBrowser
{
    NSNetServiceBrowser *       _browser;
    NSMutableDictionary *       _servicesByDomain;
    
    id<APAddressBook>           _localAddressBook;
    APServerSocket *            _serverSocket;
    
    NSMutableSet *              _clients;
    
    NSMutableSet *              _remoteAddressBooks;
    
    // NSNetService name string to handler blocks
    // this uses a map table so we can specify copy semantics for values
    NSMapTable *                _serviceResolutionHandlers;
}

- (id) init
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _servicesByDomain = [NSMutableDictionary new];
    _serviceResolutionHandlers = [[NSMapTable alloc]
        initWithKeyOptions: NSPointerFunctionsObjectPersonality|NSPointerFunctionsCopyIn
              valueOptions: NSPointerFunctionsObjectPersonality|NSPointerFunctionsCopyIn
                  capacity: 0];
    _clients = [NSMutableSet new];
    _remoteAddressBooks = [NSMutableSet new];
    
    _browser = [NSNetServiceBrowser new];
    [_browser setDelegate: self];
    [_browser searchForServicesOfType: @"_apad._tcp" inDomain: @""];
    
    return ( self );
}

- (void) dealloc
{
    [_serverSocket close];
    [_browser stop];
    [_servicesByDomain enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop){
        [obj makeObjectsPerformSelector: @selector(stop)];
    }];
}

- (void) vendAddressBook: (id<APAddressBook>) addressBook
            errorHandler: (void (^)(NSError *)) errorHandler
{
    if ( _serverSocket == nil )
    {
        // listen for incoming connections
        // fire up a new listening socket object with a new-connection handler block
        _serverSocket = [[APServerSocket alloc] initWithConnectionHandler: ^(int newSocket) {
            NSLog(@"Accepted new connection");
            
            APAddressBookClient * client = nil;
            client = [[APAddressBookClient alloc] initWithSocket: newSocket
                                                        delegate: self];
            [_clients addObject: client];
        }];
        
        if ( _serverSocket == nil )
        {
            errorHandler([NSError errorWithDomain: NSPOSIXErrorDomain
                                             code: errno
                                         userInfo: nil]);
            return;
        }
    }
    
    _localAddressBook = addressBook;
}

- (void) client: (APAddressBookClient *) client
  handleMessage: (NSDictionary *) command
{
    void (^dataHandler)(NSArray *, NSError *) = ^(NSArray * values, NSError * error) {
        NSMutableDictionary * result = [NSMutableDictionary new];
        NSUUID * uuid = command[APRemoteAddressBookCommandUUIDKey];
        result[APRemoteAddressBookCommandNameKey] = APRemoteAddressBookCommandReply;
        result[APRemoteAddressBookCommandUUIDKey] = uuid;
        if ( values != nil )
            result[APRemoteAddressBookCommandValueKey] = values;
        if ( error != nil )
            result[APRemoteAddressBookCommandErrorKey] = [error jsonDictionaryRepresentation];
        
        NSError * jsonError = nil;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject: result
                                                            options: 0
                                                              error: &jsonError];
        if ( jsonData == nil )
        {
            NSLog(@"Error building JSON reply: %@. Message = %@. Reply = %@",
                  jsonError, command, result);
            return;
        }
        
        // send the data asynchronously
        [client sendData: jsonData];
    };
    
    NSString * name = command[APRemoteAddressBookCommandNameKey];
    NSString * identifier = command[APRemoteAddressBookCommandPersonIDKey];
    
    if ( [name isEqualToString: APRemoteAddressBookCommandAllPeople] )
    {
        [_localAddressBook allPeople: dataHandler];
    }
    else if ( [name isEqualToString: APRemoteAddressBookCommandGetMailingAddresses] )
    {
        [_localAddressBook mailingAddressesForPersonWithIdentifier: identifier
                                                             reply: dataHandler];
    }
    else if ( [name isEqualToString: APRemoteAddressBookCommandGetEmailAddresses] )
    {
        [_localAddressBook emailAddressesForPersonWithIdentifier: identifier
                                                           reply: dataHandler];
    }
    else if ( [name isEqualToString: APRemoteAddressBookCommandGetPhoneNumbers] )
    {
        [_localAddressBook phoneNumbersForPersonWithIdentifier: identifier
                                                         reply: dataHandler];
    }
    else
    {
        id userInfo = @{ NSLocalizedDescriptionKey : @"Unknown command" };
        NSError * error = [NSError errorWithDomain: APRemoteAddressBookErrorDomain
                                              code: 101
                                          userInfo: userInfo];
        dataHandler(nil, error);
    }
}

- (void) clientDisconnected: (APAddressBookClient *) client withError: (NSError *) error
{
    // not doing anything with the error, which has already been logged.
    [_clients removeObject: client];
}

- (void) availableServiceNames: (void (^)(NSArray *, NSError *)) reply
{
    NSMutableSet * allNames = [NSMutableSet new];
    NSPredicate * nullFilter = [NSPredicate predicateWithBlock: ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if ( [evaluatedObject isKindOfClass: [NSNull class]] )
            return ( NO );
        return ( YES );
    }];
    
    [_servicesByDomain enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        NSArray * names = [obj valueForKey: @"name"];
        [allNames addObjectsFromArray: [names filteredArrayUsingPredicate: nullFilter]];
    }];
    
    // sort it
    NSArray * sorted = [[allNames allObjects] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    // post it back
    reply(sorted, nil);
}

- (void) connectToServiceWithName: (NSString *) name
                     replyHandler: (void (^)(id<APRemoteAddressBook>, NSError *)) replyHandler
{
    NSLog(@"Connecting to service named '%@'", name);
    __block NSNetService * selected = nil;
    
    // search individual domains -- look in "local" domain first, then any others
    NSMutableArray * localServices = _servicesByDomain[@"local."];
    NSLog(@"Searching local services: %@", localServices);
    for ( NSNetService * service in localServices )
    {
        if ( [[service name] isEqualToString: name] )
        {
            NSLog(@"Found local service: %@", service);
            selected = service;
            break;
        }
    }
    
    // if no local services were found, look in the other domains
    if ( selected == nil )
    {
        [_servicesByDomain enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            if ( [key isEqualToString: @"local."] )
                return;     // skip local domain, we've already looked there
            
            NSLog(@"Searching services in domain '%@': %@", key, obj);
            for ( NSNetService * service in obj )
            {
                if ( [[service name] isEqualToString: name] )
                {
                    NSLog(@"Found service: %@", service);
                    selected = service;
                    *stop = YES;
                    break;
                }
            }
        }];
    }
    
    // if none were found at all, send back an error
    if ( selected == nil )
    {
        NSDictionary * info = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"An address book service with the provided name could not be found.", @"error") };
        NSError * error = [NSError errorWithDomain: APRemoteAddressBookErrorDomain
                                              code: APRemoteAddressBookErrorServiceNotFound
                                          userInfo: info];
        replyHandler(nil, error);
        return;
    }
    
    // resolve if necessary then connect and send back a proxy
    if ( [selected hostName] == nil )
    {
        // resolve the service
        // take a copy of the 
        void (^replyCopy)(id<APRemoteAddressBook>, NSError *) = [replyHandler copy];
        
        // schedule it in the main run loop so the resolve success/failure will
        // trigger there -- this method is returning shortly
        [selected scheduleInRunLoop: [NSRunLoop mainRunLoop]
                            forMode: NSRunLoopCommonModes];
        
        // ensure it's got a delegate set, so we know whether it resolved or not
        [selected setDelegate: self];
        
        // store a block to handle the result of the service resolution
        __weak APRemoteAddressBookBrowser * weakSelf = self;
        [_serviceResolutionHandlers setObject: ^(NSError * error) {
            if ( error != nil )
            {
                replyCopy(nil, error);
                return;
            }
            
            // it resolved successfully
            APRemoteAddressBookBrowser * browser = weakSelf;
            APRemoteAddressBook * book = [[APRemoteAddressBook alloc]
                                          initWithResolvedService: selected delegate: browser];
            [browser->_remoteAddressBooks addObject: book];  // keep it alive
            NSLog(@"Resolved successfully, book = %@", book);
            replyCopy(book, nil);
        } forKey: [selected name]];
        
        // start the lookup
        [selected resolveWithTimeout: 10.0];
    }
    else
    {
        // it's already been resolved: just hook up a new connection
        APRemoteAddressBook * book = [[APRemoteAddressBook alloc]
                                      initWithResolvedService: selected delegate: self];
        [_remoteAddressBooks addObject: book];  // keep it alive
        NSLog(@"Resolved successfully, book = %@", book);
        replyHandler(book, nil);
    }
    
    // expect a reply or a timeout/resolution error
}

#pragma mark - APRemoteAddressBookDelegate Implementation

- (void) addressBookDidDisconnect: (APRemoteAddressBook *) book
{
    [_remoteAddressBooks removeObject: book];   // let it be released
}

#pragma mark - NSNetServiceBrowserDelegate Implementation

- (void) netServiceBrowser: (NSNetServiceBrowser *) aNetServiceBrowser
            didFindService: (NSNetService *) aNetService
                moreComing: (BOOL) moreComing
{
    NSMutableArray * servicesInDomain = _servicesByDomain[aNetService.domain];
    if ( servicesInDomain == nil )
    {
        servicesInDomain = [NSMutableArray new];
        _servicesByDomain[aNetService.domain] = servicesInDomain;
    }
    
    [servicesInDomain addObject: aNetService];
}

- (void) netServiceBrowser: (NSNetServiceBrowser *) aNetServiceBrowser
          didRemoveService: (NSNetService *) aNetService
                moreComing: (BOOL) moreComing
{
    [aNetService stop];
    NSMutableArray * servicesInDomain = _servicesByDomain[aNetService.domain];
    [servicesInDomain removeObject: aNetService];
}

#pragma mark - NSNetServiceDelegate Implementation

- (void) netServiceDidResolveAddress: (NSNetService *) sender
{
    void (^handler)(NSError *) = [_serviceResolutionHandlers objectForKey: [sender name]];
    if ( handler == nil )
        return;
    
    handler(nil);
    [_serviceResolutionHandlers removeObjectForKey: [sender name]];
}

- (void) netService: (NSNetService *) sender
      didNotResolve: (NSDictionary *) errorDict
{
    void (^handler)(NSError *) = [_serviceResolutionHandlers objectForKey: [sender name]];
    
    if ( handler == nil )
        return;
    
    // create an error object from the dictionary
    NSError * error = [NSError errorWithDomain: errorDict[NSNetServicesErrorDomain]
                                          code: [errorDict[NSNetServicesErrorCode] intValue]
                                      userInfo: nil];
    NSLog(@"Error resolving: %@", error);
    handler(error);
    
    [_serviceResolutionHandlers removeObjectForKey: [sender name]];
}

@end
