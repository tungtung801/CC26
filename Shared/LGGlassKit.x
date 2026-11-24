#import "LGGlassKit.h"

#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

@interface MTMaterialView : UIView
@end

const void *kGlassKey = &kGlassKey;

static NSMutableArray<void (^)(void)> *sReloadHandlers = nil;
static NSMapTable<UIView *, LGGlassRec *> *sGlassRecs = nil;
static NSMapTable<UIView *, NSString *> *sSuppressed = nil;
static NSMutableArray<LGMaterialHostRoute *> *sMaterialHostRoutes = nil;

static void lgReconcileInjectionsForDisable(void);
static void lgEnablePrefsReloadCallback(CFNotificationCenterRef center,
                                        void *observer,
                                        CFStringRef name,
                                        const void *object,
                                        CFDictionaryRef userInfo);
static void lgRouteMaterialHost(UIView *view);

@implementation LGGlassRec
@end

@implementation LGMaterialHostRoute
@end

BOOL hasAncestorOfClassName(UIView *view, NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:cls]) return YES;
    }
    return NO;
}

BOOL ancestorNameContains(UIView *view, NSString *substring) {
    for (UIView *v = view; v; v = v.superview) {
        if ([NSStringFromClass([v class]) containsString:substring]) return YES;
    }
    return NO;
}

BOOL isExactClass(id obj, NSString *className) {
    return obj && [NSStringFromClass([obj class]) isEqualToString:className];
}

BOOL LGProcessMatchesExclusionList(id exclusionList) {
    NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString] ?: @"";

    if ([exclusionList isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)exclusionList) {
            if ([item isKindOfClass:[NSString class]] && [bundleId isEqualToString:[(NSString *)item lowercaseString]]) {
                return YES;
            }
        }
        return NO;
    }

    if (![exclusionList isKindOfClass:[NSString class]] || [(NSString *)exclusionList length] == 0) {
        return NO;
    }

    NSString *execName = [[[[NSBundle mainBundle] executablePath] lastPathComponent] lowercaseString] ?: @"";
    NSString *procName = [[[NSProcessInfo processInfo] processName] lowercaseString] ?: @"";
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"\n,;"];

    for (NSString *raw in [(NSString *)exclusionList componentsSeparatedByCharactersInSet:separators]) {
        NSString *token = [[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if (token.length == 0 || [token hasPrefix:@"#"]) continue;
        if ([token isEqualToString:bundleId] || [token isEqualToString:execName] || [token isEqualToString:procName]) {
            return YES;
        }
    }

    return NO;
}

BOOL lgHostEnabled(NSString *prefix) {
    if (prefix.length == 0) return YES;

    id globalEnabled = LGGlassPreferenceValue(@"Global.Enabled");
    if (![prefix isEqualToString:@"Global"] && [globalEnabled isKindOfClass:[NSNumber class]] && ![globalEnabled boolValue]) {
        return NO;
    }

    id val = LGGlassPreferenceValue([prefix stringByAppendingString:@".Enabled"]);
    if (!val) {
        static NSDictionary<NSString *, NSString *> *legacyPrefixes = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            legacyPrefixes = @{
                @"OpenFolder": @"FolderOpen",
                @"AppLibSearch": @"AppLibrary.Search",
                @"Passcode": @"Lockscreen.Passcode",
                @"Clock": @"Lockscreen.Clock",
                @"QuickActions": @"LockscreenQuickActions",
            };
        });
        NSString *legacy = legacyPrefixes[prefix];
        if (legacy) {
            val = LGGlassPreferenceValue([legacy stringByAppendingString:@".Enabled"]);
        }
    }

    if ([val isKindOfClass:[NSNumber class]]) {
        return [val boolValue];
    }

    if ([prefix isEqualToString:@"AppIcons"]) {
        return NO;
    }

    return YES;
}

void lgObservePreferenceReload(void (^handler)(void)) {
    if (!handler) return;
    if (!sReloadHandlers) sReloadHandlers = [NSMutableArray array];
    [sReloadHandlers addObject:[handler copy]];
}

void lgTrackGlass(UIView *glass, NSString *prefix, UIView *material) {
    if (!glass || prefix.length == 0) return;
    if (!sGlassRecs) sGlassRecs = [NSMapTable weakToStrongObjectsMapTable];

    LGGlassRec *existing = [sGlassRecs objectForKey:glass];
    if (existing) {
        existing.prefix = prefix;
        existing.material = material;
        return;
    }

    LGGlassRec *rec = [LGGlassRec new];
    rec.prefix = prefix;
    rec.glass = glass;
    rec.material = material;
    [sGlassRecs setObject:rec forKey:glass];
}

void lgSuppressStock(UIView *view, NSString *prefix, BOOL hideNow) {
    if (!view || prefix.length == 0) return;
    if (hideNow) {
        view.hidden = YES;
    }
    if (!sSuppressed) sSuppressed = [NSMapTable weakToStrongObjectsMapTable];
    [sSuppressed setObject:prefix forKey:view];
}

LGLiveBackdropView *LGCreateRegisteredGlass(CGRect frame, NSString *groupName, NSString *prefix) {
    if (prefix.length == 0) return nil;

    NSString *filterType = LGFilterTypeForHostPrefix(prefix);
    if (!filterType) {
        LGLog(@"lifecycle rejected unknown host prefix=%@", prefix);
        return nil;
    }

    return [[LGLiveBackdropView alloc] initWithFrame:frame groupName:groupName filterType:filterType];
}

