#import "LGLiveBackdropView.h"

#import <CoreFoundation/CoreFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <stdarg.h>
#import <string.h>
#import <unistd.h>

extern void LGLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

#pragma mark - Host Registry

typedef NS_ENUM(NSInteger, LGHostIdentifier) {
    LGHostIdentifierDefault = 0,
    LGHostIdentifierFolderIcon = 1,
    LGHostIdentifierOpenFolder = 2,
    LGHostIdentifierDock = 3,
    LGHostIdentifierBanner = 4,
    LGHostIdentifierNotification = 5,
    LGHostIdentifierControlCenter = 6,
    LGHostIdentifierAppLibrary = 7,
    LGHostIdentifierAppLibSearch = 8,
    LGHostIdentifierSpotlight = 9,
    LGHostIdentifierSearchPill = 10,
    LGHostIdentifierWidgets = 11,
    LGHostIdentifierContextMenu = 12,
    LGHostIdentifierAlerts = 13,
    LGHostIdentifierQuickActions = 14,
    LGHostIdentifierPasscode = 15,
    LGHostIdentifierClock = 16,
    LGHostIdentifierPrefsSlider = 17,
    LGHostIdentifierPrefsSwitch = 18,
    LGHostIdentifierPrefsButton = 19,
    LGHostIdentifierPrefsSegment = 20,
    LGHostIdentifierCoverSheet = 21,
    LGHostIdentifierTabBar = 22,
    LGHostIdentifierTabBarSelection = 23,
    LGHostIdentifierKeyboard = 24,
    LGHostIdentifierAppIcons = 25,
    LGHostIdentifierAssistiveTouch = 26,
    LGHostIdentifierVolumeHUD = 27,
    LGHostIdentifierPillHUD = 28,
    LGHostIdentifierCount = 29,
    LGHostIdentifierUnknown = 29
};

typedef struct {
    const char *name;
    const char *filterType;
    const char *preferencePrefix;
    float defaultCornerRadiusRatio;
    float defaultRefractionThickness;
    float defaultRefractionStrength;
    float defaultIOR;
    float defaultDispersion;
    float defaultBlurRadius;
    float defaultSpecularOpacity;
    float defaultEdgeScale;
    const char *defaultLightTintHex;
    const char *defaultDarkTintHex;
} LGHostDefinition;

