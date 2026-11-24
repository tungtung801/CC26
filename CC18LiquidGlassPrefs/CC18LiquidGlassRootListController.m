#import "CC18LiquidGlassRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/utsname.h>
#import <math.h>

static CFStringRef const kCC18PrefsDomain = CFSTR("com.cc18glass.prefs");
static CFStringRef const kCC18ReloadNotification = CFSTR("com.cc18glass.prefs/reload");

static NSDictionary<NSString *, NSArray<NSNumber *> *> *CC18Schema(void) {
    return @{
        @"enabled":   @[@0,    @1,    @1],
        @"style27":   @[@0,    @1,    @0],
        @"style26":   @[@0,    @1,    @1],
        @"touch":     @[@0,    @1,    @1],
        @"intensity": @[@0.25, @2,    @1],
        @"blur":      @[@0.25, @2,    @0.314],
        @"tint":      @[@0,    @2,    @1.316],
        @"rim":       @[@0,    @2,    @1.265],
        @"depth":     @[@0,    @2,    @0.8],
        @"color":     @[@0,    @2,    @0.8],
        @"bgBlur":    @[@0,    @24,   @20],
        @"bgSat":     @[@0.5,  @2,    @1],
        @"bgDark":    @[@0,    @0.6,  @0.25],
        @"bgTop":     @[@0,    @1,    @0.8],
        @"animation": @[@0,    @1,    @1],
        @"stretch":   @[@0,    @2,    @2],
    };
}

static BOOL CC18IsBoolKey(NSString *key) {
    return [key isEqualToString:@"enabled"]
        || [key isEqualToString:@"touch"]
        || [key isEqualToString:@"animation"]
        || [key isEqualToString:@"style26"]
        || [key isEqualToString:@"style27"];
}

static NSArray<NSString *> *CC18Handled(void) {
    id val = (__bridge_transfer id)CFPreferencesCopyAppValue(CFSTR("handledCrashes"), kCC18PrefsDomain);
    return [val isKindOfClass:[NSArray class]] ? (NSArray<NSString *> *)val : @[];
}

static void CC18MarkHandled(NSString *name) {
    NSMutableArray<NSString *> *list = [CC18Handled() mutableCopy];
    if (name && ![list containsObject:name]) {
        [list addObject:name];
    }
    while (list.count > 200) {
        [list removeObjectAtIndex:0];
    }
    CFPreferencesSetAppValue(CFSTR("handledCrashes"), (__bridge CFPropertyListRef)list, kCC18PrefsDomain);
    CFPreferencesAppSynchronize(kCC18PrefsDomain);
}

@implementation CC18LiquidGlassRootListController {
    BOOL _greeted;
    BOOL _scanned;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        [self cc18UpdateConflictRow];
        [self cc18UpdateStyleRows];
    }
    return _specifiers;
}

- (void)cc18UpdateStyleRows {
    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    id val = (__bridge_transfer id)CFPreferencesCopyAppValue(CFSTR("style27"), kCC18PrefsDomain);
    BOOL style27 = [val isKindOfClass:[NSNumber class]] ? [val boolValue] : NO;
    for (PSSpecifier *spec in _specifiers) {
        if ([[spec identifier] isEqualToString:@"style26"]) {
            [spec setProperty:@(!style27) forKey:@"enabled"];
        }
    }
}

