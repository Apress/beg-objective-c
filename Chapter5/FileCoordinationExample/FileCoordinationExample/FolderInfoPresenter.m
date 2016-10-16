//
//  FolderInfoPresenter.m
//  FileCoordinationExample
//
//  Created by Jim Dovey on 12-06-05.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "FolderInfoPresenter.h"
#import "InfoFilePresenter.h"

@implementation FolderInfoPresenter
{
    NSURL *             _folderURL;
    
    // a pair of presenters, updated in alternation
    InfoFilePresenter * _infoFiles[2];
    NSUInteger          _whichFile;
    
    NSOperationQueue *  _queue;
    
    NSUInteger          _totalFileSize;
    NSUInteger          _totalAllocatedSize;
    
    BOOL                _suspended;
}

- (id) initWithFolderURL: (NSURL *) folderURL
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    // our private operation queue upon which the NSFilePresenter methods are called
    _queue = [NSOperationQueue new];
    
    _folderURL = [folderURL copy];
    
    NSURL * infoURL = [[[folderURL URLByDeletingLastPathComponent] URLByAppendingPathComponent: @"folder-info.txt"] copy];
    _infoFiles[0] = [[InfoFilePresenter alloc] initWithFileURL: infoURL queue: _queue];
    _infoFiles[1] = [[InfoFilePresenter alloc] initWithFileURL: infoURL queue: _queue];
    
    // register with the file coordination system
    [NSFileCoordinator addFilePresenter: self];
    
    [self updateFolderInfo];
    
    return ( self );
}

- (void) dealloc
{
    [_infoFiles[0] writeFile];
    [_infoFiles[1] writeFile];
}

- (void) updateInfoFile
{
    // print the details to stdout
    fprintf(stdout, "%s\n", [[NSString stringWithFormat: @"%@: %lu / %lu", [NSDate date], _totalFileSize, _totalAllocatedSize] UTF8String]);
    
    // update the info file with these items
    [_infoFiles[_whichFile] appendFileSize: _totalFileSize allocatedSize: _totalAllocatedSize];
    // toggle files
    _whichFile = (_whichFile + 1) % 2;
}

- (void) updateFolderInfo
{
    if ( _suspended )
        return;
    
    // create a file coordinator to synchronize our access to the folder's contents
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    
    // enumerate the file sizes and total allocated file sizes for all items within the folder
    NSArray * properties = @[ NSURLFileSizeKey, NSURLTotalFileAllocatedSizeKey ];
    
    // perform the read operation through the coordinator
    [coordinator coordinateReadingItemAtURL: _folderURL options: NSFileCoordinatorReadingWithoutChanges error: NULL byAccessor: ^(NSURL *newURL) {
        
        // we use the URL passed into this block rather than the _folderURL variable in case it has changed
        NSDirectoryEnumerator * dirEnum = [[NSFileManager defaultManager] enumeratorAtURL: newURL includingPropertiesForKeys: properties options: 0 errorHandler: ^BOOL(NSURL *url, NSError *error) {
            // ignore any errors for now
            return ( YES );
        }];
        
        _totalFileSize = 0;
        _totalAllocatedSize = 0;
        
        NSURL * subItemURL = nil;
        while ( (subItemURL = [dirEnum nextObject]) != nil )
        {
            NSDictionary * attrs = [subItemURL resourceValuesForKeys: properties error: NULL];
            _totalFileSize += [[attrs objectForKey: NSURLFileSizeKey] unsignedIntegerValue];
            _totalAllocatedSize += [[attrs objectForKey: NSURLTotalFileAllocatedSizeKey] unsignedIntegerValue];
        }
    }];
    
    // update our info text
    [self updateInfoFile];
    
    // the file coordinator instance doesn't stay around, since it retains the presenter
    // we let ARC release it for us when this method exits
}

#pragma mark - NSFilePresenter Protocol

- (NSURL *) presentedItemURL
{
    return ( _folderURL );
}

- (NSOperationQueue *) presentedItemOperationQueue
{
    return ( _queue );
}

- (void) relinquishPresentedItemToReader: (void (^)(void (^reacquirer)(void))) reader
{
    _suspended = YES;
    reader(^{ _suspended = NO; });
}

- (void) relinquishPresentedItemToWriter: (void (^)(void (^reacquirer)(void))) writer
{
    _suspended = YES;
    writer(^{ _suspended = NO; });
}

- (void) accommodatePresentedItemDeletionWithCompletionHandler: (void (^)(NSError *)) completionHandler
{
    fprintf(stdout, "Presented item was deleted, shutting down now.\n");
    completionHandler(NULL);
    
    // stop this application now, as the item we're presenting has been deleted
    CFRunLoopStop(CFRunLoopGetMain());
}

- (void) presentedItemDidMoveToURL: (NSURL *) newURL
{
    _folderURL = [newURL copy];
    fprintf(stdout, "Presented item moved to %s\n", [[newURL path] UTF8String]);
}

- (void) presentedSubitemDidAppearAtURL: (NSURL *) url
{
    // handled very simply: add the new item's sizes to our totals
    // Apple recommends that this occur via NSFileCoordinator coordinateReading...
    NSFileCoordinator * c = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    [c coordinateReadingItemAtURL: url options: NSFileCoordinatorReadingWithoutChanges error: NULL byAccessor: ^(NSURL *newURL) {
        NSDictionary * attrs = [url resourceValuesForKeys: @[NSURLFileSizeKey, NSURLTotalFileAllocatedSizeKey]
                                                    error: NULL];
        _totalFileSize += [[attrs objectForKey: NSURLFileSizeKey] unsignedIntegerValue];
        _totalAllocatedSize += [[attrs objectForKey: NSURLTotalFileAllocatedSizeKey] unsignedIntegerValue];
    }];
    
    // send the new details to the info file
    [self updateInfoFile];
}

- (void) presentedSubitemDidChangeAtURL: (NSURL *) url
{
    // we don't know the prior state of this sub-item, so we have to rebuild size from scratch.
    [self updateFolderInfo];
}

- (void) accommodatePresentedSubitemDeletionAtURL: (NSURL *) url completionHandler: (void (^)(NSError *)) completionHandler
{
    // we can handle this very simply: subtract this subitem's size from the totals
    // Apple recommends that this occur via NSFileCoordinator coordinateReading...
    NSFileCoordinator * c = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    [c coordinateReadingItemAtURL: url options: NSFileCoordinatorReadingWithoutChanges error: NULL byAccessor: ^(NSURL *newURL) {
        NSDictionary * attrs = [url resourceValuesForKeys: @[NSURLFileSizeKey, NSURLTotalFileAllocatedSizeKey]
                                                    error: NULL];
        _totalFileSize -= [[attrs objectForKey: NSURLFileSizeKey] unsignedIntegerValue];
        _totalAllocatedSize -= [[attrs objectForKey: NSURLTotalFileAllocatedSizeKey] unsignedIntegerValue];
    }];
    
    // update the info file (and write latest stats to stdout)
    [self updateInfoFile];
    
    // fire the completion handler so that the subitem can be deleted.
    completionHandler(NULL);
}

- (void) presentedSubitemAtURL: (NSURL *) url didMoveToURL: (NSURL *) newURL
{
    // not used in our info file, but we can log it to stdout
    fprintf(stdout, "Sub-item moved from %s to %s\n", [[url path] UTF8String], [[newURL path] UTF8String]);
}

@end