static const LGHostDefinition kLGHostRegistry[LGHostIdentifierCount] = {
    { "Default",         "dylv.liquidglass.refraction",     "Default",         0.12727273f, 20.0f,  108.0f, 2.6f,  1.8f, 1.0f, 1.0f,  2.0f, "#FFFFFF1A", "#00000000" },
    { "FolderIcon",      "dylv.liquidglass.folder",         "FolderIcon",      0.12727273f, 13.75f, 108.0f, 2.6f,  1.8f, 1.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "OpenFolder",      "dylv.liquidglass.openfolder",     "OpenFolder",      0.12727273f, 36.0f,  108.0f, 2.6f,  1.8f, 0.0f, 1.0f,  0.0f, "#FFFFFF1A", "#00000000" },
    { "Dock",            "dylv.liquidglass.dock",           "Dock",            0.35f,       17.5f,  120.0f, 2.6f,  1.6f, 3.0f, 1.0f,  0.0f, "#FFFFFF1A", "#00000000" },
    { "Banner",          "dylv.liquidglass.banner",         "Banner",          0.12727273f, 20.75f, 132.0f, 1.6f,  1.6f, 3.0f, 1.0f,  0.0f, "#FFFFFFCC", "#00000080" },
    { "Notification",    "dylv.liquidglass.notification",   "Notification",    0.12727273f, 20.75f, 132.0f, 1.6f,  1.6f, 3.0f, 1.0f,  0.0f, "#FFFFFF66", "#00000000" },
    { "ControlCenter",   "dylv.liquidglass.cc",             "ControlCenter",   0.12727273f, 15.5f,  120.0f, 1.8f,  1.6f, 0.0f, 1.0f,  2.0f, "#FFFFFF1A", "#00000000" },
    { "AppLibrary",      "dylv.liquidglass.applibpod",      "AppLibrary",      0.12727273f, 25.0f,  120.0f, 2.2f,  1.6f, 0.0f, 1.0f,  2.0f, "#FFFFFF1A", "#00000000" },
    { "AppLibSearch",    "dylv.liquidglass.applibsearch",   "AppLibSearch",    0.5f,        25.0f,  108.0f, 1.8f,  1.6f, 0.0f, 1.0f,  2.0f, "#FFFFFF1A", "#00000000" },
    { "Spotlight",       "dylv.liquidglass.spotlight",      "Spotlight",       0.5f,        25.0f,  108.0f, 1.8f,  1.6f, 0.0f, 1.0f,  2.0f, "#FFFFFFCC", "#00000066" },
    { "SearchPill",      "dylv.liquidglass.searchpill",     "SearchPill",      0.5f,        10.0f,  108.0f, 1.6f,  1.6f, 1.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "Widgets",         "dylv.liquidglass.widget",         "Widgets",         0.12727273f, 30.0f,  120.0f, 2.2f,  1.6f, 1.0f, 1.0f,  0.0f, "#FFFFFF1A", "#0000001A" },
    { "ContextMenu",     "dylv.liquidglass.contextmenu",    "ContextMenu",     0.12727273f, 32.0f,  120.0f, 1.8f,  1.8f, 8.0f, 1.0f,  0.0f, "#FFFFFFCC", "#000000B3" },
    { "Alerts",          "dylv.liquidglass.alerts",         "Alerts",          0.12727273f, 32.0f,  120.0f, 1.6f,  1.6f, 3.0f, 1.0f,  0.0f, "#FFFFFFCC", "#000000B3" },
    { "QuickActions",    "dylv.liquidglass.quickaction",    "QuickActions",    0.5f,        12.0f,   96.0f, 1.6f,  1.4f, 1.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "Passcode",        "dylv.liquidglass.passcode",       "Passcode",        0.5f,        28.0f,   96.0f, 2.2f,  1.6f, 1.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000033" },
    { "Clock",           "dylv.liquidglass.clock",          "Clock",           0.0f,        12.0f,  120.0f, 1.6f,  1.6f, 2.0f, 1.0f,  0.0f, "#FFFFFF4C", "#FFFFFF4C" },
    { "PrefsSlider",     "dylv.liquidglass.prefsslider",    "PrefsSlider",     0.5f,        10.0f,  108.0f, 2.6f,  1.6f, 0.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "PrefsSwitch",     "dylv.liquidglass.prefsswitch",    "PrefsSwitch",     0.5f,         6.5f,  108.0f, 2.6f,  1.6f, 0.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "PrefsButton",     "dylv.liquidglass.prefsbutton",    "PrefsButton",     0.5f,        16.0f,  108.0f, 2.0f,  1.6f, 3.0f, 1.0f,  1.0f, "#FFFFFFCC", "#00000040" },
    { "PrefsSegment",    "dylv.liquidglass.prefssegment",   "PrefsSegment",    0.5f,         8.0f,  132.0f, 1.4f,  1.6f, 0.0f, 1.0f,  0.5f, "#FFFFFF1A", "#00000000" },
    { "CoverSheet",      "dylv.liquidglass.coversheet",     "CoverSheet",      0.0f,        64.0f,  192.0f, 1.4f,  1.6f, 0.0f, 0.0f,  2.0f, "#0000002E", "#0000002E" },
    { "TabBar",          "dylv.liquidglass.tabbar",         "TabBar",          0.5f,        20.0f,  108.0f, 2.2f,  1.8f, 3.0f, 1.0f,  2.0f, "#FFFFFFB3", "#00000040" },
    { "TabBarSelection", "dylv.liquidglass.tabbarselect",   "TabBarSelection", 0.5f,        12.0f,  132.0f, 1.4f,  1.6f, 0.0f, 1.0f,  0.5f, "#FFFFFF1A", "#00000020" },
    { "Keyboard",        "dylv.liquidglass.keyboard",       "Keyboard",        0.12727273f, 26.0f,  120.0f, 1.8f,  1.6f, 8.0f, 0.0f,  0.0f, "#D1D3D980", "#0000004d" },
    { "AppIcons",        "dylv.liquidglass.appicons",       "AppIcons",        0.12727273f, 13.75f, 108.0f, 2.6f,  1.8f, 1.0f, 1.0f,  1.0f, "#FFFFFF1A", "#00000000" },
    { "AssistiveTouch",  "dylv.liquidglass.assistivetouch", "AssistiveTouch",  0.5f,        22.8f,   18.0f, 2.75f, 2.1f, 0.5f, 0.35f, 0.0f, "#00000000", "#00000000" },
    { "VolumeHUD",       "dylv.liquidglass.volumehud",      "VolumeHUD",       0.5f,        28.0f,  280.0f, 3.0f,  3.2f, 5.0f, 0.35f, 1.2f, "#FFFFFF40", "#00000024" },
    { "PillHUD",         "dylv.liquidglass.pillhud",        "PillHUD",         0.5f,        17.5f,  120.0f, 2.2f,  1.7f, 1.0f, 0.35f, 1.2f, "#FFFFFF1A", "#0000002E" }
};

#pragma mark - Static State

static NSDictionary *sLGGlassPreferences = nil;
static NSHashTable<LGLiveBackdropView *> *sLGAllGlasses = nil;
static NSHashTable<LGLiveBackdropView *> *sLGMotionGlasses = nil;
static CMMotionManager *sLGMotionManager = nil;
static NSOperationQueue *sLGMotionQueue = nil;
static CADisplayLink *sLGMotionDisplayLink = nil;
static BOOL sLGFilterRefreshSetup = NO;
static BOOL sLGMotionSetup = NO;
static BOOL sLGMotionEnabled = NO;
static BOOL sLGMotionRunning = NO;

static double sLGTargetSpecularAngle = -M_PI_4;
static double sLGSpecularAngle = -M_PI_4;
static double sLGLastAppliedSpecularAngle = -100.0;
static double sLGMotionSensitivity = 2.0;
static double sLGMotionLoggedSensitivity = -1.0;
static double sLGLastTargetSpecularAngle = -M_PI_4;

static const void *kLGSpecularEnabledOverrideKey = &kLGSpecularEnabledOverrideKey;
static const void *kLGOutsetKey = &kLGOutsetKey;
static const void *kLGRadiusKey = &kLGRadiusKey;

#pragma mark - Forward Declarations

static NSString *LGGlassPreferencesPath(void);
static const LGHostDefinition *LGHostDefinitionForPreferencePrefix(const char *prefix);
static const LGHostDefinition *LGHostDefinitionForFilterType(const char *filterType);
static LGHostIdentifier LGHostIdentifierForDefinition(const LGHostDefinition *def);
static LGHostIdentifier LGHostIdentifierForFilterType(const char *filterType);
static void LGApplyMotionHighlightAngle(void);
static BOOL LGUsesDynamicRadiusType(NSString *filterType);
static void LGEnsureFilterRefreshObserver(void);
static void LGEnsureMotionHighlights(void);
static BOOL LGSpecularEnabledForFilterType(NSString *filterType);
static BOOL LGUsesPrefsControlCaptureScale(NSString *filterType);
static double LGQualityValue(void);
static double LGScaleBudget(void);
static double LGScaleForSize(CGSize size);
static double LGNativeBlurRadiusForFilterType(NSString *filterType);
static void sblog(const char *fmt, ...);
static BOOL LGNeedsGaussianIdentityFallback(void);
static CGRect LGOutsetFrame(CGRect frame, UIEdgeInsets outset);
static void LGSyncGlassGeometry(UIView *material, const void *assocKey, UIEdgeInsets outset, CGFloat cornerRadius);
static BOOL LGIsSpringBoardBundle(void);
static void LGReloadMotionHighlightPreferences(void);
static void LGRefreshMotionHighlights(void);
static void LGParametersReloaded(CFNotificationCenterRef center,
                                 void *observer,
                                 CFNotificationName name,
                                 const void *object,
                                 CFDictionaryRef userInfo);
static void LGMotionPreferencesDidChange(CFNotificationCenterRef center,
                                         void *observer,
                                         CFNotificationName name,
                                         const void *object,
                                         CFDictionaryRef userInfo);

#pragma mark - Preferences & Host Helpers

static NSString *LGGlassPreferencesPath(void) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        path = @"/var/mobile/Library/Preferences/dylv.liquidassprefs.plist";
    });
    return path;
}