- (void)cc18UpdateConflictRow {
    PSSpecifier *group = nil;
    for (PSSpecifier *spec in _specifiers) {
        if ([[spec identifier] isEqualToString:@"conflicts"]) {
            group = spec;
            break;
        }
    }
    if (!group) {
        return;
    }

    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    id checked = (__bridge_transfer id)CFPreferencesCopyAppValue(CFSTR("conflictsChecked"), kCC18PrefsDomain);
    id raw = (__bridge_transfer id)CFPreferencesCopyAppValue(CFSTR("conflicts"), kCC18PrefsDomain);
    NSArray<NSString *> *list = [raw isKindOfClass:[NSArray class]] ? (NSArray<NSString *> *)raw : @[];

    NSString *title = nil;
    NSString *footer = nil;
    if (list.count > 0) {
        title = @"⚠️ CC18LiquidGlass: something is hooking Control Center";
        footer = [NSString stringWithFormat:@"• %@\n\nThese tweaks change Control Center too and can clash with CC18 Liquid Glass. If something looks wrong, try turning them off.",
                  [list componentsJoinedByString:@"\n• "]];
    } else if (checked) {
        title = @"✅ CC18LiquidGlass";
        footer = @"Nothing else is hooking Control Center.";
    } else {
        title = @"CC18LiquidGlass";
        footer = @"Open Control Center once, then come back here to see if another tweak is hooking it.";
    }

    [group setName:title];
    [group setProperty:footer forKey:@"footerText"];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id defVal = [specifier propertyForKey:@"default"];
    if (!key) {
        return defVal;
    }

    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    id val = (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, kCC18PrefsDomain);
    if (![val isKindOfClass:[NSNumber class]]) {
        return defVal;
    }

    double d = [val doubleValue];
    if (isnan(d) || isinf(d)) {
        return defVal;
    }

    id minVal = [specifier propertyForKey:@"min"];
    id maxVal = [specifier propertyForKey:@"max"];
    if ([minVal isKindOfClass:[NSNumber class]] && [maxVal isKindOfClass:[NSNumber class]]) {
        double lo = [minVal doubleValue];
        double hi = [maxVal doubleValue];
        d = MAX(lo, MIN(hi, d));
        return @(d);
    }

    return val;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key || ![value isKindOfClass:[NSNumber class]]) {
        return;
    }

    double d = [value doubleValue];
    id minVal = [specifier propertyForKey:@"min"];
    id maxVal = [specifier propertyForKey:@"max"];
    if ([minVal isKindOfClass:[NSNumber class]] && [maxVal isKindOfClass:[NSNumber class]]) {
        double lo = [minVal doubleValue];
        double hi = [maxVal doubleValue];
        d = MAX(lo, MIN(hi, d));
        value = @(d);
    }

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, kCC18PrefsDomain);

    BOOL isStyle27 = [key isEqualToString:@"style27"];
    if (isStyle27) {
        CFPreferencesSetAppValue(CFSTR("style26"), [value boolValue] ? kCFBooleanFalse : kCFBooleanTrue, kCC18PrefsDomain);
    }

    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), kCC18ReloadNotification, NULL, NULL, true);

    if (isStyle27) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf reloadKeepingScroll];
        });
    }
}

- (void)resetDefaults {
    NSArray<NSString *> *keys = @[
        @"enabled", @"touch", @"intensity", @"blur", @"tint", @"rim",
        @"depth", @"color", @"bgBlur", @"bgSat", @"bgDark", @"bgTop",
        @"animation", @"stretch", @"style26", @"style27"
    ];
    for (NSString *key in keys) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, kCC18PrefsDomain);
    }
    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), kCC18ReloadNotification, NULL, NULL, true);
    [self reloadKeepingScroll];
}

- (void)reloadKeepingScroll {
    UITableView *table = nil;
    @try {
        table = [self valueForKey:@"table"];
    } @catch (NSException *e) {
        table = nil;
    }

    CGPoint offset = table ? table.contentOffset : CGPointZero;
    [self reloadSpecifiers];
    if (table) {
        [table setContentOffset:offset];
    }
}

- (void)applyPreset:(NSDictionary<NSString *, NSNumber *> *)preset {
    [preset enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj, BOOL *stop) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)obj, kCC18PrefsDomain);
    }];
    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), kCC18ReloadNotification, NULL, NULL, true);
    [self reloadKeepingScroll];
}

- (void)presetDefault {
    [self applyPreset:@{
        @"intensity": @1.0,
        @"blur":      @0.314,
        @"tint":      @1.316,
        @"rim":       @1.265,
        @"depth":     @0.8,
        @"color":     @0.8,
    }];
}

- (void)presetClear {
    [self applyPreset:@{
        @"intensity": @1.0,
        @"blur":      @0.5,
        @"tint":      @0.4,
        @"rim":       @1.2,
        @"depth":     @0.6,
        @"color":     @1.0,
    }];
}

- (void)presetFrosted {
    [self applyPreset:@{
        @"intensity": @1.0,
        @"blur":      @1.6,
        @"tint":      @1.6,
        @"rim":       @0.8,
        @"depth":     @0.8,
        @"color":     @0.8,
    }];
}

