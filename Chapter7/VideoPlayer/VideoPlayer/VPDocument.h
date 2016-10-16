//
//  VPDocument.h
//  VideoPlayer
//
//  Created by Jim Dovey on 2012-08-02.
//  Copyright (c) 2012 Apress, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class QTMovie;

@interface VPDocument : NSDocument
@property (nonatomic, strong) QTMovie * movie;
@end