id LGGlassPreferenceValue(NSString *key) {
    if (!key.length) {
        return nil;
    }
    @synchronized ([LGLiveBackdropView class]) {
        if (!sLGGlassPreferences) {
            NSDictionary *loaded = [NSDictionary dictionaryWithContentsOfFile:LGGlassPreferencesPath()];
            sLGGlassPreferences = loaded ?: @{};
        }
        return sLGGlassPreferences[key];
    }
}

void LGInvalidateGlassPreferenceCache(void) {
    @synchronized ([LGLiveBackdropView class]) {
        sLGGlassPreferences = nil;
    }
}

static const LGHostDefinition *LGHostDefinitionForPreferencePrefix(const char *prefix) {
    if (!prefix) {
        return NULL;
    }
    for (size_t i = 0; i < LGHostIdentifierCount; i++) {
        if (strcmp(kLGHostRegistry[i].preferencePrefix, prefix) == 0) {
            return &kLGHostRegistry[i];
        }
    }
    return NULL;
}

NSString *LGFilterTypeForHostPrefix(NSString *prefix) {
    if (!prefix.length) {
        return nil;
    }
    const LGHostDefinition *def = LGHostDefinitionForPreferencePrefix(prefix.UTF8String);
    return def ? [NSString stringWithUTF8String:def->filterType] : nil;
}

static const LGHostDefinition *LGHostDefinitionForFilterType(const char *filterType) {
    if (!filterType) {
        return NULL;
    }
    for (size_t i = 0; i < LGHostIdentifierCount; i++) {
        const char *base = kLGHostRegistry[i].filterType;
        size_t len = strlen(base);
        if (strncmp(filterType, base, len) == 0 && (filterType[len] == '\0' || filterType[len] == '.')) {
            return &kLGHostRegistry[i];
        }
    }
    return NULL;
}

static LGHostIdentifier LGHostIdentifierForDefinition(const LGHostDefinition *def) {
    if (!def) {
        return LGHostIdentifierUnknown;
    }
    return (LGHostIdentifier)(def - kLGHostRegistry);
}

static LGHostIdentifier LGHostIdentifierForFilterType(const char *filterType) {
    return LGHostIdentifierForDefinition(LGHostDefinitionForFilterType(filterType));
}

static BOOL LGUsesDynamicRadiusType(NSString *filterType) {
    if (filterType.length == 0) {
        return NO;
    }
    return LGHostIdentifierForFilterType(filterType.UTF8String) != LGHostIdentifierClock;
}

static BOOL LGSpecularEnabledForFilterType(NSString *filterType) {
    const LGHostDefinition *def = LGHostDefinitionForFilterType(filterType.UTF8String);
    if (def == &kLGHostRegistry[LGHostIdentifierCoverSheet]) {
        return NO;
    }
    if (def != NULL && def->defaultSpecularOpacity <= 0.001f) {
        return NO;
    }
    NSString *prefix = def ? [NSString stringWithUTF8String:def->preferencePrefix] : nil;
    if (!prefix.length) {
        return YES;
    }
    id val = LGGlassPreferenceValue([prefix stringByAppendingString:@".SpecularEnabled"]);
    return [val isKindOfClass:[NSNumber class]] ? [val boolValue] : YES;
}

static BOOL LGUsesPrefsControlCaptureScale(NSString *filterType) {
    LGHostIdentifier hostId = LGHostIdentifierForFilterType(filterType.UTF8String);
    return hostId >= LGHostIdentifierPrefsSlider && hostId <= LGHostIdentifierPrefsSegment;
}

static double LGQualityValue(void) {
    id val = LGGlassPreferenceValue(@"Global.Quality");
    double quality = [val respondsToSelector:@selector(doubleValue)] ? [val doubleValue] : 1.0;
    if (!isfinite(quality)) {
        quality = 1.0;
    }
    return fmin(1.0, fmax(0.1, quality));
}

static double LGScaleBudget(void) {
    return 8000.0 * LGQualityValue();
}

static double LGScaleForSize(CGSize size) {
    double area = size.width * size.height;
    if (area <= 1.0) {
        return 0.75;
    }
    double scale = sqrt(LGScaleBudget() / area);
    return fmin(0.75, fmax(0.25, scale));
}

