//
//  VPDocument.m
//  VideoPlayer
//
//  Created by Jim Dovey on 2012-08-02.
//  Copyright (c) 2012 Apress, Inc. All rights reserved.
//

#import "VPDocument.h"
#import <QTKit/QTKit.h>

@implementation VPDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"VPDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL) autosavesInPlace
{
    return YES;
}

- (BOOL) readFromURL: (NSURL *) url
              ofType: (NSString *) typeName
               error: (NSError **) outError
{
    if ( [QTMovie canInitWithURL: url] == NO )
    {
        if ( outError != NULL )
        {
            // going out of our way to provide a useful error
            NSMutableDictionary * info = [NSMutableDictionary new];
            info[NSLocalizedDescriptionKey] = NSLocalizedString(@"Invalid Input", @"error description");
            info[NSLocalizedFailureReasonErrorKey] = [NSString stringWithFormat: NSLocalizedString(@"The file '%@' cannot be opened for playback by QuickTime.", @"error reason"), [url lastPathComponent]];
            info[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString(@"You can check that the file you selected is playable in the OS X QuickTime player, or using QuickLook in the Finder.", @"error suggestion");
            
            *outError = [NSError errorWithDomain: QTKitErrorDomain
                                            code: QTErrorIncompatibleInput
                                        userInfo: info];
        }
        
        return ( NO );
    }
    
    self.movie = [[QTMovie alloc] initWithURL: url error: outError];
    return ( self.movie != nil );
}

@end
