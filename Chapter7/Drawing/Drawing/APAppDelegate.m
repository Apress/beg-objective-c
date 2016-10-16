//
//  APAppDelegate.m
//  Drawing
//
//  Created by Jim Dovey on 2012-07-14.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APAppDelegate.h"
#import "APCustomView.h"

@implementation APAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    self.leftView.linear = YES;
    self.rightView.linear = NO;
}

@end