static double LGNativeBlurRadiusForFilterType(NSString *filterType) {
    const LGHostDefinition *def = LGHostDefinitionForFilterType(filterType.UTF8String);
    if (!def) {
        return 0.0;
    }
    NSString *prefix = [NSString stringWithUTF8String:def->preferencePrefix];
    id val = LGGlassPreferenceValue([prefix stringByAppendingString:@".Blur"]);
    if ([val respondsToSelector:@selector(doubleValue)]) {
        return MAX(0.0, [val doubleValue]);
    }
    return (double)def->defaultBlurRadius;
}

static void sblog(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *format = [NSString stringWithUTF8String:(fmt ?: "")];
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    LGLog(@"[LGSB] %@", message);
}

static BOOL LGNeedsGaussianIdentityFallback(void) {
    return access("/var/mobile/Library/Accessibility/liquidass-gaussian-identity-state.bin", F_OK) == 0;
}

static BOOL LGIsSpringBoardBundle(void) {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

#pragma mark - Motion Highlights

@interface LGMotionDisplayLinkTarget : NSObject
- (void)tick:(CADisplayLink *)link;
@end

@implementation LGMotionDisplayLinkTarget

- (void)tick:(CADisplayLink *)link {
    CFTimeInterval dt = (link.targetTimestamp > link.timestamp)
                            ? (link.targetTimestamp - link.timestamp)
                            : (1.0 / 60.0);
    double diff = atan2(sin(sLGTargetSpecularAngle - sLGSpecularAngle),
                        cos(sLGTargetSpecularAngle - sLGSpecularAngle));
    if (fabs(diff) < 0.001) {
        sLGSpecularAngle = sLGTargetSpecularAngle;
        LGApplyMotionHighlightAngle();
        link.paused = YES;
        return;
    }
    double alpha = 1.0 - exp(-14.0 * dt);
    sLGSpecularAngle += diff * alpha;
    LGApplyMotionHighlightAngle();
}

@end

static void LGApplyMotionHighlightAngle(void) {
    if (sLGMotionGlasses.count == 0) {
        return;
    }
    if (sLGMotionDisplayLink &&
        sLGMotionDisplayLink.isPaused &&
        fabs(sLGSpecularAngle - sLGLastAppliedSpecularAngle) < 0.001) {
        return;
    }
    sLGLastAppliedSpecularAngle = sLGSpecularAngle;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (LGLiveBackdropView *view in [sLGMotionGlasses allObjects]) {
        UIWindow *window = view.window;
        if (!window ||
            view.isHidden ||
            view.alpha <= 0.01 ||
            window.isHidden ||
            window.alpha <= 0.01) {
            continue;
        }
        CGRect bounds = view.bounds;
        if (CGRectIsEmpty(bounds) ||
            !CGRectIntersectsRect(window.bounds, [view convertRect:bounds toView:nil])) {
            continue;
        }
        [view applySpecularAngle:sLGSpecularAngle];
    }
    [CATransaction commit];
}

static void LGReloadMotionHighlightPreferences(void) {
    id enabledVal = LGGlassPreferenceValue(@"Specular.Motion.Enabled");
    id sensitivityVal = LGGlassPreferenceValue(@"Specular.Motion.Sensitivity");
    BOOL prevEnabled = sLGMotionEnabled;
    double prevSensitivity = sLGMotionSensitivity;

    sLGMotionEnabled = [enabledVal respondsToSelector:@selector(boolValue)] ? [enabledVal boolValue] : NO;
    double sensitivity = [sensitivityVal respondsToSelector:@selector(doubleValue)] ? [sensitivityVal doubleValue] : 2.0;
    sLGMotionSensitivity = MAX(0.0, MIN(8.0, sensitivity));

    if (sLGMotionLoggedSensitivity < 0.0 ||
        prevEnabled != sLGMotionEnabled ||
        fabs(prevSensitivity - sLGMotionSensitivity) > 0.01) {
        sLGMotionLoggedSensitivity = sLGMotionSensitivity;
        LGLog(@"motion highlights prefs enabled=%d sensitivity=%.2f",
              sLGMotionEnabled,
              sLGMotionSensitivity);
    }
}

static void LGRefreshMotionHighlights(void) {
    if (!sLGMotionSetup || !LGIsSpringBoardBundle()) {
        return;
    }
    if (!sLGMotionEnabled) {
        [sLGMotionManager stopDeviceMotionUpdates];
        [sLGMotionDisplayLink invalidate];
        sLGMotionDisplayLink = nil;
        sLGMotionRunning = NO;
        sLGSpecularAngle = -M_PI_4;
        sLGTargetSpecularAngle = sLGSpecularAngle;
        sLGLastAppliedSpecularAngle = -100.0;
        LGApplyMotionHighlightAngle();
        return;
    }
    if (sLGMotionRunning) {
        return;
    }
    if (!sLGMotionQueue) {
        sLGMotionQueue = [[NSOperationQueue alloc] init];
        sLGMotionQueue.name = @"com.ngkhoi.liquidass.motion";
        sLGMotionQueue.maxConcurrentOperationCount = 1;
        sLGMotionQueue.qualityOfService = NSQualityOfServiceUtility;
    }
    CMAttitudeReferenceFrame referenceFrame = CMAttitudeReferenceFrameXArbitraryZVertical;
    sLGMotionManager.deviceMotionUpdateInterval = 1.0 / 30.0;

    static LGMotionDisplayLinkTarget *displayLinkTarget = nil;
    if (!displayLinkTarget) {
        displayLinkTarget = [LGMotionDisplayLinkTarget new];
    }
    if (!sLGMotionDisplayLink) {
        sLGMotionDisplayLink = [CADisplayLink displayLinkWithTarget:displayLinkTarget selector:@selector(tick:)];
        [sLGMotionDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    sLGMotionRunning = YES;
    [sLGMotionManager startDeviceMotionUpdatesUsingReferenceFrame:referenceFrame
                                                          toQueue:sLGMotionQueue
                                                      withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (!motion || error || !sLGMotionEnabled) {
            return;
        }
        CMAttitude *attitude = motion.attitude;
        double combined = (attitude.roll * 1.2 + attitude.pitch * 1.2) + attitude.yaw;
        double target = combined * (sLGMotionSensitivity * 1.2);
        double delta = atan2(sin(target - sLGLastTargetSpecularAngle),
                             cos(target - sLGLastTargetSpecularAngle));
        if (fabs(delta) <= 0.001) {
            return;
        }
        sLGLastTargetSpecularAngle = target;
        sLGTargetSpecularAngle = target;
        if (sLGMotionDisplayLink && sLGMotionDisplayLink.isPaused) {
            dispatch_async(dispatch_get_main_queue(), ^{
                sLGMotionDisplayLink.paused = NO;
            });
        }
    }];
    LGLog(@"motion highlights started reference=tilt+yaw rate=30Hz high-sensitivity");
}

static void LGMotionPreferencesDidChange(CFNotificationCenterRef center,
                                         void *observer,
                                         CFNotificationName name,
                                         const void *object,
                                         CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        LGInvalidateGlassPreferenceCache();
        LGReloadMotionHighlightPreferences();
        LGRefreshMotionHighlights();
    });
}

