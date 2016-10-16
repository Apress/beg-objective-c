//
//  SimpleRunLoopSource.m
//  EncryptingOutputStream
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import "SimpleRunLoopSource.h"

@interface SimpleRunLoopSource (CFGlue)
- (void) _performHandler;
@end

static void _CFRunLoopSourceHandler(void *info)
{
    SimpleRunLoopSource * source = (__bridge SimpleRunLoopSource *)info;
    [source _performHandler];
}

@implementation SimpleRunLoopSource
{
    CFRunLoopSourceRef _cf;
    void (^_sourceHandler)(void);
    NSCountedSet * _runLoops;
}

- (id) initWithSourceHandler: (void (^)(void)) handler
{
    NSParameterAssert(handler != nil);
    
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    CFRunLoopSourceContext ctx = {
        .version = 0,
        .info = (__bridge void *)self,
        .retain = NULL,
        .release = NULL,
        .copyDescription = CFCopyDescription,
        .equal = CFEqual,
        .hash = CFHash,
        .schedule = NULL,
        .cancel = NULL,
        .perform = _CFRunLoopSourceHandler
    };
    _cf = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &ctx);
    
    _sourceHandler = [handler copy];
    
    return ( self );
}

- (void) dealloc
{
    if ( _cf != NULL )
        CFRelease(_cf);
}

- (void) signal
{
    if ( _cf == NULL )
        return;
    
    CFRunLoopSourceSignal(_cf);
    
    // after signalling a version 0 source, we have to *manually* wake up the run loops to which it's attached
    for ( NSRunLoop * runLoop in _runLoops )
    {
        CFRunLoopWakeUp([runLoop getCFRunLoop]);
    }
}

- (void) invalidate
{
    if ( _cf != NULL )
        CFRunLoopSourceInvalidate(_cf);
}

- (void) addToRunLoop: (NSRunLoop *) runLoop forMode: (NSString *) mode
{
    if ( _cf == NULL )
        return;
    
    CFRunLoopAddSource([runLoop getCFRunLoop], _cf, (__bridge CFStringRef)mode);
    [_runLoops addObject: runLoop];
}

- (void) removeFromRunLoop: (NSRunLoop *) runLoop forMode: (NSString *) mode
{
    if ( _cf == NULL || CFRunLoopSourceIsValid(_cf) == FALSE )
        return;
    
    CFRunLoopRemoveSource([runLoop getCFRunLoop], _cf, (__bridge CFStringRef)mode);
    [_runLoops removeObject: runLoop];
}

- (void) _performHandler
{
    _sourceHandler();
}

@end
