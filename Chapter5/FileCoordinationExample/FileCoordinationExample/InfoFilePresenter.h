//
//  InfoFilePresenter.h
//  FileCoordinationExample
//
//  Created by Jim Dovey on 12-06-06.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InfoFilePresenter : NSObject <NSFilePresenter>
- (id) initWithFileURL: (NSURL *) fileURL queue: (NSOperationQueue *) queue;
- (void) appendFileSize: (NSUInteger) fileSize allocatedSize: (NSUInteger) allocatedSize;
- (void) writeFile;
@end
