//
//  InfoFilePresenter.m
//  FileCoordinationExample
//
//  Created by Jim Dovey on 12-06-06.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "InfoFilePresenter.h"

@interface InfoLogEntry : NSObject
- (id) initWithFileSize: (NSUInteger) fileSize allocatedSize: (NSUInteger) allocatedSize;
- (id) initWithLogLine: (NSString *) logLine;
- (NSComparisonResult) compare: (InfoLogEntry *) obj;
- (BOOL) isEqual: (id) object;
@end

@implementation InfoFilePresenter
{
    NSURL *             _fileURL;
    NSMutableArray *    _logEntries;
    NSUInteger          _firstNewItemIndex;
    NSOperationQueue *  _queue;
    BOOL                _dirty;     // whether we have data we've not yet saved
    BOOL                _suspended;
    BOOL                _deferredWrite;
    BOOL                _deferredRead;
}

- (id) initWithFileURL: (NSURL *) fileURL queue: (NSOperationQueue *) queue
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _fileURL = fileURL;
    _logEntries = [NSMutableArray new];
    _queue = queue;
    
    _firstNewItemIndex = NSNotFound;
    
    [NSFileCoordinator addFilePresenter: self];
    
    // load the initial log string, if there is one
    if ( [[NSFileManager defaultManager] fileExistsAtPath: [_fileURL path]] == NO )
        [[NSData data] writeToURL: _fileURL options: 0 error: NULL];
    else
        [self loadFile];
    
    return ( self );
}

- (void) importEntriesFromString: (NSString *) string
{
    @synchronized(self)
    {
        // convert to the proper type, one log entry per line
        NSMutableArray * list = [[NSMutableArray alloc] initWithCapacity: [_logEntries count]];
        
        // prune all previously-saved items from our in-memory list
        if ( _firstNewItemIndex >= [_logEntries count] )
        {
            [_logEntries removeAllObjects];
        }
        else
        {
            [_logEntries removeObjectsInRange: NSMakeRange(0, _firstNewItemIndex)];
        }
        
        // insert new items at the head of the list
        [string enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
            [list addObject: [[InfoLogEntry alloc] initWithLogLine: line]];
        }];
        
        if ( [_logEntries count] > 0 )
        {
            _firstNewItemIndex = [list count];
            [list addObjectsFromArray: _logEntries];
        }
        
        [_logEntries setArray: list];
    }
}

- (void) loadFile
{
    if ( _suspended )
    {
        // note the read attempt so it'll go through later
        _deferredRead = YES;
        return;
    }
    
    __block NSString * content = nil;
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    [coordinator coordinateReadingItemAtURL: _fileURL options: 0 error: NULL byAccessor: ^(NSURL *newURL) {
        content = [[NSString alloc] initWithContentsOfURL: newURL encoding: NSUTF8StringEncoding error: NULL];
    }];
    
    @synchronized(self)
    {
        // pull the contents of the string into our entry list
        [self importEntriesFromString: content];
        
        // sort the entries
        [_logEntries sortUsingSelector: @selector(compare:)];
    }
}

- (void) writeFile
{
    if ( !_dirty )
        return;     // nothing to write
    
    if ( _suspended )
    {
        // don't write, there's something else reading/writing right now
        _deferredWrite = YES;
        return;
    }
    
    _dirty = NO;
    
    // Read the existing content before pushing out our changes. We do this because
    // it might have been modified by an application which doesn't adopt the NSFileCoordination
    // facilities.
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    [coordinator coordinateReadingItemAtURL: _fileURL options: 0 writingItemAtURL: _fileURL options: 0 error: NULL byAccessor: ^(NSURL *newReadingURL, NSURL *newWritingURL) {
        
        // read the file to ensure we have the latest data
        NSString * content = [[NSString alloc] initWithContentsOfURL: newReadingURL encoding: NSUTF8StringEncoding error: NULL];
        
        @synchronized(self)
        {
            [self importEntriesFromString: content];
            
            // write out the new data
            NSMutableString * output = [NSMutableString new];
            for ( InfoLogEntry * entry in _logEntries )
            {
                [output appendFormat: @"%@\n", entry];
            }
            
            [output writeToURL: newWritingURL atomically: YES encoding: NSUTF8StringEncoding error: NULL];
            _firstNewItemIndex = NSNotFound;
        }
    }];
}

- (void) appendFileSize: (NSUInteger) fileSize allocatedSize: (NSUInteger) allocatedSize
{
    if ( _firstNewItemIndex > [_logEntries count] )
        _firstNewItemIndex = [_logEntries count];
    
    InfoLogEntry * entry = [[InfoLogEntry alloc] initWithFileSize: fileSize allocatedSize: allocatedSize];
    @synchronized(self)
    {
        [_logEntries addObject: entry];
        _dirty = YES;
    }
}

#pragma mark - NSFilePresenter Protocol (Single File)

- (NSURL *) presentedItemURL
{
    return ( _fileURL );
}

