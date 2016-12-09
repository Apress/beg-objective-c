//
//  APAddressBookImporter.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-20.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APAddressBookImporter.h"
#import <AddressBook/AddressBook.h>

#import "Person.h"
#import "MailingAddress.h"
#import "EmailAddress.h"
#import "PhoneNumber.h"

@interface APAddressBookImporter ()
@property (nonatomic, copy) void (^completionHandler)(NSError *);
@end

@implementation APAddressBookImporter
{
    NSManagedObjectContext *_context;
}

- (id) initWithParentObjectContext: (NSManagedObjectContext *) parent
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
    [_context setParentContext: parent];
    // because it has a parent, it doesn't need a persistentStoreCoordinator
    
    return ( self );
}

- (void) beginImportingWithCompletion: (void (^)(NSError *)) completion
{
    self.completionHandler = completion;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ABAddressBook * addressBook = [ABAddressBook addressBook];
        
        // get our entity descriptions ready to use to create objects
        NSEntityDescription *entity = [NSEntityDescription entityForName: @"Person"
                                                  inManagedObjectContext: _context];

        for ( ABPerson * abPerson in [addressBook people] )
        {
            // Create a new Person object in our own database
            Person * myPerson = [[Person alloc] initWithEntity: entity
                                insertIntoManagedObjectContext: _context];
            
            // now fetch some values from the Address Book for this person
            myPerson.firstName = [abPerson valueForProperty: kABFirstNameProperty];
            myPerson.lastName = [abPerson valueForProperty: kABLastNameProperty];
            
            // email addresses
            [self importEmailsFromABPerson: abPerson toMine: myPerson];

            // phone numbers
            [self importPhonesFromABPerson: abPerson toMine: myPerson];

            // mailing addresses
            [self importAddressesFromABPerson: abPerson toMine: myPerson];

            // now save the contents of the context and/or clean up, in a
            // synchronized fashion
            [_context performBlockAndWait: ^{
                NSError * validationError = nil;
                // if the person is valid, save it. Otherwise, reset the context.
                if ( [myPerson validateForUpdate: &validationError] == NO )
                {
                    [_context reset];
                }
                else
                {
                    NSError * error = nil;
                    if ( [_context save: &error] == NO )
                    {
                        // zap this record and its related objects
                        [_context deleteObject: myPerson];
                    }
                }
            }];
        }
    });
}

- (void)importEmailsFromABPerson:(ABPerson *)abPerson toMine:(Person *)myPerson
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"EmailAddress"
                                              inManagedObjectContext:_context];
    ABMultiValue * abEmails = [abPerson valueForProperty: kABEmailProperty];
    for ( NSUInteger i = 0, max = [abEmails count]; i < max; i++ )
    {
        NSString * label = [abEmails labelAtIndex: i];
        NSString * email = [abEmails valueAtIndex: i];
        
        // skip any weird entries which won't fit with our model validation
        if ( label == nil || email == nil )
            continue;
        
        EmailAddress * e = [[EmailAddress alloc] initWithEntity: entity
                                 insertIntoManagedObjectContext: _context];
        e.label = ABLocalizedPropertyOrLabel(label);
        e.email = email;
        
        // rather than call the 'add to relationship' methods on myPerson,
        // we'll just set the to-one relationship on the email, which
        // does the same thing
        e.person = myPerson;
        
        // ensure it's valid -- if not, delete it
        NSError * validationError = nil;
        if ( [e validateForUpdate: &validationError] == NO )
        {
            [_context performBlockAndWait: ^{
                [_context deleteObject: e];
            }];
            continue;
        }
    }
}

- (void)importPhonesFromABPerson:(ABPerson *)abPerson toMine:(Person *)myPerson
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"PhoneNumber"
                                              inManagedObjectContext:_context];
    ABMultiValue * abPhones = [abPerson valueForProperty: kABPhoneProperty];
    for ( NSUInteger i = 0, max = [abPhones count]; i < max; i++ )
    {
        NSString * label = [abPhones labelAtIndex: i];
        NSString * phone = [abPhones valueAtIndex: i];
        
        if ( label == nil || phone == nil )
            continue;
        
        PhoneNumber *p = [[PhoneNumber alloc] initWithEntity: entity
                              insertIntoManagedObjectContext: _context];
        p.label = ABLocalizedPropertyOrLabel(label);
        p.phoneNumber = phone;
        p.person = myPerson;
        
        // validate
        NSError * validationError = nil;
        if ( [p validateForUpdate: &validationError] == NO )
        {
            [_context performBlockAndWait: ^{
                [_context deleteObject: p];
            }];
            continue;
        }
    }
}

- (void)importAddressesFromABPerson:(ABPerson *)abPerson toMine:(Person *)myPerson
{
    NSEntityDescription *ent = [NSEntityDescription entityForName:@"MailingAddress"
                                           inManagedObjectContext:_context];
    ABMultiValue *abMail = [abPerson valueForProperty: kABAddressProperty];
    for ( NSUInteger i = 0, max = [abMail count]; i < max; i++ )
    {
        NSString * label = [abMail labelAtIndex: i];
        NSDictionary * addr = [abMail valueAtIndex: i];
        
        if ( label == nil || addr == nil )
            continue;
        
        MailingAddress *m = [[MailingAddress alloc] initWithEntity: ent
                                    insertIntoManagedObjectContext: _context];
        m.label = ABLocalizedPropertyOrLabel(label);
        m.street = [addr objectForKey: kABAddressStreetKey];
        m.city = [addr objectForKey: kABAddressCityKey];
        m.region = [addr objectForKey: kABAddressStateKey];
        m.country = [addr objectForKey: kABAddressCountryKey];
        m.postalCode = [addr objectForKey: kABAddressZIPKey];
        m.person = myPerson;
        
        // validate
        NSError * validationError = nil;
        if ( [m validateForUpdate: &validationError] == NO )
        {
            [_context performBlockAndWait: ^{
                [_context deleteObject: m];
            }];
            continue;
        }
    }
}

@end
