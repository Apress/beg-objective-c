//
//  NSError+APDictionaryRepresentation.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-08-01.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (APDictionaryRepresentation)
+ (NSError *) errorWithJSONDictionaryRepresentation: (NSDictionary *) dictionary;
- (NSDictionary *) jsonDictionaryRepresentation;
@end
