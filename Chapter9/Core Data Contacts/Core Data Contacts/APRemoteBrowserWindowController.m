//
//  APRemoteBrowserWindowController.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-29.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APRemoteBrowserWindowController.h"

@implementation APRemoteBrowserWindowController

- (id) initWithServiceNames: (NSArray *) serviceNames
                   delegate: (id<APRemoteBrowserDelegate>) delegate
{
    self = [super initWithWindowNibName: [self className]];
    if ( self == nil )
        return ( nil );
    
    _serviceNames = [serviceNames sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    _delegate = delegate;
    
    return ( self );
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    // make double-clicking a row the same as selecting it and clicking 'Connect'
    [self.tableView setTarget: self];
    [self.tableView setDoubleAction: @selector(connect:)];
}

- (IBAction) connect: (id) sender
{
    NSString * name = [_serviceNames objectAtIndex: [self.tableView selectedRow]];
    [_delegate remoteBrowser: self connectToServiceNamed: name];
}

#pragma mark - NSTableViewDataSource Implementation

- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView
{
    return ( [_serviceNames count] );
}

- (id) tableView: (NSTableView *) tableView objectValueForTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row
{
    return ( [_serviceNames objectAtIndex: row] );
}

@end
