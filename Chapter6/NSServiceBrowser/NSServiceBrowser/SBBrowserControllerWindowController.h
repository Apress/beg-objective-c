//
//  SBBrowserControllerWindowController.h
//  NSServiceBrowser
//
//  Created by Jim Dovey on 12-06-14.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SBBrowserControllerWindowController : NSWindowController <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (strong) IBOutlet NSArrayController * servicesController;
@property (assign) IBOutlet NSArrayController * resolvedServicesController;

- (IBAction)editServices:(id)sender;

@end
