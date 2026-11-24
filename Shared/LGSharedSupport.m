#import "LGSharedSupport.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <stdarg.h>
#import <stdlib.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <unistd.h>

typedef struct {
    uint32_t magic;
    uint32_t version;
    int64_t bootTime;
    uint8_t reserved[12];
    uint32_t active;
} LGBackboardSafeModeState;

static const char *kLGBackboardSafeModeStatePath = "/var/mobile/Library/Accessibility/liquidass-backboardd-guard.bin";
static const char *kLGBackboardSafeModePendingPath = "/var/mobile/Library/Accessibility/liquidass-backboardd-alert";
static const void *kLGImageStableCacheKeyAssociation = &kLGImageStableCacheKeyAssociation;

static os_unfair_lock sLGPrefsLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *sLGCachedPreferences = nil;
static dispatch_once_t sLGPrefsSetupOnce = 0;

static dispatch_queue_t sLGLogQueue = nil;
static NSFileHandle *sLGLogHandle = nil;

static NSDictionary *LGCopyPreferencesDictionary(void);
static void LGEnsurePreferenceCacheInitialized(void);
static id LGPreferenceValue(NSString *key);
static void LGPreferencesChanged(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo);
static NSString *LGLogFilePath(void);
static void LGAppendLogLine(NSString *line);
static void LGCloseLogHandle(void);
static void LGCloseLogHandleAtExit(void);

BOOL LGBackboardSafeModeActive(void) {
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:kLGBackboardSafeModeStatePath]];
    if (data.length != sizeof(LGBackboardSafeModeState)) {
        return NO;
    }

    LGBackboardSafeModeState state = {0};
    [data getBytes:&state length:sizeof(state)];
    if (state.magic != 0x4C47534DU || state.version != 1 || state.active == 0) {
        return NO;
    }

    struct timeval bootTime = {0};
    size_t bootTimeSize = sizeof(bootTime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &bootTime, &bootTimeSize, NULL, 0) != 0) {
        return NO;
    }

    return state.bootTime == (int64_t)bootTime.tv_sec;
}

void LGClearBackboardSafeMode(void) {
    unlink(kLGBackboardSafeModeStatePath);
    unlink(kLGBackboardSafeModePendingPath);
}

NSString *LGMainBundleIdentifier(void) {
    static NSString *bundleID = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bundleID = [NSBundle.mainBundle.bundleIdentifier copy] ?: @"";
    });
    return bundleID;
}

BOOL LGIsSpringBoardProcess(void) {
    return [LGMainBundleIdentifier() isEqualToString:@"com.apple.springboard"];
}

BOOL LGIsPreferencesProcess(void) {
    return [LGMainBundleIdentifier() isEqualToString:@"com.apple.Preferences"];
}

BOOL LGIsExcludedSystemProcess(void) {
    static BOOL excluded = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bundleID = (LGMainBundleIdentifier() ?: @"").lowercaseString;
        NSString *execName = (NSBundle.mainBundle.executablePath ?: @"").lastPathComponent.lowercaseString;
        NSString *processName = (NSProcessInfo.processInfo.processName ?: @"").lowercaseString;

        if ([bundleID isEqualToString:@"com.apple.springboard"] ||
            [bundleID isEqualToString:@"com.apple.preferences"] ||
            [bundleID isEqualToString:@"com.apple.mobilesafari"]) {
            return;
        }

        if (bundleID.length == 0) {
            excluded = YES;
            return;
        }

        NSArray<NSString *> *excludedTokens = @[
            @"assistivetouchd",
            @"posterboard",
            @"posterextension",
            @"wallpaper",
            @"widgetrenderer",
            @"chronod",
            @"backboardd",
            @"sharingd",
            @"bluetoothd",
            @"wifid",
            @"powerlog",
            @"coreauthui",
        ];

        for (NSString *token in excludedTokens) {
            if ([bundleID containsString:token] ||
                [execName containsString:token] ||
                [processName containsString:token]) {
                excluded = YES;
                return;
            }
        }
    });
    return excluded;
}

BOOL LGIsAtLeastiOS16(void) {
    static BOOL cached = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion version = {16, 0, 0};
        cached = [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:version];
    });
    return cached;
}

