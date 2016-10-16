//
//  main.m
//  PerformSpotlightSearch
//
//  Created by Jim Dovey on 12-06-05.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import <sysexits.h>
#import <CoreServices/CoreServices.h>

@interface MetadataSearcher : NSObject
- (id) initWithPredicate: (NSPredicate *) predicate maxResults: (NSUInteger) maxResults;
- (void) performQuery;
@end

@implementation MetadataSearcher
{
    NSMetadataQuery *   _query;
    NSUInteger          _maxResults;
}

- (id) initWithPredicate: (NSPredicate *) predicate maxResults: (NSUInteger) maxResults
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _maxResults = maxResults;
    _query = [[NSMetadataQuery alloc] init];
    [_query setPredicate: predicate];
    
    // limit search to local volumes, not across the network
    [_query setSearchScopes: @[NSMetadataQueryLocalComputerScope]];
    // sort results by path
    [_query setSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: NSMetadataItemPathKey ascending: YES]]];
    // group results by their type-- we will have to get a display string from the UTI value here
    [_query setGroupingAttributes: @[(__bridge id)kMDItemContentType]];
    
    // register to receive notifications when result gathering starts, progresses, and completes.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(gatheringStarted)
                                                 name: NSMetadataQueryDidStartGatheringNotification
                                               object: _query];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(gatherProgressing)
                                                 name: NSMetadataQueryGatheringProgressNotification
                                               object: _query];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(gatherComplete)
                                                 name: NSMetadataQueryDidFinishGatheringNotification
                                               object: _query];
    
    return ( self );
}

- (void) gatheringStarted
{
    fprintf(stderr, "Gathering results...");        // no newline on purpose
}

- (void) gatherProgressing
{
    fprintf(stderr, "...");     // again, no newline on purpose
}

- (void) gatherComplete
{
    fprintf(stderr, "done.\n");     // NOW we have the newline
    fflush(stderr);
    
    // pause live updating
    [_query disableUpdates];
    
    for ( NSMetadataQueryResultGroup * group in [_query groupedResults] )
    {
        NSString * groupValue = [group value];
        NSString * type = CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef)groupValue));
        if ( type == nil )
            type = [NSString stringWithFormat: @"Unknown type (.%@ file)", CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)groupValue, kUTTagClassFilenameExtension))];
        else
            type = [type capitalizedString];
        fprintf(stdout, "%s:\n", [type UTF8String]);
        
        NSUInteger max = MIN(_maxResults, [group resultCount]);
        if ( max == 0 )
            max = [group resultCount];
        
        for ( NSUInteger i = 0; i < max; i++ )
        {
            NSMetadataItem * item = [group resultAtIndex: i];
            fprintf(stdout, "  %s\n", [[item valueForAttribute: NSMetadataItemPathKey] UTF8String]);
        }
    }
    
    fflush(stdout);
    
    // resume live updates but stop the query in general
    [_query enableUpdates];
    [_query stopQuery];
    
    // all done now, so stop the main runloop so the app can exit
    CFRunLoopStop(CFRunLoopGetMain());
}

- (void) performQuery
{
    [_query startQuery];
}

@end

#pragma mark -

static const char *gVersionNumber = "1.0";

static const char * _shortCommandLineArgs = "hvm:";
const struct option _longCommandLineArgs[] = {
    { "help", no_argument, NULL, 'h' },
    { "version", no_argument, NULL, 'v' },
    { "max-results", required_argument, NULL, 'm' },
    { NULL, 0, NULL, 0 }
};

static void usage(FILE *fp)
{
    NSString * usageStr = [[NSString alloc] initWithFormat: @"Usage: %@ [OPTIONS] <search-term>\n"
                           @"\n"
                           @"Options:\n"
                           @"  -h, --help         Display this information.\n"
                           @"  -v, --version      Display the version number.\n"
                           @"  -m, --max-results  Limit the number of results to the provided number.\n"
                           @"\n", [[NSProcessInfo processInfo] processName]];
    fprintf(fp, "%s", [usageStr UTF8String]);
    fflush(fp);
}

static void version(FILE *fp)
{
    fprintf(fp, "%s: version %s\n", [[[NSProcessInfo processInfo] processName] UTF8String], gVersionNumber);
    fflush(fp);
}

int main(int argc, char * const argv[])
{
    @autoreleasepool
    {
        NSUInteger maxResults = 0;
        int ch = 0;
        NSString * searchTerm = nil;
        
        while ( (ch = getopt_long(argc, argv, _shortCommandLineArgs, _longCommandLineArgs, NULL)) != -1 )
        {
            switch ( ch )
            {
                case 'h':
                    usage(stdout);
                    return ( EX_OK );
                case 'v':
                    version(stdout);
                    return ( EX_OK );
                    
                case 'm':
                    maxResults = strtoull(optarg, NULL, 10);
                    break;
                    
                default:
                    usage(stderr);
                    return ( EX_USAGE );
            }
        }
        
        if ( optind >= argc )
        {
            fprintf(stderr, "Error: No search term provided.\n");
            usage(stderr);
            return ( EX_USAGE );
        }
        
        searchTerm = [[NSString stringWithUTF8String: argv[optind]] stringByAppendingString: @"*"];
        
        // The Spotlight menu uses this search:
        // (* == '<searchTerm>'wcd || kMDItemTextContent == '<searchTerm>'wcd)
        NSArray * allTheThings = @[@"*", (__bridge id)kMDItemTextContent];
        NSMutableArray * allTheQueries = [NSMutableArray new];
        for ( NSString * attributeName in allTheThings )
        {
            NSExpression * lhs = [NSExpression expressionForKeyPath: @"*"];
            NSExpression * rhs = [NSExpression expressionForConstantValue: searchTerm];
            NSPredicate * predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs modifier: NSDirectPredicateModifier type: NSLikePredicateOperatorType options: NSCaseInsensitivePredicateOption|NSDiacriticInsensitivePredicateOption];
            
            [allTheQueries addObject: predicate];
        }
        
        // create the compound predicate itself
        NSPredicate * predicate = [NSCompoundPredicate orPredicateWithSubpredicates: allTheQueries];
        MetadataSearcher * searcher = [[MetadataSearcher alloc] initWithPredicate: predicate maxResults: maxResults];
        [searcher performQuery];
        
        // run the main run loop until the query is done
        CFRunLoopRun();
    }
    
    return ( EX_OK );
}