static void LGEnsureMotionHighlights(void) {
    if (!LGIsSpringBoardBundle()) {
        return;
    }
    if (!sLGMotionGlasses) {
        sLGMotionGlasses = [NSHashTable weakObjectsHashTable];
    }
    if (!sLGMotionManager) {
        sLGMotionManager = [CMMotionManager new];
    }
    if (!sLGMotionSetup) {
        sLGMotionSetup = YES;
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LGMotionPreferencesDidChange,
                                        CFSTR("dylv.liquidassprefs/Reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    LGReloadMotionHighlightPreferences();
    LGRefreshMotionHighlights();
}

static void LGParametersReloaded(CFNotificationCenterRef center,
                                 void *observer,
                                 CFNotificationName name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        LGInvalidateGlassPreferenceCache();
        NSArray<LGLiveBackdropView *> *glasses = [sLGAllGlasses allObjects];
        LGLog(@"render parameters ready; refreshing %lu live filters", (unsigned long)glasses.count);
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        for (LGLiveBackdropView *glass in glasses) {
            [glass reapplyFilterForParameterReload];
        }
        [CATransaction commit];
    });
}

static void LGEnsureFilterRefreshObserver(void) {
    if (!sLGAllGlasses) {
        sLGAllGlasses = [NSHashTable weakObjectsHashTable];
    }
    if (sLGFilterRefreshSetup) {
        return;
    }
    sLGFilterRefreshSetup = YES;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    LGParametersReloaded,
                                    CFSTR("dylv.liquidglass/ParametersReloaded"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

#pragma mark - LGLiveBackdropView

@implementation LGLiveBackdropView {
    NSString *_lgGroupName;
    CAGradientLayer *_specularLayer;
    CAShapeLayer *_specularMask;
    CAShapeLayer *_edge;
    UIView *_nativeBlurView;
    double _nativeBlurRadius;
    BOOL _backdropConfigured;
    BOOL _filterAttached;
    uint32_t _lgId;
    double _appliedScale;
    double _appliedBackdropZoom;
    BOOL _parameterRefreshVariant;
    NSInteger _lastRadiusStep;
    double _appliedSpecularOpacity;
}

+ (Class)layerClass {
    Class cls = NSClassFromString(@"CABackdropLayer");
    return cls ?: [CALayer class];
}

- (NSString *)lgEffectiveFilterType {
    if (!_lgFilterType.length) {
        return [NSString stringWithUTF8String:kLGHostRegistry[LGHostIdentifierDefault].filterType];
    }
    NSString *base = _lgFilterType;
    if (LGUsesDynamicRadiusType(base) && !CGRectIsEmpty(self.bounds)) {
        CGFloat minDim = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
        BOOL isKeyboard = (LGHostIdentifierForFilterType(base.UTF8String) == LGHostIdentifierKeyboard);
        CGFloat radius = isKeyboard ? _lgShapeCornerRadius : self.layer.cornerRadius;
        CGFloat ratio = (minDim > 0.0) ? (radius / minDim) : 0.0;
        CGFloat clamped = MAX(0.0, MIN(0.5, ratio));
        double scaled = clamped * 32.0;
        NSInteger step = llround(scaled);
        if (_lastRadiusStep >= 0 && fabs(scaled - (double)_lastRadiusStep) < 0.75) {
            step = _lastRadiusStep;
        }
        _lastRadiusStep = step;
        base = [base stringByAppendingFormat:@".r%ld", (long)step];
    }
    NSString *result = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
                           ? [base stringByAppendingString:@".dark"]
                           : base;
    if (_parameterRefreshVariant) {
        result = [result stringByAppendingString:@".refresh"];
    }
    return result;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame groupName:nil filterType:nil];
}

- (instancetype)initWithFrame:(CGRect)frame groupName:(NSString *)groupName {
    return [self initWithFrame:frame groupName:groupName filterType:nil];
}

- (instancetype)initWithFrame:(CGRect)frame
                    groupName:(NSString *)groupName
                   filterType:(NSString *)filterType {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    _lastRadiusStep = -1;
    _appliedSpecularOpacity = -1.0;
    _lgShapeRect = CGRectNull;
    _lgFilterType = [filterType copy];

    static _Atomic(uint32_t) idCounter = 0;
    _lgId = atomic_fetch_add(&idCounter, 1) + 1;

    if (groupName.length > 0) {
        _lgGroupName = [groupName copy];
    } else {
        static uint32_t salt = 0;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            salt = arc4random();
        });
        _lgGroupName = [NSString stringWithFormat:@"dylv.liquidglass.p%d.%08x.g%u",
                        getpid(),
                        salt,
                        _lgId];
    }

    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    LGEnsureFilterRefreshObserver();
    [sLGAllGlasses addObject:self];
    LGEnsureMotionHighlights();
    [sLGMotionGlasses addObject:self];
    [self applyFilters];
    return self;
}

