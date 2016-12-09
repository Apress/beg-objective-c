//
//  main.m
//  Networker
//
//  Created by Jim Dovey on 2012-07-24.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "APRemoteAddressBookInterface.h"
#import "APRemoteAddressBookBrowser.h"
#import "APRemoteAddressBook.h"

@interface APXPCRemoteAddressBookBrowser : APRemoteAddressBookBrowser <NSXPCListenerDelegate>
@end

#pragma mark -

@implementation APXPCRemoteAddressBookBrowser

- (BOOL) listener: (NSXPCListener *) listener shouldAcceptNewConnection: (NSXPCConnection *) newConnection
{
    NSXPCInterface * myInterface = [NSXPCInterface interfaceWithProtocol: @protocol(APRemoteAddressBookBrowser)];
    
    // add proxy details for the return value of -connectToServiceWithName:
    NSXPCInterface * bookInterface = [NSXPCInterface interfaceWithProtocol: @protocol(APRemoteAddressBook)];
    // first argument of the reply block is to be sent as a proxy
    [myInterface setInterface: bookInterface
                  forSelector: @selector(connectToServiceWithName:replyHandler:)
                argumentIndex: 0
                      ofReply: YES];
    
    // proxy details for the object sent to -vendAddressBook:errorHandler:
    NSXPCInterface * addressBookInterface = [NSXPCInterface interfaceWithProtocol: @protocol(APAddressBook)];
    // first argument to the function is a proxy object
    [myInterface setInterface: addressBookInterface
                  forSelector: @selector(vendAddressBook:errorHandler:)
                argumentIndex: 0
                      ofReply: NO];
    
    newConnection.exportedInterface = myInterface;
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return ( YES );
}

@end

#pragma mark -

int main(int argc, const char *argv[])
{
    APXPCRemoteAddressBookBrowser * xpcDelegate = [APXPCRemoteAddressBookBrowser new];
    
    NSXPCListener * listener = [NSXPCListener serviceListener];
    listener.delegate = xpcDelegate;
    
    // this runs essentially forever
    [listener resume];
    
	return 0;
}