UIView *LGInstallRegisteredGlassInMaterial(UIView *materialView,
                                           const void *assocKey,
                                           NSString *prefix,
                                           UIEdgeInsets outset,
                                           CGFloat cornerRadius,
                                           NSString *groupName) {
    if (!materialView || !assocKey || prefix.length == 0) return nil;

    const LGHostDefinition *def = LGHostDefinitionForPreferencePrefix(prefix.UTF8String);
    if (!def) {
        LGLog(@"lifecycle rejected unknown host prefix=%@", prefix);
        return nil;
    }

    if (!lgHostEnabled(prefix)) {
        LGRemoveGlassFromMaterial(materialView, assocKey);
        return nil;
    }

    NSString *filterType = [NSString stringWithUTF8String:def->filterType];
    LGInjectGlassIntoMaterialGroupType(materialView, assocKey, outset, cornerRadius, groupName, filterType);

    UIView *glass = objc_getAssociatedObject(materialView, assocKey);
    if (glass) {
        lgTrackGlass(glass, prefix, materialView);
    }
    return glass;
}

void LGRegisterMaterialHost(NSString *prefix,
                            NSInteger priority,
                            LGMaterialHostMatcher matcher,
                            UIEdgeInsets outset,
                            LGMaterialHostCornerRadiusProvider cornerRadiusProvider,
                            NSString *groupName,
                            LGMaterialHostPostInstall postInstall) {
    if (prefix.length == 0 || !matcher || !LGHostDefinitionForPreferencePrefix(prefix.UTF8String)) {
        LGLog(@"router rejected invalid material host prefix=%@", prefix);
        return;
    }

    if (!sMaterialHostRoutes) sMaterialHostRoutes = [NSMutableArray array];

    for (LGMaterialHostRoute *existing in sMaterialHostRoutes) {
        if ([existing.prefix isEqualToString:prefix]) return;
    }

    LGMaterialHostRoute *route = [LGMaterialHostRoute new];
    route.prefix = prefix;
    route.priority = priority;
    route.matcher = [matcher copy];
    route.outset = outset;
    route.cornerRadiusProvider = [cornerRadiusProvider copy];
    route.groupName = groupName;
    route.postInstall = [postInstall copy];

    [sMaterialHostRoutes addObject:route];
    [sMaterialHostRoutes sortUsingComparator:^NSComparisonResult(LGMaterialHostRoute *a, LGMaterialHostRoute *b) {
        if (a.priority == b.priority) {
            return [a.prefix compare:b.prefix];
        }
        return (a.priority > b.priority) ? NSOrderedAscending : NSOrderedDescending;
    }];
}

__attribute__((constructor))
static void lgGlassInitEnableObserver(void) {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        lgEnablePrefsReloadCallback,
        CFSTR("dylv.liquidassprefs/Reload"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}

static void lgEnablePrefsReloadCallback(CFNotificationCenterRef center,
                                        void *observer,
                                        CFStringRef name,
                                        const void *object,
                                        CFDictionaryRef userInfo) {
    LGLog(@"prefs Reload received; invalidating SpringBoard host-enable cache");
    LGInvalidateGlassPreferenceCache();
    dispatch_async(dispatch_get_main_queue(), ^{
        lgReconcileInjectionsForDisable();
        LGLog(@"prefs Reload reconciled material hosts; extraHandlers=%lu", (unsigned long)sReloadHandlers.count);
        for (void (^handler)(void) in [sReloadHandlers copy]) {
            handler();
        }
    });
}

static void lgReconcileInjectionsForDisable(void) {
    if (sGlassRecs.count > 0) {
        for (UIView *glass in [[sGlassRecs keyEnumerator] allObjects]) {
            LGGlassRec *rec = [sGlassRecs objectForKey:glass];
            if (!rec) continue;
            if (!lgHostEnabled(rec.prefix)) {
                if (rec.material) {
                    LGRemoveGlassFromMaterial(rec.material, kGlassKey);
                } else {
                    [glass removeFromSuperview];
                }
                [sGlassRecs removeObjectForKey:glass];
            }
        }
    }

    for (UIView *view in [[sSuppressed keyEnumerator] allObjects]) {
        NSString *prefix = [sSuppressed objectForKey:view];
        if (prefix && !lgHostEnabled(prefix)) {
            view.hidden = NO;
            [sSuppressed removeObjectForKey:view];
        }
    }
}

static void lgRouteMaterialHost(UIView *view) {
    if (!view.window) {
        LGRemoveGlassFromMaterial(view, kGlassKey);
        return;
    }

    for (LGMaterialHostRoute *route in sMaterialHostRoutes) {
        if (!route.matcher(view)) continue;

        CGFloat cornerRadius = route.cornerRadiusProvider ? route.cornerRadiusProvider(view) : -1.0;
        UIView *glass = LGInstallRegisteredGlassInMaterial(view, kGlassKey, route.prefix, route.outset, cornerRadius, route.groupName);
        if (glass && route.postInstall) {
            route.postInstall(view, glass);
        }
        return;
    }
}

%hook MTMaterialView

- (void)didMoveToWindow {
    %orig;
    lgRouteMaterialHost(self);
}

- (void)layoutSubviews {
    %orig;
    lgRouteMaterialHost(self);
}

- (void)setHidden:(BOOL)hidden {
    if (LGMaterialHasGlass(self, kGlassKey)) {
        hidden = YES;
    }
    %orig(hidden);
}

- (void)setFrame:(CGRect)frame {
    %orig;
    LGResyncGlassGeometry(self, kGlassKey);
}

- (void)setBounds:(CGRect)bounds {
    %orig;
    LGResyncGlassGeometry(self, kGlassKey);
}

- (void)setCenter:(CGPoint)center {
    %orig;
    LGResyncGlassGeometry(self, kGlassKey);
}

%end
