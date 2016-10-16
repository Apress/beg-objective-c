//
//  main.m
//  jsonize
//
//  Created by Jim Dovey on 12-06-11.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import <sysexits.h>

static const char *     gVersionNumber = "1.0";

static const char *		_shortCommandLineArgs = "hvjp";
static struct option	_longCommandLineArgs[] = {
	{ "help", no_argument, NULL, 'h' },
	{ "version", no_argument, NULL, 'v' },
    { "json", no_argument, NULL, 'j' },
    { "plist", no_argument, NULL, 'p' },
	{ NULL, 0, NULL, 0 }
};

static void version(FILE *fp)
{
    fprintf(fp, "%s version %s\n", [[[NSProcessInfo processInfo] processName] UTF8String], gVersionNumber);
    fflush(fp);
}

static void usage(FILE *fp)
{
    fprintf(fp, "Usage: %s [-j|-p] [<path>]\n"
            "Options:\n"
            "  -h|--help    Display this message.\n"
            "  -v|--version Display the application's version number.\n"
            "  -j|--json    Create JSON data from the input property list.\n"
            "  -p|--plist   Create an XML property list from the input JSON data.\n\n"
            "Only one of -j or -p may be specified.\n"
            "If no path is provided, input will be read from stdin.\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
    fflush(fp);
}

int main(int argc, char * const argv[])
{
    @autoreleasepool
    {
        BOOL inputIsJSON = NO, inputIsPlist = NO;
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
                    
                case 'j':
                {
                    if ( inputIsPlist )
                    {
                        fprintf(stderr, "Error: only one of -p or -j options may be specified.\n");
                        usage(stderr);
                        return ( EX_USAGE );
                    }
                    
                    inputIsJSON = YES;
                    break;
                }
                    
                case 'p':
                {
                    if ( inputIsJSON )
                    {
                        fprintf(stderr, "Error: only one of -p or -j options may be specified.\n");
                        usage(stderr);
                        return ( EX_USAGE );
                    }
                    
                    inputIsPlist = YES;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        if ( inputIsJSON == inputIsPlist )
        {
            fprintf(stderr, "Error: must specify one of -p or -j options.\n");
            usage(stderr);
            return ( EX_NOINPUT );
        }
        
        NSFileHandle * input = nil;
        NSFileHandle * output = [NSFileHandle fileHandleWithStandardOutput];
        
        if ( optind < argc )
        {
            input = [NSFileHandle fileHandleForReadingAtPath: [NSString stringWithUTF8String: argv[optind]]];
            if ( input == nil )
            {
                fprintf(stderr, "Error: unable to open file at path %s\n", argv[optind]);
                usage(stderr);
                return ( EX_USAGE );
            }
        }
        else
        {
            input = [NSFileHandle fileHandleWithStandardInput];
        }
        
        NSData * inputData = [input readDataToEndOfFile];
        
        NSError * error = nil;
        NSData * converted = nil;
        if ( inputIsJSON )
        {
            id obj = [NSJSONSerialization JSONObjectWithData: inputData options: 0 error: &error];
            if ( obj != nil )
            {
                converted = [NSPropertyListSerialization dataWithPropertyList: obj format: NSPropertyListXMLFormat_v1_0 options: 0 error: &error];
            }
        }
        else
        {
            id obj = [NSPropertyListSerialization propertyListWithData: inputData options: 0 format: NULL error: &error];
            if ( obj != nil )
            {
                if ( [NSJSONSerialization isValidJSONObject: obj] == NO )
                {
                    fprintf(stderr, "Error: input property list cannot be represented as JSON.\n");
                    return ( EX_DATAERR );
                }
                
                converted = [NSJSONSerialization dataWithJSONObject: obj options: NSJSONWritingPrettyPrinted error: &error];
            }
        }
        
        if ( converted == nil )
        {
            NSString * desc = [error localizedFailureReason];
            if ( desc == nil )
                desc = [error localizedDescription];
            if ( desc == nil )
                desc = [NSString stringWithFormat: @"unexpected error -- %@ / %lu", [error domain], [error code]];
            
            fprintf(stderr, "Error: %s\n", [desc UTF8String]);
            return ( EX_SOFTWARE );
        }
        
        // write the data to stdout
        [output writeData: converted];
    }
    
    return ( EX_OK );
}