- (void)dealloc {
    [sLGAllGlasses removeObject:self];
    [sLGMotionGlasses removeObject:self];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self applyFilters];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        _filterAttached = NO;
        [self applyFilters];
        [self updateSpecular];
    }
}

- (NSNumber *)lgSpecularEnabledOverride {
    return objc_getAssociatedObject(self, kLGSpecularEnabledOverrideKey);
}

- (void)setLgSpecularEnabledOverride:(NSNumber *)lgSpecularEnabledOverride {
    NSNumber *current = [self lgSpecularEnabledOverride];
    if (current == lgSpecularEnabledOverride || [current isEqualToNumber:lgSpecularEnabledOverride]) {
        return;
    }
    objc_setAssociatedObject(self,
                             kLGSpecularEnabledOverrideKey,
                             [lgSpecularEnabledOverride copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self updateSpecular];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyFilters];
    [self updateSpecular];
}

- (void)updateNativeBlurOverlayWithRadius:(CGFloat)radius {
    if (radius <= 0.0) {
        [_nativeBlurView removeFromSuperview];
        _nativeBlurView = nil;
        _nativeBlurRadius = 0.0;
        return;
    }
    if (!_nativeBlurView) {
        Class cls = NSClassFromString(@"LGSettingsLowBlurView");
        if (!cls) {
            return;
        }
        _nativeBlurView = [[cls alloc] initWithFrame:self.bounds];
        _nativeBlurView.userInteractionEnabled = NO;
        [self insertSubview:_nativeBlurView atIndex:0];
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _nativeBlurView.frame = self.bounds;
    _nativeBlurView.layer.cornerRadius = self.layer.cornerRadius;
    _nativeBlurView.layer.cornerCurve = self.layer.cornerCurve;
    _nativeBlurView.clipsToBounds = YES;
    if (fabs(_nativeBlurRadius - radius) > 0.001) {
        @try {
            [_nativeBlurView setValue:@(radius) forKey:@"lgBlurRadius"];
        } @catch (NSException *exception) {
        }
        _nativeBlurRadius = radius;
    }
    [CATransaction commit];
}

- (void)setLgShapeRect:(CGRect)lgShapeRect {
    if (CGRectEqualToRect(_lgShapeRect, lgShapeRect)) {
        return;
    }
    _lgShapeRect = lgShapeRect;
    if (LGHostIdentifierForFilterType(_lgFilterType.UTF8String) == LGHostIdentifierKeyboard) {
        _filterAttached = NO;
        [self applyFilters];
    }
    [self updateSpecular];
}

- (void)setLgShapeCornerRadius:(CGFloat)lgShapeCornerRadius {
    if (fabs(_lgShapeCornerRadius - lgShapeCornerRadius) < 0.01) {
        return;
    }
    _lgShapeCornerRadius = lgShapeCornerRadius;
    if (LGHostIdentifierForFilterType(_lgFilterType.UTF8String) == LGHostIdentifierKeyboard) {
        _filterAttached = NO;
        [self applyFilters];
    }
    [self updateSpecular];
}

- (void)updateSpecular {
    if (CGRectIsEmpty(self.bounds)) {
        return;
    }
    BOOL hasShapeRect = !CGRectIsNull(_lgShapeRect) && !CGRectIsEmpty(_lgShapeRect);
    CGRect targetRect = hasShapeRect ? _lgShapeRect : self.bounds;
    CGFloat cornerRadius = hasShapeRect ? _lgShapeCornerRadius : self.layer.cornerRadius;

    NSNumber *override = [self lgSpecularEnabledOverride];
    BOOL specularEnabled = override ? [override boolValue] : LGSpecularEnabledForFilterType(_lgFilterType);

    const LGHostDefinition *def = LGHostDefinitionForFilterType(_lgFilterType.UTF8String);
    if (def == &kLGHostRegistry[LGHostIdentifierClock]) {
        return;
    }
    if (!specularEnabled && !_specularLayer) {
        return;
    }

    if (!_edge) {
        _edge = [CAShapeLayer layer];
        _edge.backgroundColor = [UIColor clearColor].CGColor;
        _edge.borderWidth = 1.0;
        [self.layer addSublayer:_edge];
    }

    double opacity = 0.35;
    if (def) {
        NSString *prefix = [NSString stringWithUTF8String:def->preferencePrefix];
        id val = prefix.length ? LGGlassPreferenceValue([prefix stringByAppendingString:@".SpecularOpacity"]) : nil;
        if ([val respondsToSelector:@selector(doubleValue)]) {
            opacity = [val doubleValue];
        } else if (def->defaultSpecularOpacity > 0.001f) {
            opacity = (double)def->defaultSpecularOpacity;
        }
    }
    opacity = fmax(0.0, fmin(1.0, opacity));

    if (!_specularLayer) {
        _specularLayer = [CAGradientLayer layer];
        _specularLayer.locations = @[@0.0, @0.12, @0.34, @0.66, @0.88, @1.0];

        _specularMask = [CAShapeLayer layer];
        _specularMask.backgroundColor = [UIColor clearColor].CGColor;
        _specularMask.borderColor = [UIColor blackColor].CGColor;
        _specularMask.borderWidth = 1.0;

        _specularLayer.mask = _specularMask;
        [self.layer addSublayer:_specularLayer];
    }

    if (fabs(_appliedSpecularOpacity - opacity) > 0.001) {
        id clearCG = (id)[UIColor clearColor].CGColor;
        _specularLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:opacity * 0.28].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:opacity * 0.10].CGColor,
            clearCG,
            clearCG,
            (id)[UIColor colorWithWhite:0.0 alpha:opacity * 0.04].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:opacity * 0.12].CGColor
        ];
        _appliedSpecularOpacity = opacity;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _specularLayer.hidden = !specularEnabled;
    _specularLayer.frame = targetRect;

    UIColor *edgeColor = [[UIColor separatorColor] colorWithAlphaComponent:0.16];
    if (@available(iOS 13.0, *)) {
        edgeColor = [edgeColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    _edge.hidden = NO;
    _edge.frame = targetRect;
    _edge.cornerRadius = cornerRadius;
    _edge.cornerCurve = self.layer.cornerCurve;
    _edge.borderWidth = 1.0;
    _edge.borderColor = edgeColor.CGColor;

    _specularMask.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(targetRect), CGRectGetHeight(targetRect));
    _specularMask.cornerRadius = cornerRadius;
    _specularMask.cornerCurve = self.layer.cornerCurve;
    _specularMask.borderWidth = 1.0;
    [CATransaction commit];

    [self applySpecularAngle:sLGSpecularAngle];
}

