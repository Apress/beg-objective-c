//
//  SimpleRunLoopSource.h
//  EncryptingOutputStream
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SimpleRunLoopSource : NSObject

- (id) initWithSourceHandler: (void (^)(void)) handler;

- (void) signal;
- (void) invalidate;

- (void) addToRunLoop: (NSRunLoop *) runLoop forMode: (NSString *) mode;
- (void) removeFromRunLoop: (NSRunLoop *) runLoop forMode: (NSString *) mode;

@end
