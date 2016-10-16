//
//  SBAppDelegate.m
//  NSServiceBrowser
//
//  Created by Jim Dovey on 12-06-14.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "SBAppDelegate.h"
#import "SBBrowserControllerWindowController.h"

@implementation SBServiceEntry
@end

@implementation SBAppDelegate

+ (void) showPreferencesWindow
{
    SBAppDelegate * delegate = [[NSApplication sharedApplication] delegate];
    [delegate showPreferences: nil];
}

+ (NSArray *) builtInServices
{
    NSDictionary * serviceDictionary = @{
        @"_afpovertcp._tcp" : @"AppleShare Servers",
        @"_smb._tcp" : @"Windows Sharing",
        @"_rfb._tcp" : @"Screen Sharing",
        @"_ssh._tcp" : @"Remote Login",
        @"_ftp._tcp" : @"FTP Servers",
        @"_http._tcp" : @"Web Servers",
        @"_printer._tcp" : @"LPR Printers",
        @"_ipp._tcp" : @"IPP Printers",
        @"_airport._tcp" : @"AirPort Base Stations",
        @"_presence._tcp" : @"iChat Buddies",
        @"_daap._tcp" : @"iTunes Libraries",
        @"_dpap._tcp" : @"iPhoto Libraries"
    };
    
    NSMutableArray * services = [NSMutableArray new];
    [serviceDictionary enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        SBServiceEntry * entry = [SBServiceEntry new];
        entry.type = key;
        entry.description = obj;
        entry.customService = NO;
        [services addObject: entry];
    }];
    
    return ( [services copy] );
}

+ (NSArray *) userServices
{
    NSDictionary * serviceDictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"user-services"];
    
    NSMutableArray * services = [NSMutableArray new];
    [serviceDictionary enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        SBServiceEntry * entry = [SBServiceEntry new];
        entry.type = key;
        entry.description = obj;
        entry.customService = YES;
        [services addObject: entry];
    }];
    
    return ( [services copy] );
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // setup the available services
    [self.knownServices setSortDescriptors: @[ [NSSortDescriptor sortDescriptorWithKey:@"type" ascending:YES] ]];
    [self.knownServices addObjects: [SBAppDelegate builtInServices]];
    [self.knownServices addObjects: [SBAppDelegate userServices]];
    [self.knownServices setSelectedObjects: [NSArray array]];
    
    self.browserController = [[SBBrowserControllerWindowController alloc] initWithWindowNibName: @"SBBrowserControllerWindowController"];
    [self.browserController showWindow: self];
    [self.browserController.servicesController addObjects: [self.knownServices arrangedObjects]];
}

- (IBAction)showPreferences:(id)sender
{
    if ( [[self.browserController window] attachedSheet] == self.preferencesWindow )
        return;
    
    [[NSApplication sharedApplication] beginSheet: self.preferencesWindow modalForWindow: [self.browserController window] modalDelegate: self didEndSelector: @selector(prefsDidClose) contextInfo: NULL];
}

- (IBAction)closePreferencesWindow:(id)sender
{
    [[NSApplication sharedApplication] endSheet: self.preferencesWindow];
}

- (void)prefsDidClose
{
    [self.preferencesWindow close];
}

- (IBAction)addNewService:(id)sender
{
    SBServiceEntry * entry = [SBServiceEntry new];
    entry.type = self.addServiceType;
    entry.description = self.addServiceDescription;
    [self.knownServices addObject: entry];
    [self.browserController.servicesController addObject: entry];
    
    NSMutableDictionary * dict = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"user-services"] mutableCopy];
    [dict setObject: self.addServiceDescription forKey: self.addServiceType];
    [[NSUserDefaults standardUserDefaults] setObject: dict forKey: @"user-services"];
}

@end
