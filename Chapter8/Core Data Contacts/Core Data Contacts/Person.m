//
//  Person.m
//  Core Data Contacts
//
//  Created by Jim Dovey on 2012-07-16.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "Person.h"
#import "EmailAddress.h"
#import "MailingAddress.h"


@implementation Person

@dynamic firstName;
@dynamic lastName;
@dynamic emailAddresses;
@dynamic mailingAddresses;
@dynamic phoneNumbers;

+ (NSSet *) keyPathsForValuesAffectingFullName
{
    return ( [NSSet setWithObjects: @"firstName", @"lastName", nil] );
}

- (NSString *) fullName
{
    if ( self.firstName != nil && self.lastName != nil )
        return ( [NSString stringWithFormat: @"%@ %@", self.firstName, self.lastName] );
    
    if ( self.firstName != nil )
        return ( self.firstName );
    else
        return ( self.lastName );
}

- (void) setFullName: (NSString *) fullName
{
    NSCharacterSet * whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet * nonWhitespace = [whitespace invertedSet];
    
    fullName = [fullName stringByTrimmingCharactersInSet: whitespace];
    NSRange r = [fullName rangeOfCharacterFromSet: whitespace];
    if ( r.location == NSNotFound )
    {
        // a single name
        self.firstName = fullName;
        self.lastName = nil;
        return;
    }
    
    self.firstName = [fullName substringToIndex: r.location];
    
    r = NSMakeRange(r.location, [fullName length]-r.location);
    r = [fullName rangeOfCharacterFromSet: nonWhitespace options: 0 range: r];
    self.lastName = [fullName substringFromIndex: r.location];
}

@end
