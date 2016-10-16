//
//  SHAEncryptor.h
//  FileEncryptor
//
//  Created by Jim Dovey on 12-06-03.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SHAEncryptor : NSObject
- (id) initWithPassPhrase: (NSString *) passPhrase;
- (NSData *) encryptData: (NSData *) data;
- (NSData *) decryptData: (NSData *) data;
- (NSData *) finalData;  // returns any trailing data
@end
