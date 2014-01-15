/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2013  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Substrate is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Substrate is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Substrate.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

#include <substrate.h>

Class $SafeModeAlertItem;

@interface SBAlertItem : NSObject {
}
- (UIAlertView *) alertSheet;
- (void) dismiss;
@end

@interface SBAlertItemsController : NSObject {
}
+ (SBAlertItemsController *) sharedInstance;
- (void) activateAlertItem:(SBAlertItem *)item;
@end

@interface SBStatusBarTimeView : UIView {
}
- (id) textFont;
@end

@interface UIApplication (CydiaSubstrate)
- (void) applicationOpenURL:(id)url;
@end

@interface UIAlertView (CydiaSubstrate)
- (void) setForceHorizontalButtonsLayout:(BOOL)force;
- (void) setBodyText:(NSString *)body;
- (void) setNumberOfRows:(NSInteger)rows;
@end

void SafeModeButtonClicked(int button) {
    switch (button) {
        case 1:
        break;

        case 2:
            if (kCFCoreFoundationVersionNumber >= 700)
                system("killall backboardd");
            else
                // XXX: there are better ways of restarting SpringBoard that would actually save state
                exit(0);
        break;

        case 3:
            [[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"http://cydia.saurik.com/safemode/"]];
        break;
    }
}

void SafeModeAlertItem$alertSheet$buttonClicked$(id self, SEL sel, id sheet, int button) {
    SafeModeButtonClicked(button);
    [self dismiss];
}

void SafeModeAlertItem$alertView$clickedButtonAtIndex$(id self, SEL sel, id sheet, NSInteger button) {
    SafeModeButtonClicked(button + 1);
    [self dismiss];
}

void SafeModeAlertItem$configure$requirePasscodeForActions$(id self, SEL sel, BOOL configure, BOOL require) {
    UIAlertView *sheet([self alertSheet]);

    [sheet setDelegate:self];
    [sheet setBodyText:@"We apologize for the inconvenience, but SpringBoard has just crashed.\n\nMobileSubstrate /did not/ cause this problem: it has protected you from it.\n\nYour device is now running in Safe Mode. All extensions that support this safety system are disabled.\n\nReboot (or restart SpringBoard) to return to the normal mode. To return to this dialog touch the status bar.\n\nTap \"Help\" below for more tips."];
    [sheet addButtonWithTitle:@"OK"];
    [sheet addButtonWithTitle:@"Restart"];
    [sheet addButtonWithTitle:@"Help"];
    [sheet setNumberOfRows:1];

    if ([sheet respondsToSelector:@selector(setForceHorizontalButtonsLayout:)])
        [sheet setForceHorizontalButtonsLayout:YES];
}

void SafeModeAlertItem$performUnlockAction(id self, SEL sel) {
    [[%c(SBAlertItemsController) sharedInstance] activateAlertItem:self];
}

static void MSAlert() {
    if ($SafeModeAlertItem == nil)
        $SafeModeAlertItem = objc_lookUpClass("SafeModeAlertItem");
    if ($SafeModeAlertItem == nil) {
        $SafeModeAlertItem = objc_allocateClassPair(objc_getClass("SBAlertItem"), "SafeModeAlertItem", 0);
        if ($SafeModeAlertItem == nil)
            return;

        class_addMethod($SafeModeAlertItem, @selector(alertSheet:buttonClicked:), (IMP) &SafeModeAlertItem$alertSheet$buttonClicked$, "v@:@i");
        class_addMethod($SafeModeAlertItem, @selector(alertView:clickedButtonAtIndex:), (IMP) &SafeModeAlertItem$alertView$clickedButtonAtIndex$, "v@:@i");
        class_addMethod($SafeModeAlertItem, @selector(configure:requirePasscodeForActions:), (IMP) &SafeModeAlertItem$configure$requirePasscodeForActions$, "v@:cc");
        class_addMethod($SafeModeAlertItem, @selector(performUnlockAction), (IMP) SafeModeAlertItem$performUnlockAction, "v@:");
        objc_registerClassPair($SafeModeAlertItem);
    }

    if (%c(SBAlertItemsController) != nil)
        [[%c(SBAlertItemsController) sharedInstance] activateAlertItem:[[[$SafeModeAlertItem alloc] init] autorelease]];
}


