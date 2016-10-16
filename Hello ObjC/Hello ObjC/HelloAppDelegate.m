//
//  HelloAppDelegate.m
//  Hello ObjC
//
//  Created by Jim Dovey on 12-02-03.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "HelloAppDelegate.h"

@implementation HelloAppDelegate

@synthesize window = _window;
@synthesize userName;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Fetch the current user's name as a default value
    self.userName = NSFullUserName();
}

@end