- (NSOperationQueue *) presentedItemOperationQueue
{
    return ( _queue );
}

- (void) relinquishPresentedItemToReader: (void (^)(void (^reacquirer)(void))) reader
{
    fprintf(stdout, "Relinquishing file to reader.\n");
    _suspended = YES;
    reader(^{
        _suspended = NO;
        if ( _deferredRead )
        {
            _deferredRead = NO;
            [self loadFile];
        }
        if ( _deferredWrite )
        {
            // there was a request to write the file while we were suspended
            // fire off the operation now
            _deferredWrite = NO;
            [self writeFile];
        }
    });
}

- (void) relinquishPresentedItemToWriter: (void (^)(void (^reacquirer)(void))) writer
{
    fprintf(stdout, "Relinquishing to writer.\n");
    _suspended = YES;
    // load the new data after the writer's complete
    writer(^{
        _suspended = NO;
        
        // we always reload at this point
        _deferredRead = NO;
        [self loadFile];
        
        if ( _deferredWrite )
        {
            // there was a request to write the file while we were suspended
            // fire off the operation now
            _deferredWrite = NO;
            [self writeFile];
        }
    });
}

- (void) savePresentedItemChangesWithCompletionHandler: (void (^)(NSError *)) completionHandler
{
    fprintf(stdout, "Saving changes.\n");
    [self writeFile];
            
    // call the completion handler to tell the world we're done
    completionHandler(NULL);
}

- (void) accommodatePresentedItemDeletionWithCompletionHandler: (void (^)(NSError *)) completionHandler
{
    fprintf(stdout, "FolderInfo file being deleted.\n");
    // deletion is relatively simple for us to handle-- we'll ensure we've got the latest contents cached in memory
    // and let it go
    [self loadFile];
    completionHandler(NULL);
}

- (void) presentedItemDidMoveToURL: (NSURL *) newURL
{
    // store the new URL
    _fileURL = [newURL copy];
}

- (void) presentedItemDidChange
{
    // load the new contents
    [self loadFile];
}

@end

#pragma mark -

@implementation InfoLogEntry
{
    NSUInteger  _fileSize;
    NSUInteger  _allocatedSize;
    NSDate *    _date;
}

+ (NSDateFormatter *) dateFormatter
{
    static NSDateFormatter * __formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __formatter = [[NSDateFormatter alloc] init];
        [__formatter setDateFormat: @"yyyy/MM/dd HH:mm:ss.SSSS"];
    });
    return ( __formatter );
}

- (id) initWithFileSize: (NSUInteger) fileSize allocatedSize: (NSUInteger) allocatedSize
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _fileSize = fileSize;
    _allocatedSize = allocatedSize;
    _date = [NSDate date];
    
    return ( self );
}

- (id) initWithLogLine: (NSString *) logLine
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    NSScanner * scanner = [[NSScanner alloc] initWithString: logLine];
    NSMutableString * builder = [NSMutableString new];
    
    // WARNING:
    // This is very brittle code. It's close to midnight, I'm behind schedule, so I'm ot doing any error handling.
    // Your task, should you accept it, is to adapt this method to gracefully handle all sorts of dodgy input.
    
    NSString * tmp = nil;
    [scanner scanUpToString: @" " intoString: &tmp];
    [scanner setScanLocation: [scanner scanLocation]+1];
    [builder appendString: tmp];
    
    [scanner scanUpToString: @": " intoString: &tmp];
    [builder appendFormat: @" %@", tmp];
    
    // this bit is the date
    _date = [[InfoLogEntry dateFormatter] dateFromString: builder];
    
    // skip the ': ' string
    [scanner setScanLocation: [scanner scanLocation]+2];
    
    // read an unsigned integer
    // NSScanner doesn't scan unsigned types by default, so we get a string & use libc
    [scanner scanUpToString: @" / " intoString: &tmp];
    _fileSize = strtoul([tmp UTF8String], NULL, 10);
    
    // skip ' / '
    [scanner setScanLocation: [scanner scanLocation] + 3];
    [scanner scanCharactersFromSet: [NSCharacterSet decimalDigitCharacterSet] intoString: &tmp];
    _allocatedSize = strtoul([tmp UTF8String], NULL, 10);
    
    return ( self );
}

- (NSString *) description
{
    NSDateFormatter * formatter = [InfoLogEntry dateFormatter];
    return ( [NSString stringWithFormat: @"%@: %lu / %lu", [formatter stringFromDate: _date], _fileSize, _allocatedSize] );
}

- (NSComparisonResult) compare: (InfoLogEntry *) obj
{
    return ( [_date compare: obj->_date] );
}

- (BOOL) isEqual: (id) object
{
    if ( [object isMemberOfClass: [self class]] == NO )
        return ( NO );
    
    InfoLogEntry * entry = object;
    if ( [_date isEqual: entry->_date] == NO )
        return ( NO );
    
    return ( _fileSize == entry->_fileSize && _allocatedSize == entry->_allocatedSize );
}

@end
