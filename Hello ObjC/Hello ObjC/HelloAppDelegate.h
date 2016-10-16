//
//  HelloAppDelegate.h
//  Hello ObjC
//
//  Created by Jim Dovey on 12-02-03.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HelloAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (copy) NSString * userName;

@end
