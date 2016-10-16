//
//  StreamCryptor.h
//  FileEncryptor
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StreamCryptor : NSObject <NSStreamDelegate>
{
    NSInputStream * _stream;
}
- (id) initWithInputURL: (NSURL *) input outputURL: (NSURL *) output passPhrase: (NSString *) passPhrase encrypting: (BOOL) encrypting;
- (void) run;
@end
