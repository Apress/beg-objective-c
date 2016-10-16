//
//  SBAppDelegate.h
//  NSServiceBrowser
//
//  Created by Jim Dovey on 12-06-14.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBBrowserControllerWindowController;

@interface SBAppDelegate : NSObject <NSApplicationDelegate>

+ (void)showPreferencesWindow;

- (IBAction)showPreferences:(id)sender;
- (IBAction)addNewService:(id)sender;

@property (assign) IBOutlet NSArrayController * knownServices;
@property (assign) IBOutlet NSWindow * preferencesWindow;

@property (strong) SBBrowserControllerWindowController * browserController;
@property (strong) NSString * addServiceType;
@property (strong) NSString * addServiceDescription;

@end

@interface SBServiceEntry : NSObject
@property (strong) NSString * type;
@property (strong) NSString * description;
@property (assign, getter=isCustomService) BOOL customService;
@end
