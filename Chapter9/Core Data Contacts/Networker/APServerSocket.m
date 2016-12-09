//
//  APServerSocket.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-08-20.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APServerSocket.h"

#import <sys/socket.h>
#import <netinet/in.h>

@interface APServerSocket ()
- (void) handleNewSocket: (int) newSocket;
@end

static void _ServerSocketCallback(CFSocketRef s, CFSocketCallBackType type,
                                  CFDataRef address, const void *data, void *info)
{
    APServerSocket * obj = (__bridge APServerSocket *)info;
    switch ( type )
    {
        case kCFSocketAcceptCallBack:
        {
            // pull out the new socket and pass it on
            int * socketPtr = (int *)data;
            [obj handleNewSocket: *socketPtr];
            break;
        }
            
        default:
            break;
    }
}

@implementation APServerSocket
{
    CFSocketRef     _serverSocket;
    NSNetService *  _netService;
    void            (^_connectionHandler)(int);
}

@synthesize netService=_netService;

- (id) initWithConnectionHandler: (void (^)(int)) handler
{
    NSParameterAssert(handler != nil);
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _connectionHandler = [handler copy];
    if ( [self initializeConnection] == NO )
        return ( nil );
    
    return ( self );
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    [_netService stop];
    
    if ( _serverSocket != NULL )
    {
        CFRelease(_serverSocket);
        _serverSocket = NULL;
    }
}

- (void) handleNewSocket: (int) newSocket
{
    _connectionHandler(newSocket);
}

- (BOOL) initializeConnection
{
    CFSocketContext ctx = {
        .version = 0,
        .info = (__bridge void *)self,
        .retain = NULL,
        .release = NULL,
        .copyDescription = CFCopyDescription
    };
    
    _serverSocket = CFSocketCreate(kCFAllocatorDefault, AF_INET6, SOCK_STREAM,
                                   IPPROTO_TCP, 0, _ServerSocketCallback, &ctx);
    if ( _serverSocket == NULL )
    {
        NSLog(@"Failed to create listening socket");
        return ( NO );
    }
    
    int val = 1;
    int socketFD = CFSocketGetNative(_serverSocket);
    if ( setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(int)) != 0 )
    {
        NSLog(@"Failed to set socket options");
        return ( NO );
    }
    
    struct sockaddr_in6 address = {0};
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
    address.sin6_addr = in6addr_any;
    address.sin6_port = 0;
    NSData * addressData = [[NSData alloc] initWithBytesNoCopy: &address
                                                        length: sizeof(address)
                                                  freeWhenDone: NO];
    
    if ( CFSocketSetAddress(_serverSocket, (__bridge CFDataRef)addressData) != kCFSocketSuccess )
    {
        NSLog(@"Failed to set server socket address");
        return ( NO );
    }
    
    // enable the accept callback and set it to automatically re-enable after each event
    CFSocketSetSocketFlags(_serverSocket, kCFSocketAutomaticallyReenableAcceptCallBack);
    CFSocketEnableCallBacks(_serverSocket, kCFSocketAcceptCallBack);
    
    // find out what port we were assigned
    socklen_t slen = sizeof(address);
    getsockname(socketFD, (struct sockaddr *)&address, &slen);
    
    UInt16 port = ntohs(address.sin6_port);
    _netService = [[NSNetService alloc] initWithDomain: @"" // default domain
                                                  type: @"_apad._tcp"
                                                  name: @"" // default name
                                                  port: port];
    [_netService scheduleInRunLoop: [NSRunLoop mainRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [_netService setDelegate: self];
    [_netService publishWithOptions: 0];
    
    return ( YES );
}

#pragma mark - Net Service Delegate

- (void) netService: (NSNetService *) sender didNotPublish: (NSDictionary *) errorDict
{
    NSLog(@"Failed to publish service %@: %@", sender, errorDict);
}

- (void) netServiceDidPublish: (NSNetService *) sender
{
    NSLog(@"Published network service %@", sender);
}

@end
