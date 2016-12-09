//
//  APServerSocket.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-08-20.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APServerSocket : NSObject <NSNetServiceDelegate>

- (id) initWithConnectionHandler: (void (^)(int newSocket)) handler;
- (void) close;

@property (readonly) NSNetService * netService;

@end
