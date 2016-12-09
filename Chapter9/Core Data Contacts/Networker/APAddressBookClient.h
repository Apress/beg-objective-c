//
//  APAddressBookClient.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class APAddressBookClient;
@protocol APAddressBookClientDelegate <NSObject>
- (void) client: (APAddressBookClient *) client
  handleMessage: (NSDictionary *) message;
- (void) clientDisconnected: (APAddressBookClient *) client
                  withError: (NSError *) error;
@end

@interface APAddressBookClient : NSObject
- (id) initWithSocket: (CFSocketNativeHandle) sock
             delegate: (id<APAddressBookClientDelegate>) delegate;
- (void) sendData: (NSData *) data;
@end
