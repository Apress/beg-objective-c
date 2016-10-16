//
//  main.m
//  FileCoordinationExample
//
//  Created by Jim Dovey on 12-06-05.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sysexits.h>
#import "FolderInfoPresenter.h"

static void usage(void)
{
    fprintf(stderr, "Usage: FileCoordinationExample <folder>\n");
    fflush(stderr);
}

int main(int argc, const char * argv[])
{
    if ( argc != 2 )
    {
        usage();
        return ( EX_USAGE );
    }
    
    @autoreleasepool
    {
        NSString * path = [[NSString stringWithUTF8String: argv[1]] stringByStandardizingPath];
        BOOL isDir = NO;
        if ( [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDir] == NO || isDir == NO )
        {
            fprintf(stderr, "Specified path does not exist, or is not a folder.\n");
            usage();
            return ( EX_USAGE );
        }
        
        NSURL * url = [NSURL fileURLWithPath: path isDirectory: YES];
        FolderInfoPresenter * presenter = [[FolderInfoPresenter alloc] initWithFolderURL: url];
        
        // quit on receipt of SIGINT or SIGTERM
        dispatch_block_t signalHandlerBlock = ^{ CFRunLoopStop(CFRunLoopGetMain()); };
        dispatch_source_t intSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
        dispatch_source_t termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(intSource, signalHandlerBlock);
        dispatch_source_set_event_handler(termSource, signalHandlerBlock);
        dispatch_resume(intSource);
        dispatch_resume(termSource);
        
        // run the main run loop until we're done
        CFRunLoopRun();
        
        dispatch_source_cancel(intSource);
        dispatch_source_cancel(termSource);
        
#if !defined(OS_OBJECT_USE_OBJC) || OS_OBJECT_USE_OBJC == 0
        dispatch_release(intSource);
        dispatch_release(termSource);
#endif
        
        // force ARC to keep this alive until here
        fprintf(stdout, "NSFilePresenter %p shut down.\n", presenter);
    }
    
    return 0;
}

