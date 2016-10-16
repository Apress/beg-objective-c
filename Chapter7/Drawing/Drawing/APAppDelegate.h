//
//  APAppDelegate.h
//  Drawing
//
//  Created by Jim Dovey on 2012-07-14.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class APCustomView;

@interface APAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet APCustomView * leftView;
@property (assign) IBOutlet APCustomView * rightView;

@end
