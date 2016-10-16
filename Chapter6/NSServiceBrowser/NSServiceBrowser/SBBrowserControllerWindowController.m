//
//  SBBrowserControllerWindowController.m
//  NSServiceBrowser
//
//  Created by Jim Dovey on 12-06-14.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "SBBrowserControllerWindowController.h"
#import "SBAppDelegate.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

static void * SBSelectedServiceObserverContext = &SBSelectedServiceObserverContext;

@interface SBResolvedService : NSObject <NSNetServiceDelegate>
- (id) initWithNetService: (NSNetService *) netService;
@property (strong) NSString * name;
@property (strong) NSString * hostName;
@property (strong) NSString * IP4Address;
@property (strong) NSString * IP6Address;
@property (strong) NSString * TXTRecordString;
@property (assign) NSInteger port;
@end

@implementation SBBrowserControllerWindowController
{
    NSNetServiceBrowser *   _browser;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if ( self == nil )
        return ( nil );
    
    _browser = [[NSNetServiceBrowser alloc] init];
    [_browser setDelegate: self];
    [_browser scheduleInRunLoop: [NSRunLoop mainRunLoop] forMode: NSRunLoopCommonModes];
    
    return ( self );
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.servicesController addObserver: self forKeyPath: @"selection" options: NSKeyValueObservingOptionNew context: SBSelectedServiceObserverContext];
    [self.resolvedServicesController setSortDescriptors: @[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES] ]];
}

- (IBAction)editServices:(id)sender
{
    [SBAppDelegate showPreferencesWindow];
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context
{
    if ( context == SBSelectedServiceObserverContext )
    {
        // stop the browser
        [_browser stop];
        
        // remove all current resolvers
        NSArray * currentServices = [self.resolvedServicesController arrangedObjects];
        NSRange r = NSMakeRange(0, [currentServices count]);
        NSIndexSet * indexes = [NSIndexSet indexSetWithIndexesInRange: r];
        [self.resolvedServicesController removeObjectsAtArrangedObjectIndexes: indexes];
        
        // [object selection] returns a proxy object from which I can't get any useful info (i.e. is it actually valid)
        // [change objectForKey: NSChangeNewKey] always returns an NSNull instance (wtf?)
        
        // point the browser at the new type, if appropriate
        NSArray * selection = [object selectedObjects];
        if ( [selection count] != 0 )
        {
            // kick off the search
            SBServiceEntry * entry = [selection objectAtIndex: 0];
            [_browser searchForServicesOfType: entry.type inDomain: @""];
        }
        
        return;
    }
    
    // call super if possible/required
    if ( [[self superclass] instancesRespondToSelector: _cmd] )
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSNetServiceBrowser Delegation

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    id obj = [[SBResolvedService alloc] initWithNetService: aNetService];
    [self.resolvedServicesController addObject: obj];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    id obj = [[SBResolvedService alloc] initWithNetService: aNetService];
    [self.resolvedServicesController removeObject: obj];
}

@end

#pragma mark - NSNetService Info Object

@implementation SBResolvedService
{
    NSNetService * _service;
}

- (id) initWithNetService: (NSNetService *) netService
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _service = netService;
    self.name = [_service name];
    
    if ( [netService port] == -1 )
    {
        [_service setDelegate: self];
        [_service scheduleInRunLoop: [NSRunLoop mainRunLoop] forMode: NSRunLoopCommonModes];
        [_service resolveWithTimeout: 5.0];
    }
    else
    {
        [self netServiceDidResolveAddress: netService];
    }
    
    return ( self );
}

- (BOOL) isEqual: (id) object
{
    if ( [object isKindOfClass: [self class]] == NO )
        return ( NO );
    
    return ( [self.name isEqualToString: [object name]] );
}

- (void) netServiceDidResolveAddress: (NSNetService *) sender
{
    self.hostName = [sender hostName];
    self.port = [sender port];
    
    for ( NSData * sockaddrData in [sender addresses] )
    {
        const struct sockaddr_storage *pSockaddr = [sockaddrData bytes];
        switch ( pSockaddr->ss_family )
        {
            case AF_INET:
            {
                if ( self.IP4Address != nil )
                    break;
                
                char ip4buf[INET_ADDRSTRLEN] = {0};
                const struct sockaddr_in *pIn = [sockaddrData bytes];
                if ( inet_ntop(AF_INET, &pIn->sin_addr, ip4buf, INET_ADDRSTRLEN) != NULL )
                    self.IP4Address = [NSString stringWithUTF8String: ip4buf];
                
                break;
            }
                
            case AF_INET6:
            {
                if ( self.IP6Address != nil )
                    break;
                
                char ip6buf[INET6_ADDRSTRLEN] = {0};
                const struct sockaddr_in6 *pIn = [sockaddrData bytes];
                if ( inet_ntop(AF_INET6, &pIn->sin6_addr, ip6buf, INET6_ADDRSTRLEN) != NULL )
                    self.IP6Address = [NSString stringWithUTF8String: ip6buf];
                
                break;
            }
            
            default:
                break;
        }
    }
    
    NSData * txtData = [sender TXTRecordData];
    if ( txtData != nil )
    {
        NSDictionary * txtDictionary = [NSNetService dictionaryFromTXTRecordData: txtData];
        if ( txtDictionary != nil )
        {
            NSMutableString * str = [NSMutableString new];
            [txtDictionary enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
                NSString * valueStr = [[NSString alloc] initWithData: obj encoding: NSUTF8StringEncoding];
                if ( valueStr == nil )
                    valueStr = [obj description];
                [str appendFormat: @"%@=%@; ", key, valueStr];
            }];
            
            self.TXTRecordString = [str copy];
        }
    }
    
    if ( self.TXTRecordString == nil )
        self.TXTRecordString = @"";
}

@end
