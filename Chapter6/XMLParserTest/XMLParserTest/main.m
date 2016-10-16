//
//  main.m
//  XMLParserTest
//
//  Created by Jim Dovey on 12-06-11.
//  Copyright (c) 2012 Apress. All rights reserved.
//
/*
 *  ParserComparison.m
 *  ParserComparison
 *
 *  Created by Jim Dovey on 6/4/2009.
 *
 *  Copyright (c) 2009 Jim Dovey
 *  All rights reserved.
 *  
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *  
 *  Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *  
 *  Neither the name of this project's author nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#if TARGET_OS_IPHONE
# error This isn't designed for iPhone; it's a command-line app.
#endif

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <sysexits.h>
#import <getopt.h>
#import <stdarg.h>
#import "MemoryUsageLogger.h"

static const char * MemorySizeString( mach_vm_size_t size );

static const char *     _shortCommandLineArgs = "f:u:i:ndsh";
static struct option    _longCommandLineArgs[] = {
    { "file", required_argument, NULL, 'f'},
    { "url", required_argument, NULL, 'u' },
    { "iterations", required_argument, NULL, 'i' },
    { "nsxmlparser", no_argument, NULL, 'n' },
    { "nsxmldocument", no_argument, NULL, 'd' },
    { "streamed-nsxmlparser", no_argument, NULL, 's' },
    { "help", no_argument, NULL, 'h' },
    { NULL, 0, NULL, 0 }
};

enum
{
    Test_NSXMLParserWithURL,
    Test_NSXMLDocument,
    Test_NSXMLParserWithStream
};

# pragma mark -

static void usage(FILE *fp)
{
    fprintf( fp, "Loads and parses an XML file containing 'number' elements in any\n"
            "structure, each containing a contiguous integer value.  The values are read\n"
            "into an NSMutableIndexSet, so as to avoid consuming too much memory with\n"
            "the parsed data.  We check the amount of virtual memory consumed by the app\n"
            "at certain points within the process, and print out the maximum amount of\n"
            "memory consumed.\n\n"
            "The different methods attempted are using NSXMLParser's -initWithURL:, with\n"
            "NSXMLParser's -initWithData: using a memory-mapped data object, and using\n"
            "AQXMLParser which reads data from a stream.\n\n" );
    fprintf( fp, "Usage: ParserComparison [OPTIONS]\n" );
    fprintf( fp, "  Options:\n" );
    fprintf( fp, "    [-f|--file]=FILE            Path to an XML file to load.\n" );
    fprintf( fp, "    [-u|--url]=URL              URL for an XML file to load. Must not require\n"
                 "                                authentication to access.\n" );
    fprintf( fp, "    [-n|--nsxmlparser           Run NSXMLParser test direct from URL.\n" );
    fprintf( fp, "    [-d|--nsxmldocument]        Run NSXMLDocument test direct from URL.\n" );
    fprintf( fp, "    [-s|--streamed-nsxmlparser] Run NSXMLParser test using streams (default).\n" );
    fprintf( fp, "    [-i|--iterations]=COUNT     Run a specific number of iterations and average\n"
                 "                                the results. Default is 1.\n");
    fprintf( fp, "    [-h|--help]                 Display this message.\n\n" );
    fprintf( fp, "If both -f and -u options are provided, -u takes precedence. If more than\n"
                 "one test-run argument is provided, runs the last one specified.\n" );
    fflush( fp );
}

static const char * MemorySizeString( mach_vm_size_t size )
{
    enum
    {
        kSizeIsBytes        = 0,
        kSizeIsKilobytes,
        kSizeIsMegabytes,
        kSizeIsGigabytes,
        kSizeIsTerabytes,
        kSizeIsPetabytes,
        kSizeIsExabytes
    };
    
    int sizeType = kSizeIsBytes;
    double dSize = (double) size;
    
    while ( isgreater(dSize, 1024.0) )
    {
        dSize = dSize / 1024.0;
        sizeType++;
    }
    
    NSMutableString * str = [[NSMutableString alloc] initWithFormat: (sizeType == kSizeIsBytes ? @"%.00f" : @"%.02f"), dSize];
    switch ( sizeType )
    {
        default:
        case kSizeIsBytes:
            [str appendString: @" bytes"];
            break;
            
        case kSizeIsKilobytes:
            [str appendString: @"KB"];
            break;
            
        case kSizeIsMegabytes:
            [str appendString: @"MB"];
            break;
            
        case kSizeIsGigabytes:
            [str appendString: @"GB"];
            break;
            
        case kSizeIsTerabytes:
            [str appendString: @"TB"];
            break;
            
        case kSizeIsPetabytes:
            [str appendString: @"PB"];
            break;
            
        case kSizeIsExabytes:
            [str appendString: @"EB"];
            break;
    }
    
    return ( [str UTF8String] );
}

#pragma mark -

@interface NumberParser : NSObject <NSXMLParserDelegate>
{
    NSUInteger count;
}
@property (nonatomic, readonly, retain) NSMutableIndexSet * set;
@property (nonatomic, readonly) mach_vm_size_t maxVMSize;
@property (nonatomic) mach_vm_size_t startVMSize;
@property (copy) NSString * characters;
@end

@implementation NumberParser

@synthesize set, characters, maxVMSize, startVMSize;

- (id) init
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    set = [[NSMutableIndexSet alloc] init];
    
    return ( self );
}

- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if ( self.characters != nil )
        self.characters = [self.characters stringByAppendingString: string];
    else
        self.characters = string;
}

- (void) parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    NSString * str = [[NSString alloc] initWithData: CDATABlock encoding: NSUTF8StringEncoding];
    [self parser: parser foundCharacters: str];
}

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    self.characters = nil;
}

- (void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ( [elementName isEqualToString: @"number"] == NO )
        return;
    
    count++;
    NSUInteger number = (NSUInteger) [self.characters integerValue];
    [set addIndex: number];
    
    mach_vm_size_t vmUsage = GetProcessMemoryUsage() - startVMSize;
    if ( vmUsage > maxVMSize )
        maxVMSize = vmUsage;
}

@end

#pragma mark -

static void RunNSDocumentTest( NSURL * url, int iterations )
{
    fprintf( stdout, "Testing NSXMLDocument...\n" );
    
    mach_vm_size_t * sizes = malloc(iterations*sizeof(mach_vm_size_t));
    CFTimeInterval * times = malloc(iterations*sizeof(CFTimeInterval));
    
    for ( int i = 0; i < iterations; i++ )
    {
        @autoreleasepool
        {
            mach_vm_size_t start = GetProcessMemoryUsage();
            CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
            NSXMLDocument * doc = [[NSXMLDocument alloc] initWithContentsOfURL: url
                                                                       options: NSXMLDocumentTidyXML
                                                                         error: NULL];
            time = CFAbsoluteTimeGetCurrent() - time;
            mach_vm_size_t end = GetProcessMemoryUsage();
            [doc rootElement];      // keep it alive until here
            
            sizes[i] = end - start;
            times[i] = time;
        }
    }
    
    // average the results
    mach_vm_size_t avgSize = 0;
    CFTimeInterval avgTime = 0.0;
    for ( int i = 0; i < iterations; i++ )
    {
        avgSize += sizes[i];
        avgTime += times[i];
    }
    
    fprintf( stdout, "  %.02f seconds, peak VM usage: %s\n", avgTime / iterations, MemorySizeString(avgSize / iterations) );
    
    free(sizes);
    free(times);
}

static void RunNSParserTest( NSURL * url, int iterations )
{
    fprintf( stdout, "Testing NSXMLParser with data...\n" );
    
    mach_vm_size_t * sizes = malloc(iterations*sizeof(mach_vm_size_t));
    CFTimeInterval * times = malloc(iterations*sizeof(CFTimeInterval));
    
    for ( int i = 0; i < iterations; i++ )
    {
        @autoreleasepool
        {
            NumberParser * delegate = [[NumberParser alloc] init];
            delegate.startVMSize = GetProcessMemoryUsage();
            
            NSData * data = [NSData dataWithContentsOfURL: url options: 0 error: NULL];
            NSXMLParser * parser = [[NSXMLParser alloc] initWithData: data];
            [parser setDelegate: delegate];
            
            CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
            
            (void) [parser parse];
            
            time = CFAbsoluteTimeGetCurrent() - time;
            
            sizes[i] = delegate.maxVMSize;
            times[i] = time;
        }
    }
    
    // average the results
    mach_vm_size_t avgSize = 0;
    CFTimeInterval avgTime = 0.0;
    for ( int i = 0; i < iterations; i++ )
    {
        avgSize += sizes[i];
        avgTime += times[i];
    }
    
    fprintf( stdout, "  %.02f seconds, peak VM usage: %s\n", avgTime / iterations, MemorySizeString(avgSize / iterations) );
    
    free(sizes);
    free(times);
}

static NSInputStream * StreamFromURL( NSURL * url )
{
    if ( [url isFileURL] )
        return ( [[NSInputStream alloc] initWithFileAtPath: [url path]] );
    
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest( kCFAllocatorDefault, CFSTR("POST"),
                                                      (__bridge CFURLRef)url, kCFHTTPVersion1_1 );
    NSInputStream * stream = CFBridgingRelease(CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, msg));
    CFRelease( msg );
    
    return ( stream );
}

static void RunNSParserTestWithStream( NSURL * url, int iterations )
{
    fprintf( stdout, "Testing NSXMLParser with input stream...\n" );
    
    mach_vm_size_t * sizes = malloc(iterations*sizeof(mach_vm_size_t));
    CFTimeInterval * times = malloc(iterations*sizeof(CFTimeInterval));
    
    for ( int i = 0; i < iterations; i++ )
    {
        @autoreleasepool
        {
            NumberParser * delegate = [[NumberParser alloc] init];
            delegate.startVMSize = GetProcessMemoryUsage();
            NSInputStream * stream = StreamFromURL(url);
            NSXMLParser * parser = [[NSXMLParser alloc] initWithStream: stream];
            
            [parser setDelegate: delegate];
            
            CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
            
            (void) [parser parse];
            
            time = CFAbsoluteTimeGetCurrent() - time;
            
            sizes[i] = delegate.maxVMSize;
            times[i] = time;
        }
    }
    
    // average the results
    mach_vm_size_t avgSize = 0;
    CFTimeInterval avgTime = 0.0;
    for ( int i = 0; i < iterations; i++ )
    {
        avgSize += sizes[i];
        avgTime += times[i];
    }
    
    fprintf( stdout, "  %.02f seconds, peak VM usage: %s\n", avgTime / iterations, MemorySizeString(avgSize / iterations) );
    
    free(sizes);
    free(times);
}

#pragma mark -

int main (int argc, char * const argv[])
{
    const char * fileStr = NULL;
    const char * urlStr  = NULL;
    int ch = -1;
    int test = Test_NSXMLParserWithStream;
    int iterations = 1;
    
    @autoreleasepool
    {
        while ( (ch = getopt_long(argc, argv, _shortCommandLineArgs, _longCommandLineArgs, NULL)) != -1 )
        {
            switch ( ch )
            {
                case 'h':
                default:
                    usage(stdout);
                    return ( EX_OK );
                    
                case 'f':
                    fileStr = optarg;
                    break;
                case 'u':
                    urlStr = optarg;
                    break;
                    
                case 'i':
                    iterations = MAX(atoi(optarg), 1);
                    break;
                    
                case 'n':
                    test = Test_NSXMLParserWithURL;
                    break;
                case 'd':
                    test = Test_NSXMLDocument;
                    break;
                case 's':
                    test = Test_NSXMLParserWithStream;
                    break;
            }
        }
        
        if ( (fileStr == NULL) && (urlStr == NULL) )
        {
            usage(stderr);
            exit( EX_USAGE );
        }
        
        // we're going to avoid creating autoreleased objects as much as possible, so we can get them all
        //  deallocated & out of the way asap
        NSURL * url = nil;
        if ( urlStr != NULL )
        {
            NSString * str = [[NSString alloc] initWithUTF8String: urlStr];
            url = [NSURL URLWithString: str];
        }
        else
        {
            NSString * str = [[NSString alloc] initWithUTF8String: fileStr];
            url = [NSURL fileURLWithPath: str];
        }
        
        switch ( test )
        {
            case Test_NSXMLDocument:
                RunNSDocumentTest( url, iterations );
                break;
                
            case Test_NSXMLParserWithURL:
                RunNSParserTest( url, iterations );
                break;
                
            default:
            case Test_NSXMLParserWithStream:
                RunNSParserTestWithStream( url, iterations );
                break;
        }
    }
    
    return ( EX_OK );
}