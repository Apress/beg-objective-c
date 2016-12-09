//
//  APRemoteAddressBookBrowser.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-25.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APRemoteAddressBookInterface.h"
#import "APRemoteAddressBook.h"
#import "APAddressBookClient.h"

@interface APRemoteAddressBookBrowser : NSObject
    <APRemoteAddressBookBrowser, APAddressBookClientDelegate,
     APRemoteAddressBookDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@end
