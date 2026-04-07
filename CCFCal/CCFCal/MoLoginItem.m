//
//  Created by Sanjay Madan on 12/9/16.
//  Copyright © 2016 Mowglii. All rights reserved.
//

#import "MoLoginItem.h"

#import <ServiceManagement/ServiceManagement.h>

// LSSharedFileList API was deprecated in macOS 10.11
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL MOLegacyIsLoginItemEnabled(void)
{
    BOOL isEnabled = NO;
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

    if (loginItemsRef) {
        UInt32 seedValue;
        NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
        for (id item in loginItems) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
            if (pathURL && [pathURL.path hasPrefix:appPath]) {
                isEnabled = YES;
                break;
            }
        }
        CFRelease(loginItemsRef);
    }
    return isEnabled;
}

static BOOL MOLegacySetLoginItemEnabled(BOOL enable)
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

    if (loginItemsRef) {
        if (enable) {
            // We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (item != NULL) CFRelease(item);
        }
        else {
            // Grab the contents of the shared file list (LSSharedFileListItemRef objects)
            // and pop it in an array so we can iterate through it to find our item.
            UInt32 seedValue;
            NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
            for (id item in loginItems) {
                LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
                NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
                if (pathURL && [pathURL.path hasPrefix:appPath]) {
                    LSSharedFileListItemRemove(loginItemsRef, itemRef); // Deleting the item
                }
            }
        }
        CFRelease(loginItemsRef);
        return YES;
    }
    return NO;
}

BOOL MOIsLoginItemEnabled(void)
{
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    }
    return MOLegacyIsLoginItemEnabled();
}

BOOL MOLoginItemRequiresApproval(void)
{
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status == SMAppServiceStatusRequiresApproval;
    }
    return NO;
}

BOOL MOSetLoginItemEnabled(BOOL enable, NSError **error)
{
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        if (enable) {
            if (service.status == SMAppServiceStatusEnabled) {
                return YES;
            }
            return [service registerAndReturnError:error];
        }
        if (service.status == SMAppServiceStatusNotRegistered) {
            return YES;
        }
        return [service unregisterAndReturnError:error];
    }
    return MOLegacySetLoginItemEnabled(enable);
}

void MOOpenLoginItemsSettings(void)
{
    if (@available(macOS 13.0, *)) {
        [SMAppService openSystemSettingsLoginItems];
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"]];
}

#pragma clang diagnostic pop