NSString *LGRWBDefaultWidgetBundleIDsText(void) {
    static NSString *text = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *bundleIDs = @[
            @"com.apple.mobiletimer.WorldClockWidget",
            @"com.apple.mobilecal.CalendarWidgetExtension",
            @"com.apple.mobilemail.MailWidgetExtension",
            @"com.apple.ScreenTimeWidgetApplication.ScreenTimeWidgetExtension",
            @"com.apple.reminders.WidgetExtension",
            @"com.apple.weather.widget",
            @"com.apple.Fitness.FitnessWidget",
            @"com.apple.Passbook.PassbookWidgets",
            @"com.apple.Health.Sleep.SleepWidgetExtension",
            @"com.apple.tips.TipsSwift",
            @"com.apple.Music.MusicWidgets",
            @"com.apple.gamecenter.widgets.extension",
            @"com.apple.tv.TVWidgetExtension",
            @"com.apple.news.widget",
            @"com.apple.Maps.GeneralMapsWidget",
        ];
        text = [bundleIDs componentsJoinedByString:@"\n"];
    });
    return text;
}

CGFloat LGEffectiveBannerBlur(CGFloat blur) {
    return fmin(80.0, fmax(0.0, blur) * 2.2);
}

void LGReloadPreferences(void) {
    NSDictionary *prefs = LGCopyPreferencesDictionary();
    os_unfair_lock_lock(&sLGPrefsLock);
    sLGCachedPreferences = prefs;
    os_unfair_lock_unlock(&sLGPrefsLock);
}

static NSDictionary *LGCopyPreferencesDictionary(void) {
    CFStringRef domain = CFSTR("dylv.liquidassprefs");
    CFPreferencesAppSynchronize(domain);
    NSDictionary *prefs = CFBridgingRelease(CFPreferencesCopyMultiple(NULL,
                                                                      domain,
                                                                      kCFPreferencesCurrentUser,
                                                                      kCFPreferencesAnyHost));
    if (![prefs isKindOfClass:[NSDictionary class]]) {
        return @{};
    }
    return prefs;
}

void LGObservePreferenceChanges(dispatch_block_t handler) {
    if (!handler) {
        return;
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:@"dylv.liquidassprefs.InProcessReload"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        (void)note;
        handler();
    }];
}

BOOL LGHasExplicitPreferenceValue(NSString *key) {
    if (key.length == 0) {
        return NO;
    }
    LGEnsurePreferenceCacheInitialized();
    NSDictionary *prefs = nil;
    os_unfair_lock_lock(&sLGPrefsLock);
    prefs = sLGCachedPreferences;
    os_unfair_lock_unlock(&sLGPrefsLock);
    return prefs[key] != nil;
}

static void LGEnsurePreferenceCacheInitialized(void) {
    dispatch_once(&sLGPrefsSetupOnce, ^{
        LGReloadPreferences();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LGPreferencesChanged,
                                        CFSTR("dylv.liquidassprefs/Reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

BOOL LG_prefBool(NSString *key, BOOL fallback) {
    id value = LGPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value boolValue];
    }
    return fallback;
}

static id LGPreferenceValue(NSString *key) {
    if (key.length == 0) {
        return nil;
    }
    LGEnsurePreferenceCacheInitialized();
    NSDictionary *prefs = nil;
    os_unfair_lock_lock(&sLGPrefsLock);
    prefs = sLGCachedPreferences;
    os_unfair_lock_unlock(&sLGPrefsLock);
    return prefs[key];
}

CGFloat LG_prefFloat(NSString *key, CGFloat fallback) {
    id value = LGPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value doubleValue];
    }
    return fallback;
}

NSInteger LG_prefInteger(NSString *key, NSInteger fallback) {
    id value = LGPreferenceValue(key);
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value integerValue];
    }
    return fallback;
}

NSString *LG_prefString(NSString *key, NSString *fallback) {
    id value = LGPreferenceValue(key);
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return value;
    }
    return fallback;
}

BOOL LG_globalEnabled(void) {
    return LG_prefBool(@"Global.Enabled", NO);
}

BOOL LGDebugLoggingEnabled(void) {
    return LG_prefBool(@"Debug.Logging.Enabled", NO);
}