// XXX: on iOS 5.0, we really would prefer avoiding 

%hook SBStatusBar
- (void) touchesEnded:(id)touches withEvent:(id)event {
    MSAlert();
    %orig(touches, event);
} %end

%hook SBStatusBar
- (void) mouseDown:(void *)event {
    MSAlert();
    %orig(event);
} %end

%hook UIStatusBar
- (void) touchesBegan:(void *)touches withEvent:(void *)event {
    MSAlert();
    %orig(touches, event);
} %end


// this fairly complex code came from Grant, to solve the "it Safe Mode"-in-bar bug

%hook SBStatusBarDataManager
- (void) _updateTimeString {
    char *_data(&MSHookIvar<char>(self, "_data"));
    if (_data == NULL)
        return;

    Ivar _itemIsEnabled(object_getInstanceVariable(self, "_itemIsEnabled", NULL));
    if (_itemIsEnabled == NULL)
        return;

    Ivar _itemIsCloaked(object_getInstanceVariable(self, "_itemIsCloaked", NULL));
    if (_itemIsCloaked == NULL)
        return;

    size_t enabledOffset(ivar_getOffset(_itemIsEnabled));
    size_t cloakedOffset(ivar_getOffset(_itemIsCloaked));
    if (enabledOffset >= cloakedOffset)
        return;

    size_t offset(cloakedOffset - enabledOffset);
    char *timeString(_data + offset);
    strcpy(timeString, "Exit Safe Mode");
} %end


// this /insanely/ complex code came from that parrot guy... omg this is getting bad

@interface SBStatusBarStateAggregator : NSObject
- (void) _stopTimeItemTimer;
@end

%hook SBStatusBarStateAggregator

- (void) _updateTimeItems {
    if ([self respondsToSelector:@selector(_stopTimeItemTimer)])
        [self _stopTimeItemTimer];
    %orig;
}

- (void) _restartTimeItemTimer {
}

- (void) _resetTimeItemFormatter {
    %orig;
    if (NSDateFormatter *df = MSHookIvar<NSDateFormatter *>(self, "_timeItemDateFormatter"))
        [df setDateFormat:@"'Exit' 'Safe' 'Mode'"];
}

%end


static bool alerted_;

static void AlertIfNeeded() {
    if (alerted_)
        return;
    alerted_ = true;
    MSAlert();
}

// on iOS 7 (maybe also iOS 6) we should really just hook the unlock mechanism
// XXX: deterine where this works and maybe unify this code

%hook SBLockScreenManager
- (void) _finishUIUnlockFromSource:(int)source withOptions:(id)options {
    %orig;
    AlertIfNeeded();
} %end


// on iOS 4.3 and above we can use this advertisement, which seems to check every time the user unlocks
// XXX: verify that this still works on iOS 5.0

%hook AAAccountManager
+ (void) showMobileMeOfferIfNecessary {
    AlertIfNeeded();
} %end


// -[SBIconController showInfoAlertIfNeeded] explains how to drag icons around the iPhone home screen
// it used to be shown to users when they unlocked their screen for the first time, and happened every unlock
// however, as of iOS 4.3, it got relegated to only appearing once the user installed an app or web clip

%hook SBIconController
- (void) showInfoAlertIfNeeded {
    AlertIfNeeded();
} %end


// the icon state, including crazy configurations like Five Icon Dock, is stored in SpringBoard's defaults
// unfortunately, SpringBoard on iOS 2.0 and 2.1 (maybe 2.2 as well) buffer overrun with more than 4 icons
// there is a third party package called IconSupport that remedies this, but not everyone is using it yet

