//
//  main.m
//  FileAttributeReader
//
//  Created by Jim Dovey on 2012-05-23.
//  Copyright (c) 2012 Apress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import <sysexits.h>

static const char *     gVersionNumber = "1.0";

static const char *		_shortCommandLineArgs = "hvf:";
static struct option	_longCommandLineArgs[] = {
	{ "help", no_argument, NULL, 'h' },
	{ "version", no_argument, NULL, 'v' },
    { "file", required_argument, NULL, 'f' },
	{ NULL, 0, NULL, 0 }
};

static void version(FILE *fp)
{
    fprintf(fp, "%s version %s\n", [[[NSProcessInfo processInfo] processName] UTF8String], gVersionNumber);
    fflush(fp);
}

static void usage(FILE *fp)
{
    fprintf(fp, "Usage: %s -f <path> <attribute> [<attribute2> ...]\n\n"
                "  Attributes can be any resource key defined in <Foundation/NSURL.h> or '*',\n"
                "  which will print all attributes.\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
    fflush(fp);
}

static NSArray * all_attributes(void)
{
    NSArray * allAttrs = @[
        NSURLNameKey,
        NSURLLocalizedNameKey,
        NSURLIsRegularFileKey,
        NSURLIsDirectoryKey,
        NSURLIsSymbolicLinkKey,
        NSURLIsVolumeKey,
        NSURLIsPackageKey,
        NSURLIsSystemImmutableKey,
        NSURLIsUserImmutableKey,
        NSURLIsHiddenKey,
        NSURLHasHiddenExtensionKey,
        NSURLCreationDateKey,
        NSURLContentAccessDateKey,
        NSURLContentModificationDateKey,
        NSURLAttributeModificationDateKey,
        NSURLLinkCountKey,
        NSURLParentDirectoryURLKey,
        NSURLVolumeURLKey,
        NSURLTypeIdentifierKey,
        NSURLLocalizedTypeDescriptionKey,
        NSURLLabelNumberKey,
        NSURLLabelColorKey,
        NSURLLocalizedLabelKey,
        NSURLEffectiveIconKey,
        NSURLCustomIconKey,
        NSURLFileResourceIdentifierKey,
        NSURLVolumeIdentifierKey,
        NSURLPreferredIOBlockSizeKey,
        NSURLIsReadableKey,
        NSURLIsWritableKey,
        NSURLIsExecutableKey,
        NSURLFileSecurityKey,
#if defined(MAC_OS_X_VERSION_10_8) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8)
        NSURLIsExcludedFromBackupKey,
        NSURLPathKey,
#endif
        NSURLIsMountTriggerKey,
        NSURLFileResourceTypeKey,
        NSURLFileResourceTypeNamedPipe,
        NSURLFileResourceTypeCharacterSpecial,
        NSURLFileResourceTypeDirectory,
        NSURLFileResourceTypeBlockSpecial,
        NSURLFileResourceTypeRegular,
        NSURLFileResourceTypeSymbolicLink,
        NSURLFileResourceTypeSocket,
        NSURLFileResourceTypeUnknown,
        NSURLFileSizeKey,
        NSURLFileAllocatedSizeKey,
        NSURLTotalFileSizeKey,
        NSURLTotalFileAllocatedSizeKey,
        NSURLIsAliasFileKey,
        NSURLVolumeLocalizedFormatDescriptionKey,
        NSURLVolumeTotalCapacityKey,
        NSURLVolumeAvailableCapacityKey,
        NSURLVolumeResourceCountKey,
        NSURLVolumeSupportsPersistentIDsKey,
        NSURLVolumeSupportsSymbolicLinksKey,
        NSURLVolumeSupportsHardLinksKey,
        NSURLVolumeSupportsJournalingKey,
        NSURLVolumeIsJournalingKey,
        NSURLVolumeSupportsSparseFilesKey,
        NSURLVolumeSupportsZeroRunsKey,
        NSURLVolumeSupportsCaseSensitiveNamesKey,
        NSURLVolumeSupportsCasePreservedNamesKey,
        NSURLVolumeSupportsRootDirectoryDatesKey,
        NSURLVolumeSupportsVolumeSizesKey,
        NSURLVolumeSupportsRenamingKey,
        NSURLVolumeSupportsAdvisoryFileLockingKey,
        NSURLVolumeSupportsExtendedSecurityKey,
        NSURLVolumeIsBrowsableKey,
        NSURLVolumeMaximumFileSizeKey,
        NSURLVolumeIsEjectableKey,
        NSURLVolumeIsRemovableKey,
        NSURLVolumeIsInternalKey,
        NSURLVolumeIsAutomountedKey,
        NSURLVolumeIsLocalKey,
        NSURLVolumeIsReadOnlyKey,
        NSURLVolumeCreationDateKey,
        NSURLVolumeURLForRemountingKey,
        NSURLVolumeUUIDStringKey,
        NSURLVolumeNameKey,
        NSURLVolumeLocalizedNameKey,
        NSURLIsUbiquitousItemKey,
        NSURLUbiquitousItemHasUnresolvedConflictsKey,
        NSURLUbiquitousItemIsDownloadedKey,
        NSURLUbiquitousItemIsDownloadingKey,
        NSURLUbiquitousItemIsUploadedKey,
        NSURLUbiquitousItemIsUploadingKey,
        NSURLUbiquitousItemPercentDownloadedKey,
        NSURLUbiquitousItemPercentUploadedKey
    ];
    
    return ( allAttrs );
}

static NSArray * canonical(NSArray * attrs)
{
    NSDictionary * lookup = @{
        @"NSURLNameKey" : NSURLNameKey,
        @"NSURLLocalizedNameKey" : NSURLLocalizedNameKey,
        @"NSURLIsRegularFileKey" : NSURLIsRegularFileKey,
        @"NSURLIsDirectoryKey" : NSURLIsDirectoryKey,
        @"NSURLIsSymbolicLinkKey" : NSURLIsSymbolicLinkKey,
        @"NSURLIsVolumeKey" : NSURLIsVolumeKey,
        @"NSURLIsPackageKey" : NSURLIsPackageKey,
        @"NSURLIsSystemImmutableKey" : NSURLIsSystemImmutableKey,
        @"NSURLIsUserImmutableKey" : NSURLIsUserImmutableKey,
        @"NSURLIsHiddenKey" : NSURLIsHiddenKey,
        @"NSURLHasHiddenExtensionKey" : NSURLHasHiddenExtensionKey,
        @"NSURLCreationDateKey" : NSURLCreationDateKey,
        @"NSURLContentAccessDateKey" : NSURLContentAccessDateKey,
        @"NSURLContentModificationDateKey" : NSURLContentModificationDateKey,
        @"NSURLAttributeModificationDateKey" : NSURLAttributeModificationDateKey,
        @"NSURLLinkCountKey" : NSURLLinkCountKey,
        @"NSURLParentDirectoryURLKey" : NSURLParentDirectoryURLKey,
        @"NSURLVolumeURLKey" : NSURLVolumeURLKey,
        @"NSURLTypeIdentifierKey" : NSURLTypeIdentifierKey,
        @"NSURLLocalizedTypeDescriptionKey" : NSURLLocalizedTypeDescriptionKey,
        @"NSURLLabelNumberKey" : NSURLLabelNumberKey,
        @"NSURLLabelColorKey" : NSURLLabelColorKey,
        @"NSURLLocalizedLabelKey" : NSURLLocalizedLabelKey,
        @"NSURLEffectiveIconKey" : NSURLEffectiveIconKey,
        @"NSURLCustomIconKey" : NSURLCustomIconKey,
        @"NSURLFileResourceIdentifierKey" : NSURLFileResourceIdentifierKey,
        @"NSURLVolumeIdentifierKey" : NSURLVolumeIdentifierKey,
        @"NSURLPreferredIOBlockSizeKey" : NSURLPreferredIOBlockSizeKey,
        @"NSURLIsReadableKey" : NSURLIsReadableKey,
        @"NSURLIsWritableKey" : NSURLIsWritableKey,
        @"NSURLIsExecutableKey" : NSURLIsExecutableKey,
        @"NSURLFileSecurityKey" : NSURLFileSecurityKey,
#if defined(MAC_OS_X_VERSION_10_8) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8)
        @"NSURLIsExcludedFromBackupKey" : NSURLIsExcludedFromBackupKey,
        @"NSURLPathKey" : NSURLPathKey,
#endif
        @"NSURLIsMountTriggerKey" : NSURLIsMountTriggerKey,
        @"NSURLFileResourceTypeKey" : NSURLFileResourceTypeKey,
        @"NSURLFileResourceTypeNamedPipe" : NSURLFileResourceTypeNamedPipe,
        @"NSURLFileResourceTypeCharacterSpecial" : NSURLFileResourceTypeCharacterSpecial,
        @"NSURLFileResourceTypeDirectory" : NSURLFileResourceTypeDirectory,
        @"NSURLFileResourceTypeBlockSpecial" : NSURLFileResourceTypeBlockSpecial,
        @"NSURLFileResourceTypeRegular" : NSURLFileResourceTypeRegular,
        @"NSURLFileResourceTypeSymbolicLink" : NSURLFileResourceTypeSymbolicLink,
        @"NSURLFileResourceTypeSocket" : NSURLFileResourceTypeSocket,
        @"NSURLFileResourceTypeUnknown" : NSURLFileResourceTypeUnknown,
        @"NSURLFileSizeKey" : NSURLFileSizeKey,
        @"NSURLFileAllocatedSizeKey" : NSURLFileAllocatedSizeKey,
        @"NSURLTotalFileSizeKey" : NSURLTotalFileSizeKey,
        @"NSURLTotalFileAllocatedSizeKey" : NSURLTotalFileAllocatedSizeKey,
        @"NSURLIsAliasFileKey" : NSURLIsAliasFileKey,
        @"NSURLVolumeLocalizedFormatDescriptionKey" : NSURLVolumeLocalizedFormatDescriptionKey,
        @"NSURLVolumeTotalCapacityKey" : NSURLVolumeTotalCapacityKey,
        @"NSURLVolumeAvailableCapacityKey" : NSURLVolumeAvailableCapacityKey,
        @"NSURLVolumeResourceCountKey" : NSURLVolumeResourceCountKey,
        @"NSURLVolumeSupportsPersistentIDsKey" : NSURLVolumeSupportsPersistentIDsKey,
        @"NSURLVolumeSupportsSymbolicLinksKey" : NSURLVolumeSupportsSymbolicLinksKey,
        @"NSURLVolumeSupportsHardLinksKey" : NSURLVolumeSupportsHardLinksKey,
        @"NSURLVolumeSupportsJournalingKey" : NSURLVolumeSupportsJournalingKey,
        @"NSURLVolumeIsJournalingKey" : NSURLVolumeIsJournalingKey,
        @"NSURLVolumeSupportsSparseFilesKey" : NSURLVolumeSupportsSparseFilesKey,
        @"NSURLVolumeSupportsZeroRunsKey" : NSURLVolumeSupportsZeroRunsKey,
        @"NSURLVolumeSupportsCaseSensitiveNamesKey" : NSURLVolumeSupportsCaseSensitiveNamesKey,
        @"NSURLVolumeSupportsCasePreservedNamesKey" : NSURLVolumeSupportsCasePreservedNamesKey,
        @"NSURLVolumeSupportsRootDirectoryDatesKey" : NSURLVolumeSupportsRootDirectoryDatesKey,
        @"NSURLVolumeSupportsVolumeSizesKey" : NSURLVolumeSupportsVolumeSizesKey,
        @"NSURLVolumeSupportsRenamingKey" : NSURLVolumeSupportsRenamingKey,
        @"NSURLVolumeSupportsAdvisoryFileLockingKey" : NSURLVolumeSupportsAdvisoryFileLockingKey,
        @"NSURLVolumeSupportsExtendedSecurityKey" : NSURLVolumeSupportsExtendedSecurityKey,
        @"NSURLVolumeIsBrowsableKey" : NSURLVolumeIsBrowsableKey,
        @"NSURLVolumeMaximumFileSizeKey" : NSURLVolumeMaximumFileSizeKey,
        @"NSURLVolumeIsEjectableKey" : NSURLVolumeIsEjectableKey,
        @"NSURLVolumeIsRemovableKey" : NSURLVolumeIsRemovableKey,
        @"NSURLVolumeIsInternalKey" : NSURLVolumeIsInternalKey,
        @"NSURLVolumeIsAutomountedKey" : NSURLVolumeIsAutomountedKey,
        @"NSURLVolumeIsLocalKey" : NSURLVolumeIsLocalKey,
        @"NSURLVolumeIsReadOnlyKey" : NSURLVolumeIsReadOnlyKey,
        @"NSURLVolumeCreationDateKey" : NSURLVolumeCreationDateKey,
        @"NSURLVolumeURLForRemountingKey" : NSURLVolumeURLForRemountingKey,
        @"NSURLVolumeUUIDStringKey" : NSURLVolumeUUIDStringKey,
        @"NSURLVolumeNameKey" : NSURLVolumeNameKey,
        @"NSURLVolumeLocalizedNameKey" : NSURLVolumeLocalizedNameKey,
        @"NSURLIsUbiquitousItemKey" : NSURLIsUbiquitousItemKey,
        @"NSURLUbiquitousItemHasUnresolvedConflictsKey" : NSURLUbiquitousItemHasUnresolvedConflictsKey,
        @"NSURLUbiquitousItemIsDownloadedKey" : NSURLUbiquitousItemIsDownloadedKey,
        @"NSURLUbiquitousItemIsDownloadingKey" : NSURLUbiquitousItemIsDownloadingKey,
        @"NSURLUbiquitousItemIsUploadedKey" : NSURLUbiquitousItemIsUploadedKey,
        @"NSURLUbiquitousItemIsUploadingKey" : NSURLUbiquitousItemIsUploadingKey,
        @"NSURLUbiquitousItemPercentDownloadedKey" : NSURLUbiquitousItemPercentDownloadedKey,
        @"NSURLUbiquitousItemPercentUploadedKey" : NSURLUbiquitousItemPercentUploadedKey
    };
    
    NSMutableArray * canon = [[NSMutableArray alloc] initWithCapacity: [attrs count]];
    for ( NSString * attr in attrs )
    {
        // convert textual symbol into whatever the symbol's actual value is
        [canon addObject: [lookup objectForKey: attr]];
    }
    
    return ( canon );
}

static void show(NSURL * url, NSArray * attrs)
{
    NSError * error = nil;
    NSDictionary * dict = [url resourceValuesForKeys: attrs error: &error];
    if ( dict == nil )
    {
        if ( error != nil )
        {
            NSString * desc = [error localizedFailureReason];
            if ( desc == nil )
                desc = [error localizedDescription];
            if ( desc == nil )
                desc = [NSString stringWithFormat: @"<unknown error: %@:%lu>", [error domain], [error code]];
            fprintf(stderr, "Error fetching attributes: %s\n", [desc UTF8String] );
            return;
        }
    }
    
    fprintf(stdout, "%lu Attributes:\n", [dict count]);
    
    for ( NSString * attr in attrs )
    {
        fprintf(stdout, "  %44s : %s\n", [attr UTF8String], [[[dict objectForKey: attr] description] UTF8String]);
    }
}

int main(int argc, char * const argv[])
{
    @autoreleasepool
    {
        NSURL * url = nil;
        int ch = 0;
        while ( (ch = getopt_long(argc, argv, _shortCommandLineArgs, _longCommandLineArgs, NULL)) != -1 )
        {
            switch ( ch )
            {
                case 'h':
                    usage(stdout);
                    return ( EX_OK );
                    
                case 'v':
                    version(stdout);
                    return ( EX_OK );
                
                case 'f':
                    url = [NSURL fileURLWithPath: [NSString stringWithUTF8String: optarg]];
                    break;
                    
                default:
                    usage(stderr);
                    return ( EX_USAGE );
            }
        }
        
        if ( url == nil )
        {
            fprintf(stderr, "Error: no file specified.\n");
            usage(stderr);
            return ( EX_USAGE );
        }
        
        if ( optind >= argc )
        {
            fprintf(stderr, "Error: no attributes specified.\n");
            usage(stderr);
            return ( EX_USAGE );
        }
        
        NSMutableArray * attributes = [NSMutableArray new];
        for ( int i = optind; i < argc; i++ )
        {
            [attributes addObject: [NSString stringWithUTF8String: argv[i]]];
        }
        
        if ( [attributes containsObject: @"*"] )
        {
            show(url, all_attributes());
        }
        else
        {
            show(url, canonical(attributes));
        }
    }
    
    return ( EX_OK );
}

