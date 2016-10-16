//
//  FolderInfoPresenter.h
//  FileCoordinationExample
//
//  Created by Jim Dovey on 12-06-05.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FolderInfoPresenter : NSObject <NSFilePresenter>
- (id) initWithFolderURL: (NSURL *) folderURL;
@end