- (void)presetBold {
    [self applyPreset:@{
        @"intensity": @1.25,
        @"blur":      @0.8,
        @"tint":      @1.3,
        @"rim":       @1.3,
        @"depth":     @1.0,
        @"color":     @1.2,
    }];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                message:message
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"ok"
                                           style:UIAlertActionStyleDefault
                                         handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)exportSettings {
    NSDictionary<NSString *, NSArray<NSNumber *> *> *schema = CC18Schema();
    NSMutableDictionary<NSString *, NSNumber *> *settings = [NSMutableDictionary dictionary];

    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    for (NSString *key in schema) {
        NSArray<NSNumber *> *bounds = schema[key];
        id raw = (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, kCC18PrefsDomain);
        double v = [bounds[2] doubleValue];
        if ([raw isKindOfClass:[NSNumber class]]) {
            double d = [raw doubleValue];
            if (!isnan(d) && !isinf(d)) {
                v = d;
            }
        }
        v = MAX([bounds[0] doubleValue], MIN([bounds[1] doubleValue], v));
        if (CC18IsBoolKey(key)) {
            double threshold = [key isEqualToString:@"animation"] ? 0.05 : 0.5;
            settings[key] = @(v > threshold);
        } else {
            settings[key] = @(round(v * 1000.0) / 1000.0);
        }
    }

    NSDictionary *payload = @{
        @"format":   @"cc18.json",
        @"version":  @1,
        @"name":     @"CC18 Liquid Glass style",
        @"settings": settings,
    };

    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                     error:&err];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"cc18.json"];
    if (!data || ![data writeToFile:path atomically:YES]) {
        [self showMessage:@"Could not create cc18.json."];
        return;
    }

    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                   applicationActivities:nil];
    vc.popoverPresentationController.sourceView = self.view;
    vc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                             CGRectGetMidY(self.view.bounds),
                                                             1,
                                                             1);
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)importSettings {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text", @"public.data"]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    id obj = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;

    NSDictionary *src = nil;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        id inner = obj[@"settings"];
        src = [inner isKindOfClass:[NSDictionary class]] ? inner : obj;
    }
    if (!src) {
        [self showMessage:@"That file is not a valid cc18.json."];
        return;
    }

    NSDictionary<NSString *, NSArray<NSNumber *> *> *schema = CC18Schema();
    NSUInteger count = 0;

    for (NSString *key in schema) {
        id raw = src[key];
        if (![raw isKindOfClass:[NSNumber class]]) {
            continue;
        }
        double v = [raw doubleValue];
        if (isnan(v) || isinf(v)) {
            continue;
        }
        NSArray<NSNumber *> *bounds = schema[key];
        if (![key isEqualToString:@"animation"]) {
            v = MAX([bounds[0] doubleValue], MIN([bounds[1] doubleValue], v));
        }
        NSNumber *outVal = CC18IsBoolKey(key)
            ? @(v > ([key isEqualToString:@"animation"] ? 0.05 : 0.5))
            : @(v);
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)outVal, kCC18PrefsDomain);
        count++;
    }

    if (count == 0) {
        [self showMessage:@"That file is not a valid cc18.json."];
        return;
    }

    id s27 = src[@"style27"];
    if ([s27 isKindOfClass:[NSNumber class]] && [s27 boolValue]) {
        CFPreferencesSetAppValue(CFSTR("style26"), kCFBooleanFalse, kCC18PrefsDomain);
    }

    CFPreferencesAppSynchronize(kCC18PrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), kCC18ReloadNotification, NULL, NULL, true);
    [self reloadKeepingScroll];
    [self showMessage:[NSString stringWithFormat:@"Imported %lu settings.", (unsigned long)count]];
}

- (void)openURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)openDiscord {
    [self openURLString:@"https://discord.com/users/1545706852267069460"];
}

- (void)openZepew {
    [self openURLString:@"https://discord.com/users/1415931796008206361"];
}

- (void)openFemboy {
    [self openURLString:@"https://discord.com/users/1360235705950801940"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    UITableView *table = nil;
    @try {
        table = [self valueForKey:@"table"];
    } @catch (NSException *e) {
        table = nil;
    }
    if (table) {
        UIEdgeInsets insets = table.contentInset;
        if (insets.bottom < 90.0) {
            insets.bottom = 90.0;
            table.contentInset = insets;
            table.scrollIndicatorInsets = insets;
        }
    }

    if (_greeted) {
        if (!_scanned) {
            _scanned = YES;
            [self scanCrashLogsManual:NO];
        }
        return;
    }

    _greeted = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                    message:@"🐍eko built this shit."
                                                             preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"uhh okay"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
            [weakSelf cc18AfterGreeting];
        }]];
        [ac addAction:[UIAlertAction actionWithTitle:@"idfk"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
            UIAlertController *ac2 = [UIAlertController alertControllerWithTitle:nil
                                                                         message:@"shut up"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [ac2 addAction:[UIAlertAction actionWithTitle:@"ok"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *action2) {
                [weakSelf cc18AfterGreeting];
            }]];
            [weakSelf presentViewController:ac2 animated:YES completion:nil];
        }]];
        [weakSelf presentViewController:ac animated:YES completion:nil];
    });
}

- (void)cc18AfterGreeting {
    if (_scanned) {
        return;
    }
    _scanned = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf scanCrashLogsManual:NO];
    });
}

- (void)checkCrashLogsNow {
    [self scanCrashLogsManual:YES];
}

