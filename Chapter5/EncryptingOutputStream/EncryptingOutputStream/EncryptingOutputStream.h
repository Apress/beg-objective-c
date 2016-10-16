//
//  EncryptingOutputStream.h
//  EncryptingOutputStream
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EncryptingOutputStream : NSOutputStream
- (id) initWithFileURL: (NSURL *) fileURL passPhrase: (NSString *) passPhrase;
@end
