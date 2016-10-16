//
//  APAddressBookImporter.h
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-20.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface APAddressBookImporter : NSObject
- (id)initWithParentObjectContext:(NSManagedObjectContext *)parent;
- (void)beginImportingWithCompletion:(void (^)(NSError *error)) completion;
@end