void LGLog(NSString *format, ...) {
    if (!LGDebugLoggingEnabled()) {
        return;
    }
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[LiquidAss] %@", message);
    LGAppendLogLine([NSString stringWithFormat:@"[LiquidAss] %@\n", message]);
}

static void LGAppendLogLine(NSString *line) {
    NSString *path = LGLogFilePath();
    if (path.length == 0 || line.length == 0) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sLGLogQueue = dispatch_queue_create("dylv.liquidass.logfile", DISPATCH_QUEUE_SERIAL);
        atexit(LGCloseLogHandleAtExit);
    });

    dispatch_async(sLGLogQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:path]) {
            NSError *createError = nil;
            [[NSData data] writeToFile:path options:NSDataWritingAtomic error:&createError];
            if (createError) {
                NSLog(@"[LiquidAss] log file create failed %@", createError.localizedDescription ?: @"unknown");
                return;
            }
        }

        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (data.length == 0) {
            return;
        }

        if (!sLGLogHandle) {
            sLGLogHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        if (!sLGLogHandle) {
            NSLog(@"[LiquidAss] log file open failed %@", path);
            return;
        }

        NSError *writeError = nil;
        if (@available(iOS 13.0, *)) {
            [sLGLogHandle seekToEndReturningOffset:NULL error:&writeError];
            if (!writeError) {
                [sLGLogHandle writeData:data error:&writeError];
            }
        } else {
            @try {
                [sLGLogHandle seekToEndOfFile];
                [sLGLogHandle writeData:data];
            } @catch (NSException *exception) {
                writeError = [NSError errorWithDomain:@"dylv.liquidass.logfile"
                                                 code:1
                                             userInfo:@{
                    NSLocalizedDescriptionKey: exception.reason ?: @"NSFileHandle exception"
                }];
            }
        }

        if (writeError) {
            LGCloseLogHandle();
            NSLog(@"[LiquidAss] log file append failed %@", writeError.localizedDescription ?: @"unknown");
        }
    });
}

CGColorSpaceRef LGSharedRGBColorSpace(void) {
    static CGColorSpaceRef sColorSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sColorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return sColorSpace;
}

UIImage *LGNormalizedImageForUpload(UIImage *image) {
    if (!image) {
        return nil;
    }
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

NSNumber *LGTextureScaleKey(CGFloat scale) {
    NSInteger scaled = (NSInteger)llround(scale * 1000.0);
    return @(MAX(scaled, 1));
}

NSNumber *LGBlurSettingKey(CGFloat blur) {
    NSInteger scaled = (NSInteger)llround(fmax(0.0, blur) * 1000.0);
    return @(MAX(scaled, 0));
}

NSString *LGImageStableCacheKey(UIImage *image) {
    if (!image) {
        return nil;
    }
    return objc_getAssociatedObject(image, kLGImageStableCacheKeyAssociation);
}

void LGSetImageStableCacheKey(UIImage *image, NSString *cacheKey) {
    if (!image) {
        return;
    }
    objc_setAssociatedObject(image,
                             kLGImageStableCacheKeyAssociation,
                             [cacheKey copy],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void LGPreferencesChanged(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        LGReloadPreferences();
        [[NSNotificationCenter defaultCenter] postNotificationName:@"dylv.liquidassprefs.InProcessReload"
                                                            object:nil];
    });
}

static NSString *LGLogFilePath(void) {
    static NSString *sPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobilesafari"]) {
            NSString *tempDir = NSTemporaryDirectory();
            sPath = [tempDir stringByAppendingPathComponent:@"liquidglass.log"];
        } else {
            sPath = @"/var/mobile/Library/Accessibility/liquidglass.log";
        }
    });
    return sPath;
}

static void LGCloseLogHandleAtExit(void) {
    if (!sLGLogQueue) {
        LGCloseLogHandle();
        return;
    }
    dispatch_sync(sLGLogQueue, ^{
        LGCloseLogHandle();
    });
}

static void LGCloseLogHandle(void) {
    if (!sLGLogHandle) {
        return;
    }
    if (@available(iOS 13.0, *)) {
        [sLGLogHandle closeAndReturnError:nil];
    } else {
        [sLGLogHandle closeFile];
    }
    sLGLogHandle = nil;
}