- (void)scanCrashLogsManual:(BOOL)manual {
    id senseVal = (__bridge_transfer id)CFPreferencesCopyAppValue(CFSTR("crashSense"), kCC18PrefsDomain);
    BOOL enabled = [senseVal isKindOfClass:[NSNumber class]] ? [senseVal boolValue] : YES;
    if (!manual && !enabled) {
        return;
    }

    NSString *dir = @"/var/mobile/Library/Logs/CrashReporter";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    if (!files) {
        if (manual) {
            [self showMessage:@"Settings is not allowed to read the crash log folder on this device."];
        }
        return;
    }

    NSArray<NSString *> *handled = CC18Handled();
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-14.0 * 86400.0];
    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];

    for (NSString *name in files) {
        if ((![name hasSuffix:@".ips"] && ![name hasSuffix:@".crash"]) || [handled containsObject:name]) {
            continue;
        }
        NSString *path = [dir stringByAppendingPathComponent:name];
        NSDate *mtime = [[fm attributesOfItemAtPath:path error:nil] fileModificationDate];
        if (!mtime || [mtime compare:cutoff] == NSOrderedAscending) {
            continue;
        }
        [candidates addObject:@{@"n": name, @"p": path, @"d": mtime}];
    }

    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"d"] compare:a[@"d"]];
    }];

    NSUInteger checked = 0;
    for (NSDictionary *entry in candidates) {
        if (++checked > 40) {
            break;
        }
        NSData *data = [NSData dataWithContentsOfFile:entry[@"p"]
                                              options:NSDataReadingMappedIfSafe
                                                error:nil];
        if (!data || data.length > 0x400000) {
            continue;
        }
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!text) {
            text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
        }
        if ([text containsString:@"CC18LiquidGlass"] || [text containsString:@"CC18Glass"]) {
            [self offerCrashLog:entry];
            return;
        }
    }

    if (manual) {
        [self showMessage:@"No new crash logs that mention CC18 Liquid Glass."];
    }
}

- (void)offerCrashLog:(NSDictionary *)entry {
    NSString *name = entry[@"n"];
    NSString *path = entry[@"p"];
    NSString *msg = [NSString stringWithFormat:@"%@\n\nThis crash log mentions CC18 Liquid Glass.\n\n\"send to seko\" sends the crash log, your iOS version and your device model to Seko on Discord. Nothing else.", name];

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"🐍 seko bot sensed a crash log"
                                                                message:msg
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"ignore"
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action) {
        CC18MarkHandled(name);
    }]];

    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"send to seko"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
        [weakSelf sendCrashLog:path name:name];
    }]];

    [self presentViewController:ac animated:YES completion:nil];
}

- (void)sendCrashLog:(NSString *)path name:(NSString *)name {
    NSString *webhook = @"";
    if (webhook.length == 0) {
        [self showMessage:@"Crash sending is not set up in this build yet (no Discord webhook was added)."];
        return;
    }

    NSData *logData = [NSData dataWithContentsOfFile:path];
    if (logData.length == 0) {
        [self showMessage:@"Could not read that crash log."];
        return;
    }
    if (logData.length > 400000) {
        logData = [logData subdataWithRange:NSMakeRange(0, 400000)];
    }

    struct utsname u;
    uname(&u);
    NSString *content = [NSString stringWithFormat:@"🐍 **CC18 Liquid Glass crash report**\niOS %@ · %@",
                         [UIDevice currentDevice].systemVersion,
                         [NSString stringWithUTF8String:u.machine]];
    NSData *payloadJSON = [NSJSONSerialization dataWithJSONObject:@{
        @"username": @"seko bot",
        @"content":  content,
    } options:0 error:nil];

    NSString *boundary = [@"cc18-" stringByAppendingString:[NSUUID UUID].UUIDString];
    NSMutableData *body = [NSMutableData data];
    void (^appendStr)(NSString *) = ^(NSString *s) {
        [body appendData:[s dataUsingEncoding:NSUTF8StringEncoding]];
    };

    appendStr([NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n", boundary]);
    [body appendData:payloadJSON];
    appendStr([NSString stringWithFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"%@\"\r\nContent-Type: text/plain\r\n\r\n", boundary, name]);
    [body appendData:logData];
    appendStr([NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]);

    NSURL *url = [NSURL URLWithString:webhook];
    if (!url) {
        [self showMessage:@"The Discord webhook address in this build is not valid."];
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary]
        forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = body;

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode
            : 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && status >= 200 && status < 300) {
                CC18MarkHandled(name);
                [weakSelf showMessage:@"sent to seko ✓"];
            } else {
                NSString *reason = error ? @"network error" : [NSString stringWithFormat:@"HTTP %ld", (long)status];
                [weakSelf showMessage:[NSString stringWithFormat:@"Could not send (%@). Check your connection and try again.", reason]];
            }
        });
    }] resume];
}

@end
