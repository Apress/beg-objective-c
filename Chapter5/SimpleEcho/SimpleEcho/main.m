//
//  main.m
//  SimpleEcho
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, char * const argv[])
{
    @autoreleasepool
    {
        // get hold of standard input
        NSFileHandle * input = [NSFileHandle fileHandleWithStandardInput];
        
        // register to receive the ‘read complete’ notification first
        NSString * name = NSFileHandleReadToEndOfFileCompletionNotification;
        NSOperationQueue * queue = [NSOperationQueue mainQueue];
        [[NSNotificationCenter defaultCenter] addObserverForName: name object: input queue: queue usingBlock: ^(NSNotification *note) {
            // get the data from the notification’s userInfo
            NSData * data = [[note userInfo] objectForKey: NSFileHandleNotificationDataItem];
            if ( data == nil )
                data = [@"No Input!" dataUsingEncoding: NSUTF8StringEncoding];
            
            // write the input data to standard output
            NSFileHandle * output = [NSFileHandle fileHandleWithStandardOutput];
            [output writeData: data];
            
            // append a newline character too 
            [output writeData: [NSData dataWithBytes: "\n" length: 1]];
            
            // all done now, so stop the runloop
            CFRunLoopStop(CFRunLoopGetMain());
        }];
        
        // book-keeping: handle Control-C to kill the app
        dispatch_source_t sigHandler =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0,
                               dispatch_get_main_queue());
        dispatch_source_set_event_handler(sigHandler, ^{
            CFRunLoopStop(CFRunLoopGetMain());
        });
        dispatch_resume(sigHandler);
        
        // read all data and notify us when it’s done
        [input readToEndOfFileInBackgroundAndNotify]; 
        
        // run the main runloop to wait for the data
        // the notification handler will stop the runloop, exiting the app
        CFRunLoopRun();
    }
    
    return ( 0 );
}

