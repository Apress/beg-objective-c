//
//  main.m
//  FileEncryptor
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StreamCryptor.h"
#import <getopt.h>
#import <sysexits.h>

static const char *gVersionNumber = "1.0";

static const char *		_shortCommandLineArgs = "hvdeo:p:";
static struct option	_longCommandLineArgs[] = {
	{ "help", no_argument, NULL, 'h' },
	{ "version", no_argument, NULL, 'v' },
	{ "decrypt", no_argument, NULL, 'd' },
	{ "encrypt", no_argument, NULL, 'e' },
    { "output-file", required_argument, NULL, 'o' },
    { "pass-phrase", required_argument, NULL, 'p' },
	{ NULL, 0, NULL, 0 }
};

static void usage(FILE *fp)
{
    NSString * usageStr = [[NSString alloc] initWithFormat: @"Usage: %@ [OPTIONS] [ARGUMENTS]\n"
                           @"\n"
                           @"Options:\n"
                           @"  -h, --help         Display this information.\n"
                           @"  -v, --version      Display the version number.\n"
                           @"  -d, --decrypt      Decrypt the input file.\n"
                           @"  -e, --encrypt      Encrypt the input file.\n"
                           @"\n"
                           @"Arguments:\n"
                           @"  -o, --output-file  Relative path to the output file. Optional.\n"
                           @"  -p, --pass-phrase  The passphrase with which to encrypt/decrypt content.\n"
                           @"\n", [[NSProcessInfo processInfo] processName]];
    fprintf(fp, "%s", [usageStr UTF8String]);
#if USING_MRR
    [usageStr release];
#endif
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
        NSURL * output = nil;
        NSString * phrase = nil;
        
        BOOL encrypt = YES;
        
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
                    
                case 'e':
                    encrypt = YES;
                    break;
                case 'd':
                    encrypt = NO;
                    break;
                    
                case 'o':
                {
                    NSString * path = [NSString stringWithUTF8String: optarg];
                    output = [NSURL fileURLWithPath: path];
                    break;
                }
                    
                case 'p':
                    phrase = [NSString stringWithUTF8String: optarg];
                    break;
                    
                default:
                    usage(stderr);
                    return ( EX_USAGE );
            }
        }
        
        if ( optind > argc || [phrase length] == 0 )
        {
            usage(stderr);
            return ( EX_USAGE );
        }
        
        NSURL * input = [NSURL fileURLWithPath: [NSString stringWithUTF8String: argv[optind]]];
        BOOL isDirectory = NO;
        if ( [[NSFileManager defaultManager] fileExistsAtPath: [input path] isDirectory: &isDirectory] == NO || isDirectory == YES )
        {
            fprintf(stderr, "File not found: %s\n", [[input path] fileSystemRepresentation]);
            usage(stderr);
            exit(EX_IOERR);
        }
        
        if ( output == nil )
            output = [input URLByAppendingPathExtension: (encrypt ? @"encrypted" : @"decrypted")];
        
        StreamCryptor * cryptor = [[StreamCryptor alloc] initWithInputURL: input outputURL: output passPhrase: phrase encrypting: encrypt];
        [cryptor run];
        
        // the reader will stop the current run loop when it's done
        CFRunLoopRun();
    }
    
    return 0;
}