- (void)applySpecularAngle:(double)angle {
    if (!_specularLayer) {
        return;
    }
    CGFloat dx = cos(angle) * 0.5;
    CGFloat dy = sin(angle) * 0.5;
    _specularLayer.startPoint = CGPointMake(0.5 + dx, 0.5 + dy);
    _specularLayer.endPoint = CGPointMake(0.5 - dx, 0.5 - dy);
}

- (void)applyFilters {
    CALayer *layer = self.layer;
    Class backdropClass = NSClassFromString(@"CABackdropLayer");
    if (!backdropClass || ![layer isKindOfClass:backdropClass]) {
        return;
    }

    @try {
        if (!_backdropConfigured) {
            [layer setValue:@NO forKey:@"layerUsesCoreImageFilters"];
            [layer setValue:@NO forKey:@"windowServerAware"];
            [layer setValue:_lgGroupName forKey:@"groupName"];
            [layer setValue:@"dylv.liquidglass" forKey:@"groupNamespace"];
            [layer setValue:@YES forKey:@"ignoresScreenClip"];
            _backdropConfigured = YES;
        }

        LGHostIdentifier hostId = LGHostIdentifierForFilterType(_lgFilterType.UTF8String);
        double scale;
        if (hostId == LGHostIdentifierClock) {
            scale = 0.5;
        } else if (hostId == LGHostIdentifierCoverSheet ||
                   hostId == LGHostIdentifierTabBar ||
                   hostId == LGHostIdentifierTabBarSelection) {
            scale = 1.0;
        } else {
            scale = LGUsesPrefsControlCaptureScale(_lgFilterType) ? 1.5 : LGScaleForSize(self.bounds.size);
        }

        double wantZoom = (_lgBackdropZoom > 0.0) ? _lgBackdropZoom : 1.0;
        BOOL needsZoom = (fabs(wantZoom - 1.0) > 0.001) || (_appliedBackdropZoom > 0.0);
        if (needsZoom && fabs(wantZoom - _appliedBackdropZoom) > 0.001) {
            _appliedBackdropZoom = wantZoom;
            @try {
                [layer setValue:@(wantZoom) forKey:@"zoom"];
            } @catch (NSException *exception) {
            }
            id readback = [layer valueForKey:@"zoom"];
            LGLog(@"glass#%u zoom type=%@ want=%.3f readback=%@",
                  _lgId,
                  _lgFilterType ?: @"default",
                  wantZoom,
                  readback ?: @"<none>");
        }

        if (fabs(scale - _appliedScale) > 0.02) {
            [layer setValue:@(scale) forKey:@"scale"];
            _appliedScale = scale;
        }

        NSString *effectiveType = [self lgEffectiveFilterType];
        NSArray *existingFilters = layer.filters;
        Class caFilterClass = NSClassFromString(@"CAFilter");

        [self updateNativeBlurOverlayWithRadius:LGNativeBlurRadiusForFilterType(_lgFilterType ?: effectiveType)];

        if (_filterAttached && existingFilters.count == 1) {
            NSString *currentType = nil;
            @try {
                currentType = [existingFilters.firstObject valueForKey:@"type"];
            } @catch (NSException *exception) {
            }
            if ([currentType isEqualToString:effectiveType]) {
                return;
            }
        }

        if (!caFilterClass) {
            sblog("CAFilter class not found");
            return;
        }

        SEL filterSel = NSSelectorFromString(@"filterWithType:");
        id (*filterWithTypeIMP)(id, SEL, NSString *) = (id (*)(id, SEL, NSString *))objc_msgSend;
        id filter = filterWithTypeIMP(caFilterClass, filterSel, effectiveType);
        if (!filter) {
            LGLog(@"glass#%u filterWithType nil (not registered yet?)", _lgId);
            return;
        }

        if (LGNeedsGaussianIdentityFallback()) {
            @try {
                [filter setValue:@1.0 forKey:@"inputRadius"];
            } @catch (NSException *exception) {
            }
        }

        layer.filters = @[filter];
        _filterAttached = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LGLiveBackdropViewFilterDidAttach" object:self];
    } @catch (NSException *exception) {
        sblog("applyFilters exception: %s", exception.reason.UTF8String);
    }
}