%hook SBButtonBar
- (int) maxIconColumns {
    static int max;
    if (max == 0) {
        max = %orig();
        if (NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults])
            if (NSDictionary *iconState = [defaults objectForKey:@"iconState"])
                if (NSDictionary *buttonBar = [iconState objectForKey:@"buttonBar"])
                    if (NSArray *iconMatrix = [buttonBar objectForKey:@"iconMatrix"])
                        if ([iconMatrix count] != 0)
                            if (NSArray *row = [iconMatrix objectAtIndex:0]) {
                                int count([row count]);
                                if (max < count)
                                    max = count;
                            }
    } return max;
} %end


%hook SBUIController
- (id) init {
    if ((self = %orig()) != nil) {
        UIView *&_contentLayer(MSHookIvar<UIView *>(self, "_contentLayer"));
        UIView *&_contentView(MSHookIvar<UIView *>(self, "_contentView"));

        UIView *layer;
        if (&_contentLayer != NULL)
            layer = _contentLayer;
        else if (&_contentView != NULL)
            layer = _contentView;
        else
            layer = nil;

        if (layer != nil)
            [layer setBackgroundColor:[UIColor darkGrayColor]];
    } return self;
} %end

#define Paper_ "/Library/MobileSubstrate/MobileSafety.png"

%hook SBWallpaperImage
+ (id) alloc {
    return nil;
} %end

%hook UIImage
+ (UIImage *) defaultDesktopImage {
    return [UIImage imageWithContentsOfFile:@Paper_];
} %end

%hook SBStatusBarTimeView
- (void) tile {
    NSString *&_time(MSHookIvar<NSString *>(self, "_time"));
    CGRect &_textRect(MSHookIvar<CGRect>(self, "_textRect"));
    if (_time != nil)
        [_time release];
    _time = [@"Exit Safe Mode" retain];
    id font([self textFont]);
    CGSize size([_time sizeWithFont:font]);
    CGRect frame([self frame]);
    _textRect.size = size;
    _textRect.origin.x = (frame.size.width - size.width) / 2;
    _textRect.origin.y = (frame.size.height - size.height) / 2;
} %end


// notification widgets ("wee apps" or "bulletin board sections") are capable of crashing SpringBoard
// unfortunately, which ones are in use are stored in SpringBoard's defaults, so we need to turn them off

%hook BBSectionInfo
- (BOOL) showsInNotificationCenter {
    return NO;
} %end


// we don't want this state persisted back to disk, however: that is just really really irritating

%hook BBServer
- (void) _writeBehaviorOverrides {}
- (void) _writeSectionOrder {}
- (void) _writeClearedSections {}
- (void) _writeSectionInfo {}
%end


// on iOS 6.0, Apple split parts of SpringBoard into a daemon called backboardd, including app launches
// in order to allow safe mode to propogate into applications, we need to then tell backboardd here
// XXX: (all of this should be replaced, however, with per-process launchd-mediated exception handling)

%hook BKSApplicationLaunchSettings
- (void) setEnvironment:(NSDictionary *)original {
    if (original == nil)
        return %orig(nil);

    NSMutableDictionary *modified([original mutableCopy]);
    [modified setObject:@"1" forKey:@"_MSSafeMode"];
    return %orig(modified);
} %end

%ctor {
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

    // on iOS 6, backboardd is in charge of brightness, and freaks out when SpringBoard restarts :(
    // the result is that the device is super dark until we attempt to update the brightness here.

    if (kCFCoreFoundationVersionNumber >= 700) {
        if (void (*GSEventSetBacklightLevel)(float) = reinterpret_cast<void (*)(float)>(dlsym(RTLD_DEFAULT, "GSEventSetBacklightLevel")))
            if (NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Preferences/com.apple.springboard.plist", NSHomeDirectory()]])
                if (NSNumber *level = [defaults objectForKey:@"SBBacklightLevel2"])
                    GSEventSetBacklightLevel([level floatValue]);
    }

    [pool release];
}
