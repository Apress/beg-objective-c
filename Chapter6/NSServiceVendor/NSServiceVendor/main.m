//
//  main.m
//  NSServiceVendor
//
//  Created by Jim Dovey on 12-06-15.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import <sysexits.h>

static const char *gVersionNumer = "1.0";

static const char *         _shortCommandLineArgs = "hvt:d:n:";
static const struct option  _longCommandLineArgs[] = {
    { "help", no_argument, NULL, 'h' },
    { "version", no_argument, NULL, 'v' },
    { "type", required_argument, NULL, 't' },
    { "domain", required_argument, NULL, 'd' },
    { "name", required_argument, NULL, 'n' },
    { NULL, 0, NULL, 0 }
};

static void version(FILE *fp)
{
    fprintf(fp, "%s version %s\n", [[[NSProcessInfo processInfo] processName] UTF8String], gVersionNumer);
    fflush(fp);
}

static void usage(FILE *fp)
{
    version(fp);
    fprintf(fp, "Usage: %s [-h|-v] -t <type> [-d <domain]\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
    fprintf(fp, "Options:\n");
    fprintf(fp, "  --help|-h            Display this message and exit.\n");
    fprintf(fp, "  --version|-v         Display the application version and exit.\n");
    fprintf(fp, "  --name|-n            Specify the name of the new service. If not provided,\n");
    fprintf(fp, "                       the system will generate a name for you.\n");
    fprintf(fp, "  --type|-t <type>     Specify the type of the service to vend. Required.\n");
    fprintf(fp, "  --domain|-d <domain> Specify a domain in which to register. If not\n");
    fprintf(fp, "                       provided, registers in all available domains.\n");
    fflush(fp);
}

#pragma mark -

@interface ServiceVendor : NSObject<NSNetServiceDelegate>
- (id) initWithName: (NSString *) name type: (NSString *) type domain: (NSString *) domain;
- (void) start;
- (void) stop;
@end

@implementation ServiceVendor
{
    NSNetService *_service;
}

- (id) initWithName: (NSString *) name type: (NSString *) type domain: (NSString *) domain
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    int port = (arc4random() % (65535-1024)) + 1024;
    _service = [[NSNetService alloc] initWithDomain: domain type: type name: name port: port];
    
    return ( self );
}

- (void) start
{
    [_service setDelegate: self];
    [_service scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
    [_service publish];
}

- (void) stop
{
    [_service stop];
}

@end

#pragma mark -

int main(int argc, char * const argv[])
{
    const char *name = NULL;
    const char *type = NULL;
    const char *domain = NULL;
    
    int ch = 0;
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
                
            case 'n':
                name = optarg;
                break;
            case 't':
                type = optarg;
                break;
            case 'd':
                domain = optarg;
                break;
                
            default:
                usage(stderr);
                return ( EX_USAGE );
        }
    }
    
    if ( type == NULL )
    {
        usage(stderr);
        return ( EX_USAGE );
    }
    
    if ( domain == NULL )
        domain = "";
    
    @autoreleasepool
    {
        dispatch_source_t termSig = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
        dispatch_source_t intSig  = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
        
        dispatch_block_t sigHandler = ^{ CFRunLoopStop(CFRunLoopGetMain()); };
        dispatch_source_set_event_handler(termSig, sigHandler);
        dispatch_source_set_event_handler(intSig, sigHandler);
        
        ServiceVendor * vendor = [[ServiceVendor alloc] initWithName: [NSString stringWithUTF8String: name] type: [NSString stringWithUTF8String: type] domain: [NSString stringWithUTF8String: domain]];
        [vendor start];
        
        CFRunLoopRun();
        
        [vendor stop];
    }
    
    return ( EX_OK );
}