- (void)reapplyFilterForParameterReload {
    _parameterRefreshVariant = !_parameterRefreshVariant;
    _appliedScale = -1.0;
    _filterAttached = NO;
    [self applyFilters];
    [self updateSpecular];
    [self.layer setNeedsDisplay];
    [_specularLayer setNeedsDisplay];
}

- (void)lgInvalidateFilterContents {
    _parameterRefreshVariant = !_parameterRefreshVariant;
    _filterAttached = NO;
    [self applyFilters];
    [self.layer setNeedsDisplay];
}

- (BOOL)lgFilterAttached {
    return _filterAttached;
}

@end

#pragma mark - Material Glass Injection & Geometry Sync

static CGRect LGOutsetFrame(CGRect frame, UIEdgeInsets outset) {
    return CGRectMake(frame.origin.x - outset.left,
                      frame.origin.y - outset.top,
                      frame.size.width + outset.left + outset.right,
                      frame.size.height + outset.top + outset.bottom);
}

void LGInjectGlassIntoMaterialGroupType(UIView *material,
                                        const void *assocKey,
                                        UIEdgeInsets outset,
                                        CGFloat cornerRadius,
                                        NSString *groupName,
                                        NSString *filterType) {
    UIView *superview = material.superview;
    if (!superview) {
        return;
    }

    CGRect targetFrame = LGOutsetFrame(material.frame, outset);
    LGLiveBackdropView *glass = objc_getAssociatedObject(material, assocKey);
    if (!glass) {
        glass = [[LGLiveBackdropView alloc] initWithFrame:targetFrame
                                                groupName:groupName
                                               filterType:filterType];
        __weak LGLiveBackdropView *weakGlass = glass;
        for (NSNumber *delay in @[@1.5, @3.0, @5.0, @8.0, @12.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * (double)NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [weakGlass applyFilters];
            });
        }
        [superview insertSubview:glass aboveSubview:material];
        objc_setAssociatedObject(material, assocKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (glass.superview != superview) {
        [superview insertSubview:glass aboveSubview:material];
    }

    CGFloat effectiveRadius = (cornerRadius >= 0.0) ? cornerRadius : material.layer.cornerRadius;
    if (!CGRectEqualToRect(glass.frame, targetFrame)) {
        glass.frame = targetFrame;
    }

    if (fabs(glass.layer.cornerRadius - effectiveRadius) > 0.5) {
        glass.layer.cornerRadius = effectiveRadius;
        [glass updateSpecular];
        [glass applyFilters];
    }

    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.masksToBounds = YES;
    objc_setAssociatedObject(glass,
                             kLGOutsetKey,
                             [NSValue valueWithUIEdgeInsets:outset],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(glass,
                             kLGRadiusKey,
                             @(cornerRadius),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (!material.isHidden) {
        material.hidden = YES;
    }
}

static void LGSyncGlassGeometry(UIView *material,
                                const void *assocKey,
                                UIEdgeInsets outset,
                                CGFloat cornerRadius) {
    LGLiveBackdropView *glass = objc_getAssociatedObject(material, assocKey);
    if (!glass) {
        return;
    }

    CGRect targetFrame = LGOutsetFrame(material.frame, outset);
    CGFloat effectiveRadius = (cornerRadius >= 0.0) ? cornerRadius : material.layer.cornerRadius;

    if (!CGRectEqualToRect(glass.frame, targetFrame)) {
        glass.frame = targetFrame;
    }

    if (fabs(glass.layer.cornerRadius - effectiveRadius) > 0.5) {
        glass.layer.cornerRadius = effectiveRadius;
        [glass updateSpecular];
        [glass applyFilters];
    }

    if (!material.isHidden) {
        material.hidden = YES;
    }
}

void LGResyncGlassGeometry(UIView *material, const void *assocKey) {
    LGLiveBackdropView *glass = objc_getAssociatedObject(material, assocKey);
    if (!glass) {
        return;
    }
    NSValue *outsetVal = objc_getAssociatedObject(glass, kLGOutsetKey);
    NSNumber *radiusVal = objc_getAssociatedObject(glass, kLGRadiusKey);
    UIEdgeInsets outset = outsetVal ? [outsetVal UIEdgeInsetsValue] : UIEdgeInsetsZero;
    CGFloat radius = radiusVal ? [radiusVal doubleValue] : -1.0;
    LGSyncGlassGeometry(material, assocKey, outset, radius);
}

void LGRemoveGlassFromMaterial(UIView *material, const void *assocKey) {
    LGLiveBackdropView *glass = objc_getAssociatedObject(material, assocKey);
    if (!glass) {
        return;
    }
    objc_setAssociatedObject(material, assocKey, nil, OBJC_ASSOCIATION_ASSIGN);
    material.hidden = NO;
    [glass removeFromSuperview];
}

BOOL LGMaterialHasGlass(UIView *material, const void *assocKey) {
    return objc_getAssociatedObject(material, assocKey) != nil;
}
