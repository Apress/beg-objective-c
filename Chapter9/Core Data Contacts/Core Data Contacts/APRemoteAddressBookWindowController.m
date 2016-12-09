//
//  APRemoteAddressBookWindowController.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-27.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APRemoteAddressBookWindowController.h"

@interface APRemoteAddressBookWindowController () <NSWindowDelegate>
@property (nonatomic, readwrite, getter=isLoadingPeople) BOOL loadingPeople;
@end

@implementation APRemoteAddressBookWindowController
{
    id<APRemoteAddressBook>     _remoteAddressBook;
    NSOperationQueue *          _loaderQ;
}

- (id) initWithRemoteAddressBook: (id<APRemoteAddressBook>) remoteAddressBook
                            name: (NSString *) serviceName
{
    self = [super initWithWindowNibName: [self className]];
    if ( self == nil )
        return ( nil );
    
    _serviceName = [serviceName copy];
    _remoteAddressBook = remoteAddressBook;
    _loaderQ = [NSOperationQueue new];
    [_loaderQ setMaxConcurrentOperationCount: 1];
    
    return ( self );
}

- (BOOL) windowShouldClose: (id) sender
{
    // tell the network connection to disconnect now
    [_remoteAddressBook disconnect];
    return ( YES );
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    [[self window] setDelegate: self];

    // setup the sort descriptors
    // remember to trigger KVO notifications so the relevant controllers can be
    //  updated
    if ( _personSortDescriptors == nil )
    {
        [self willChangeValueForKey: @"personSortDescriptors"];
        _personSortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"lastName"
                                                                 ascending: YES]];
        [self didChangeValueForKey: @"personSortDescriptors"];
    }
    if ( _labelSortDescriptors == nil )
    {
        [self willChangeValueForKey: @"labelSortDescriptors"];
        _labelSortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"label"
                                                                ascending: YES]];
        [self didChangeValueForKey: @"labelSortDescriptors"];
    }
    
    // fetch all people (it's always an asynchronous call)
    [_remoteAddressBook allPeople: ^(id result, NSError *error) {
        if ( error != nil )
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp presentError: error];
            });
            return;
        }
        
        NSArray * people = result;
        NSMutableArray * contentArray = [[NSMutableArray alloc] initWithCapacity: [people count]];
        for ( NSDictionary * person in people )
        {
            NSMutableDictionary * mine = [person mutableCopy];
            
            // add the remaining pieces necessary for our UI etc.
            NSString * first = person[@"firstName"];
            NSString * last = person[@"lastName"];
            
            if ( first != nil && last != nil )
                mine[@"fullName"] = [NSString stringWithFormat: @"%@ %@", first, last];
            else if ( first != nil )
                mine[@"fullName"] = first;
            else if ( last != nil )
                mine[@"fullName"] = last;
            
            if ( first != nil )
                mine[@"firstName"] = first;
            if ( last != nil )
                mine[@"lastName"] = last;
            
            mine[@"loadingPhones"] = @NO;
            mine[@"loadingEmails"] = @NO;
            mine[@"loadingAddresses"] = @NO;
            
            mine[@"phoneNumbers"] = [NSMutableArray new];
            mine[@"emails"] = [NSMutableArray new];
            mine[@"addresses"] = [NSMutableArray new];
            
            // pack it into the output array
            [contentArray addObject: mine];
        }
        
        // now we want to update the UI by setting the content of our
        //  peopleController outlet to this array
        // this hits the UI though, so we do it on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.peopleController setContent: contentArray];
        });
    }];
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    // find the Person's mutable dictionary
    if ( [self.peopleController selectionIndex] == NSNotFound )
        return;
    
    NSMutableDictionary * person = [self.peopleController selection];
    if ( person == nil )
        return;
    
    NSString * personID = [person valueForKey: APRemoteAddressBookCommandPersonIDKey];
    if ( personID == nil )
        return;     // can't do anything without the ID
    
    // kill any waiting load operations so this one can run quickly for the user
    [_loaderQ cancelAllOperations];
    
    if ( [[person valueForKey: @"loadingPhones"] isEqual: @NO] && [[person valueForKey: @"phoneNumbers"] count] == 0 )
    {
        [person setValue: @YES forKey: @"loadingPhones"];
        NSOperation * op = [NSBlockOperation blockOperationWithBlock: ^{
            [_remoteAddressBook phoneNumbersForPersonWithIdentifier: personID reply: ^(id result, NSError *error) {
                // again, update the controller's content on the main queue, since it
                //  will update the UI in response.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [person setValue: result forKey: @"phoneNumbers"];
                    [person setValue: @NO forKey: @"loadingPhones"];
                });
            }];
        }];
        
        // the completion block runs when the operation is complete or canceled
        __weak NSOperation * weakOp = op;
        [op setCompletionBlock: ^{
            // if cancelled, we're no longer loading
            if ( [weakOp isCancelled] )
                [person setValue: @NO forKey: @"loadingPhones"];
        }];
        [_loaderQ addOperation: op];
    }
    if ( [[person valueForKey: @"loadingEmails"] isEqual: @NO] && [[person valueForKey: @"emails"] count] == 0 )
    {
        [person setValue: @YES forKey: @"loadingEmails"];
        NSOperation * op = [NSBlockOperation blockOperationWithBlock: ^{
            [_remoteAddressBook emailAddressesForPersonWithIdentifier: personID reply: ^(id result, NSError *error) {
                // again, update the controller's content on the main queue, since it
                //  will update the UI in response.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [person setValue: result forKey: @"emails"];
                    [person setValue: @NO forKey: @"loadingEmails"];
                });
            }];
        }];
        
        // the completion block runs when the operation is complete or canceled
        __weak NSOperation * weakOp = op;
        [op setCompletionBlock: ^{
            if ( [weakOp isCancelled] )
                [person setValue: @NO forKey: @"loadingEmails"];
        }];
        [_loaderQ addOperation: op];
    }
    if ( [[person valueForKey: @"loadingAddresses"] isEqual: @NO] && [[person valueForKey: @"addresses"] count] == 0 )
    {
        [person setValue: @YES forKey: @"loadingAddresses"];
        NSOperation * op = [NSBlockOperation blockOperationWithBlock: ^{
            [_remoteAddressBook mailingAddressesForPersonWithIdentifier: personID reply: ^(id result, NSError *error) {
                // again, update the controller's content on the main queue, since it
                //  will update the UI in response.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [person setValue: result forKey: @"addresses"];
                    [person setValue: @NO forKey: @"loadingAddresses"];
                });
            }];
        }];
        
        // the completion block runs when the operation is complete or canceled
        __weak NSOperation * weakOp = op;
        [op setCompletionBlock: ^{
            if ( [weakOp isCancelled] )
                [person setValue: @NO forKey: @"loadingAddresses"];
        }];
        [_loaderQ addOperation: op];
    }
    
    // stick a fork in us, we're done!
}

@end
