//
//  APRemoteBrowserWindowController.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-29.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class APRemoteBrowserWindowController;

@protocol APRemoteBrowserDelegate <NSObject>
- (void) remoteBrowser: (APRemoteBrowserWindowController *) browser
 connectToServiceNamed: (NSString *) serviceName;
@end

@interface APRemoteBrowserWindowController : NSWindowController

- (id) initWithServiceNames: (NSArray *) serviceNames
                   delegate: (id<APRemoteBrowserDelegate>) delegate;

@property (nonatomic, readonly) NSArray * serviceNames;
@property (nonatomic, assign) IBOutlet NSTableView * tableView;
@property (nonatomic, readonly, weak) id<APRemoteBrowserDelegate> delegate;

- (IBAction) connect: (id) sender;

@end
