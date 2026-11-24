#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>

// ============================================================================
// Private class forward declarations
// ============================================================================

@interface MTMaterialView : UIView
- (void)setWeighting:(double)weighting;
@end

@interface C18ConnectivityView : UIView
- (void)_itemTapped:(id)item;
- (void)_presentListForItem:(id)item;
@end

@interface LGLiveBackdropView : UIView
@end

@interface CCUIModularControlCenterOverlayViewController : UIViewController
@end

@interface FCUIActivityListView : UIView
@end

@interface C18PageScrollView : UIScrollView
@end

// ============================================================================
// Constants, Tags, Associated Object Keys & Global State
// ============================================================================

static const NSInteger kGlassTag = 0x4c471a55;
static const NSInteger kBgTag    = 0x4c471a57;

static const void *kOrigAlphaKey = &kOrigAlphaKey;
static const void *kDupKey       = &kDupKey;
static const void *kOverlapKey   = &kOverlapKey;
static const void *kZeroedKey    = &kZeroedKey;
static const void *kApplySizeKey = &kApplySizeKey;
static const void *kApplyTimeKey = &kApplyTimeKey;
static const void *kBgModeKey    = &kBgModeKey;
static const void *kStyledKey    = &kStyledKey;
static const void *kLayoutKey    = &kLayoutKey;
static const void *kWeightKey    = &kWeightKey;
static const void *kPrevAlphaKey = &kPrevAlphaKey;

static BOOL gEnabled       = YES;
static BOOL gWasEnabled    = YES;
static BOOL g27            = NO;
static BOOL gTouchOn       = YES;
static BOOL gInternal      = NO;
static BOOL gBackdropGlass = NO;

static double gIntensity  = 1.0;
static double gBlurMul    = 0.314;
static double gTintMul    = 1.316;
static double gRimMul     = 1.265;
static double gDepthMul   = 0.8;
static double gColorMul   = 0.8;
static double gStretchMul = 2.0;
static double gAnimMul    = 2.0;

static double gBgBlurPref = 20.0;
static double gBgSatPref  = 1.0;
static double gBgTopPref  = 0.8;
static double gBgDarkPref = 0.25;

static CFTimeInterval gPagerLast = 0;
static NSInteger gPrefsGen       = 0;
static UIView *gTouchGlass       = nil;
static NSMutableString *gTapLog  = nil;

// ============================================================================
// Forward Declarations
// ============================================================================

static void ReduceBlurInLayer(CALayer *l, CGSize scr, int depth);
static void ReduceBlurInAllWindows(void);
static void ClampBigBlurLayers(void);
static void ReconcileGlasses(void);
static void PagerPoll(UIWindow *win);
static void SweepFocusBlur(UIView *win);
static void TouchSafetyNet(void);
static NSHashTable *BigBlurLayers(void);
static NSMapTable *GlassToMat(void);
static NSHashTable *TouchGlasses(void);
static NSHashTable *StyledMats(void);
static NSHashTable *BgMatHolder(void);
static void LoadPrefs(void);
static void RefreshAllGlass(void);
static void ApplyGlass(UIView *mat);
static void SyncGlass(UIView *mat);
static void PlaceGlass(UIView *glass, UIView *mat);
static void PlaceGlassWithDuration(UIView *glass, UIView *mat, CFTimeInterval duration);
static void ApplySliderMask(UIView *slider);
static void ApplyEdgeStyle(CAGradientLayer *rim, CAGradientLayer *dark);
static void LayoutGlassLayers(UIView *glass, CGFloat radius, CFTimeInterval duration);
static void DumpHorizontalModules(void);
static void ScanConflicts(void);

// ============================================================================
// Weak Object Tables
// ============================================================================

static NSHashTable *BigBlurLayers(void) {
    static NSHashTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

static NSMapTable *GlassToMat(void) {
    static NSMapTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSMapTable weakToWeakObjectsMapTable];
    });
    return t;
}

static NSHashTable *TouchGlasses(void) {
    static NSHashTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

static NSHashTable *StyledMats(void) {
    static NSHashTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

static NSHashTable *BgMatHolder(void) {
    static NSHashTable *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

// ============================================================================
// Preferences
// ============================================================================

static double PrefNum(NSString *key, double def, double lo, double hi) {
    CFPreferencesAppSynchronize(CFSTR("com.cc18glass.prefs"));
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.cc18glass.prefs"));
    if (!val) return def;
    double x = def;
    id obj = (__bridge_transfer id)val;
    if ([obj isKindOfClass:[NSNumber class]]) {
        x = [obj doubleValue];
    }
    if (isnan(x) || isinf(x)) x = def;
    return MAX(lo, MIN(hi, x));
}

static void LoadPrefs(void) {
    BOOL master = PrefNum(@"enabled", 1.0, 0.0, 1.0) > 0.5;
    BOOL s27    = PrefNum(@"style27", 0.0, 0.0, 1.0) > 0.5;
    BOOL s26    = PrefNum(@"style26", 1.0, 0.0, 1.0) > 0.5;
    g27         = s27;
    gEnabled    = master && (s26 || s27);
    gTouchOn    = PrefNum(@"touch", 1.0, 0.0, 1.0) > 0.5;
    gIntensity  = PrefNum(@"intensity", 1.0, 0.25, 2.0);
    gBlurMul    = PrefNum(@"blur", 0.314, 0.0, 2.0);
    gTintMul    = PrefNum(@"tint", 1.316, 0.0, 2.0);
    gRimMul     = PrefNum(@"rim", 1.265, 0.0, 2.0);
    gDepthMul   = PrefNum(@"depth", 0.8, 0.0, 2.0);
    gColorMul   = PrefNum(@"color", 0.8, 0.0, 2.0);
    gStretchMul = PrefNum(@"stretch", 2.0, 0.0, 2.0);
    gBgBlurPref = PrefNum(@"bgBlur", 20.0, 0.0, 24.0);
    gBgSatPref  = PrefNum(@"bgSat", 1.0, 0.5, 2.0);
    gBgTopPref  = PrefNum(@"bgTop", 0.8, 0.0, 1.0);
    gBgDarkPref = PrefNum(@"bgDark", 0.25, 0.0, 0.6);
    gAnimMul    = (PrefNum(@"animation", 1.0, 0.0, 2.0) > 0.05) ? 2.0 : 0.0;
}

static void PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger gen = ++gPrefsGen;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (gen != gPrefsGen) return;
            LoadPrefs();
            RefreshAllGlass();
        });
    });
}

// ============================================================================
// CC18BlurKeeper
// ============================================================================

@interface CC18BlurKeeper : NSObject {
    CADisplayLink *_link;
    UIWindow *_win;
    NSInteger _n;
}
+ (instancetype)shared;
- (void)startForWindow:(UIWindow *)win;
- (void)tick;
- (void)stop;
@end

@implementation CC18BlurKeeper

+ (instancetype)shared {
    static CC18BlurKeeper *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [CC18BlurKeeper new];
    });
    return s;
}

- (void)startForWindow:(UIWindow *)win {
    _win = win;
    if (_link) return;
    _n = 0;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)tick {
    if (_n < 70 && (_n % 20) == 0 && _win) {
        ReduceBlurInLayer(_win.layer, [UIScreen mainScreen].bounds.size, 0);
        ReduceBlurInAllWindows();
    }
    ClampBigBlurLayers();
    ReconcileGlasses();
    PagerPoll(_win);
    if ((_n % 6) == 0 && _win) {
        SweepFocusBlur(_win);
    }
    if ((_n % 6) == 3) {
        TouchSafetyNet();
    }
    _n++;
}

- (void)stop {
    [_link invalidate];
    _link = nil;
    _win = nil;
    [BigBlurLayers() removeAllObjects];
}

@end

// ============================================================================
// Blur Reduction & Focus Blur Helpers
// ============================================================================

static BOOL NameHas(NSString *s, NSString *sub) {
    return [s rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL LayerBelongsToUs(CALayer *l) {
    id d = l.delegate;
    if ([d isKindOfClass:[UIView class]]) {
        NSInteger t = [(UIView *)d tag];
        return t == kGlassTag || t == kBgTag;
    }
    return NO;
}

static BOOL IsFullScreenLayer(CALayer *l, CGSize scr) {
    return l.bounds.size.width >= scr.width - 2.0 && l.bounds.size.height >= scr.height - 2.0;
}

static BOOL LayerInsideModule(CALayer *l) {
    for (CALayer *p = l; p; p = p.superlayer) {
        id d = p.delegate;
        if ([d isKindOfClass:[UIView class]]) {
            NSString *cls = NSStringFromClass([d class]);
            if ([cls hasPrefix:@"C18"] || [cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"]) {
                return YES;
            }
        }
    }
    return NO;
}

static void ReduceBlurInLayer(CALayer *l, CGSize scr, int depth) {
    if (depth > 16 || LayerBelongsToUs(l)) return;
    if (l.filters.count && IsFullScreenLayer(l, scr) && !LayerInsideModule(l)) {
        static NSMutableSet *logged;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            logged = [NSMutableSet set];
        });
        NSArray *filters = l.filters;
        BOOL changed = NO;
        for (id f in filters) {
            @try {
                NSString *type = [f valueForKey:@"type"];
                if ([type isEqualToString:@"colorBrightness"]) {
                    NSNumber *amt = [f valueForKey:@"inputAmount"];
                    if (amt && [amt doubleValue] < -0.001) {
                        [f setValue:@0.0 forKey:@"inputAmount"];
                        [BigBlurLayers() addObject:l];
                        changed = YES;
                    }
                } else if ([type isEqualToString:@"gaussianBlur"]) {
                    NSNumber *rad = [f valueForKey:@"inputRadius"];
                    if (rad) {
                        double r = [rad doubleValue];
                        NSString *key = [NSString stringWithFormat:@"%@|%@|%.0f",
                                         NSStringFromClass([l class]),
                                         l.delegate ? NSStringFromClass([l.delegate class]) : @"-",
                                         r];
                        if (![logged containsObject:key]) {
                            [logged addObject:key];
                            NSLog(@"[CC18Glass] found bg blur: %@ (r=%.0f -> %.0f)", key, r, gBgBlurPref);
                        }
                        [BigBlurLayers() addObject:l];
                        if (r > gBgBlurPref + 1.0) {
                            [f setValue:@(gBgBlurPref) forKey:@"inputRadius"];
                            changed = YES;
                        }
                    }
                }
            } @catch (NSException *e) {
            }
        }
        if (changed) {
            l.filters = filters;
        }
    }
    for (CALayer *sub in l.sublayers) {
        ReduceBlurInLayer(sub, scr, depth + 1);
    }
}

static void ReduceBlurInAllWindows(void) {
    CGSize scr = [UIScreen mainScreen].bounds.size;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        ReduceBlurInLayer(w.layer, scr, 0);
    }
}

static void ClampBigBlurLayers(void) {
    CGSize scr = [UIScreen mainScreen].bounds.size;
    for (CALayer *l in [BigBlurLayers() allObjects]) {
        if (!IsFullScreenLayer(l, scr) || LayerInsideModule(l)) {
            [BigBlurLayers() removeObject:l];
            continue;
        }
        NSArray *filters = l.filters;
        BOOL changed = NO;
        for (id f in filters) {
            @try {
                NSString *type = [f valueForKey:@"type"];
                if ([type isEqualToString:@"colorBrightness"]) {
                    NSNumber *amt = [f valueForKey:@"inputAmount"];
                    if (amt && [amt doubleValue] < -0.001) {
                        [f setValue:@0.0 forKey:@"inputAmount"];
                        changed = YES;
                    }
                } else if ([type isEqualToString:@"gaussianBlur"]) {
                    NSNumber *rad = [f valueForKey:@"inputRadius"];
                    if (rad && [rad doubleValue] > gBgBlurPref + 0.5) {
                        [f setValue:@(gBgBlurPref) forKey:@"inputRadius"];
                        changed = YES;
                    }
                }
            } @catch (NSException *e) {
            }
        }
        if (changed) {
            l.filters = filters;
        }
        for (NSString *key in [l.animationKeys copy]) {
            if (NameHas(key, @"inputRadius") || NameHas(key, @"gaussianBlur")) {
                [l removeAnimationForKey:key];
            }
        }
    }
}

static BOOL HasAnimDeep(CALayer *l, int depth) {
    if (l.animationKeys.count) return YES;
    if (depth >= 2) return NO;
    for (CALayer *s in l.sublayers) {
        if (HasAnimDeep(s, depth + 1)) return YES;
    }
    return NO;
}

static void ApplyMarqueeFade(UIView *v) {
    CGFloat w = CGRectGetWidth(v.bounds);
    CGFloat h = CGRectGetHeight(v.bounds);
    if (w < 40.0 || h < 8.0 || w > 500.0 || v.maskView != nil) return;
    if (v.layer.mask && ![v.layer.mask.name isEqualToString:@"cc18fade"]) return;

    CGFloat maxW = 0.0;
    for (UIView *sub in v.subviews) {
        CGFloat sw = CGRectGetWidth(sub.frame);
        if (sw > maxW) maxW = sw;
    }
    BOOL overflows = maxW > w + 1.0;

    static int logged = 0;
    if (logged < 8) {
        logged++;
        NSLog(@"[CC18Glass] marquee %@ w=%.0f content=%.0f overflow=%d",
              NSStringFromClass([v class]), w, maxW, overflows);
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!overflows) {
        if (v.layer.mask) {
            v.layer.mask = nil;
        }
    } else {
        CAGradientLayer *g = [v.layer.mask isKindOfClass:[CAGradientLayer class]] ? (CAGradientLayer *)v.layer.mask : nil;
        if (!g) {
            g = [CAGradientLayer layer];
            g.name = @"cc18fade";
            g.startPoint = CGPointMake(0.0, 0.5);
            g.endPoint   = CGPointMake(1.0, 0.5);
            v.layer.mask = g;
        }
        g.frame = v.bounds;
        BOOL anim = HasAnimDeep(v.layer, 0);
        CGFloat left  = anim ? MIN(10.0, w * 0.2) / w : 0.0;
        CGFloat right = MIN(16.0, w * 0.25) / w;
        g.colors = @[
            (id)(anim ? [UIColor clearColor] : [UIColor blackColor]).CGColor,
            (id)[UIColor blackColor].CGColor,
            (id)[UIColor blackColor].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        g.locations = @[@0.0, @(left), @(1.0 - right), @1.0];
    }
    [CATransaction commit];
}

static void SweepFocusBlurIn(UIView *v, BOOL inFocus, int depth) {
    if (depth > 24) return;
    for (UIView *sub in v.subviews) {
        if (sub.tag == kGlassTag || sub.tag == kBgTag) continue;
        NSString *cls = NSStringFromClass([sub class]);
        if (NameHas(cls, @"Marquee")) {
            ApplyMarqueeFade(sub);
            continue;
        }
        if ([cls isEqualToString:@"MTMaterialView"]) continue;
        BOOL nf = inFocus || [cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"];
        if (nf &&
            ([sub isKindOfClass:[UIVisualEffectView class]] || NameHas(cls, @"Backdrop") || NameHas(cls, @"BlurView")) &&
            CGRectGetHeight(sub.bounds) > 160.0) {
            if (!sub.hidden || sub.alpha > 0.0) {
                sub.alpha = 0.0;
                sub.hidden = YES;
            }
            continue;
        }
        if (sub.subviews.count) {
            SweepFocusBlurIn(sub, nf, depth + 1);
        }
    }
}

static void SweepFocusBlur(UIView *win) {
    if (win) {
        SweepFocusBlurIn(win, NO, 0);
    }
}

static void StripFocusBlur(UIView *v) {
    for (UIView *sub in v.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if (([sub isKindOfClass:[UIVisualEffectView class]] || NameHas(cls, @"Backdrop") || NameHas(cls, @"BlurView")) &&
            sub.tag != kGlassTag && sub.tag != kBgTag &&
            CGRectGetHeight(sub.bounds) > 160.0) {
            if (sub.alpha > 0.0) {
                sub.alpha = 0.0;
            }
            continue;
        }
        if (sub.subviews.count && ![cls isEqualToString:@"MTMaterialView"]) {
            StripFocusBlur(sub);
        }
    }
}

static BOOL IsFocusListBackdrop(UIView *v) {
    if (CGRectGetHeight(v.bounds) <= 160.0) return NO;
    UIView *p = v.superview;
    for (int i = 0; p && i < 6; i++, p = p.superview) {
        if ([NSStringFromClass([p class]) hasPrefix:@"FCUIActivityList"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL IsFocusOrPageLayer(CALayer *l) {
    id d = l.delegate;
    if (![d isKindOfClass:[UIView class]]) return NO;
    NSString *cls = NSStringFromClass([d class]);
    return [cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"] || [cls hasPrefix:@"C18Page"] || [cls isEqualToString:@"CCUIScrollView"];
}

// ============================================================================
// Geometry & Classification Helpers
// ============================================================================

static CGRect WindowRect(UIView *v) {
    return [v.superview convertRect:v.frame toView:nil];
}

static BOOL RectHugs(CGRect a, CGRect b) {
    return a.origin.x <= b.origin.x + 4.0 &&
           a.origin.y <= b.origin.y + 4.0 &&
           CGRectGetMaxX(a) >= CGRectGetMaxX(b) - 4.0 &&
           CGRectGetMaxY(a) >= CGRectGetMaxY(b) - 4.0 &&
           a.size.width <= b.size.width + 24.0 &&
           a.size.height <= b.size.height + 24.0;
}

static BOOL RectTwins(CGRect a, CGRect b) {
    if (a.size.width <= 24.0 || a.size.height <= 24.0) return NO;
    if (b.size.width <= 24.0 || b.size.height <= 24.0) return NO;
    CGRect inter = CGRectIntersection(a, b);
    if (CGRectIsNull(inter)) return NO;
    CGFloat areaA = a.size.width * a.size.height;
    CGFloat areaB = b.size.width * b.size.height;
    CGFloat minArea = MIN(areaA, areaB);
    if (minArea <= 1.0) return NO;
    CGFloat interArea = inter.size.width * inter.size.height;
    return interArea >= 0.85 * minArea;
}

static BOOL NearRelatives(UIView *a, UIView *b) {
    UIView *p = a.superview;
    for (int i = 0; p && i < 4; i++, p = p.superview) {
        if ([b isDescendantOfView:p]) return YES;
    }
    return NO;
}

static BOOL InCCWindow(UIView *v) {
    UIWindow *w = v.window;
    if (!w) return NO;
    static __weak UIWindow *lastW = nil;
    static BOOL lastR = NO;
    if (w == lastW) return lastR;
    lastW = w;
    lastR = [NSStringFromClass([w class]) hasPrefix:@"SBControlCenter"];
    return lastR;
}

static UIView *SliderAncestor(UIView *v) {
    UIView *p = v.superview;
    for (int i = 0; p && i < 5; i++, p = p.superview) {
        if (NameHas(NSStringFromClass([p class]), @"Slider")) {
            return p;
        }
    }
    return nil;
}

static UIView *FirstMaterialIn(UIView *v, int depth) {
    if (depth > 8) return nil;
    for (UIView *sub in v.subviews) {
        if (sub.tag == kGlassTag) continue;
        if ([NSStringFromClass([sub class]) isEqualToString:@"MTMaterialView"]) {
            return sub;
        }
        UIView *found = FirstMaterialIn(sub, depth + 1);
        if (found) return found;
    }
    return nil;
}

static BOOL IsSliderFill(UIView *mat, UIView *slider) {
    if (FirstMaterialIn(slider, 0) == mat) return NO;
    UIView *p = mat.superview;
    while (p && p != slider) {
        if ([NSStringFromClass([p class]) isEqualToString:@"UIView"] &&
            p.layer.masksToBounds &&
            (CGRectGetHeight(p.bounds) < CGRectGetHeight(slider.bounds) - 3.0 ||
             CGRectGetWidth(p.bounds) < CGRectGetWidth(slider.bounds) - 3.0)) {
            return YES;
        }
        p = p.superview;
    }
    return NO;
}

static BOOL IsContainerOnly(NSString *cls) {
    static NSSet *skip;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        skip = [NSSet setWithObjects:
                @"C18PassThroughView",
                @"C18PageView",
                @"C18PageScrollView",
                @"C18ScaledHostView",
                @"CCUIScrollView",
                @"FCUIActivityListView",
                @"FCUIActivityListContentView",
                nil];
    });
    return [skip containsObject:cls];
}

static BOOL IsCCClassName(NSString *cls) {
    return [cls hasPrefix:@"C18"] || [cls hasPrefix:@"CCUI"] || [cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"];
}

static BOOL IsFullScreenMatInCC(UIView *mat) {
    CGSize sz = mat.bounds.size;
    CGSize scr = [UIScreen mainScreen].bounds.size;
    CGFloat minSide = MIN(scr.width, scr.height);
    if (sz.width < minSide - 1.0 || sz.height < 300.0) return NO;
    return [NSStringFromClass([mat.window class]) hasPrefix:@"SBControlCenter"];
}

static BOOL IsControlCenterBackground(UIView *mat) {
    if (!IsFullScreenMatInCC(mat)) return NO;
    UIView *p = mat.superview;
    for (int i = 0; p && i < 8; i++, p = p.superview) {
        NSString *cls = NSStringFromClass([p class]);
        if ([cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"] || [cls hasPrefix:@"C18"]) {
            return NO;
        }
    }
    return YES;
}

static BOOL ShouldStyle(UIView *mat, const char **reason) {
    if (!mat) return NO;
    if (!InCCWindow(mat)) {
        if (reason) *reason = "not-control-center-window";
        return NO;
    }
    CGFloat w = CGRectGetWidth(mat.bounds);
    CGSize scr = [UIScreen mainScreen].bounds.size;
    if (w >= scr.width - 1.0) {
        if (reason) *reason = "fullscreen";
        return NO;
    }
    UIView *p = mat.superview;
    for (int i = 0; p && i < 5; i++, p = p.superview) {
        NSString *cls = NSStringFromClass([p class]);
        if (NameHas(cls, @"Artwork") || NameHas(cls, @"Thumbnail")) {
            if (reason) *reason = "artwork";
            return NO;
        }
    }
    UIView *slider = SliderAncestor(mat);
    if (slider) {
        if (IsSliderFill(mat, slider)) {
            if (reason) *reason = "slider-fill";
            return NO;
        }
        if (CGRectGetWidth(mat.bounds) < 30.0 || CGRectGetHeight(mat.bounds) < 30.0) {
            if (reason) *reason = "slider-small";
            return NO;
        }
        return YES;
    }
    p = mat.superview;
    for (int i = 0; p && i < 8; i++, p = p.superview) {
        NSString *cls = NSStringFromClass([p class]);
        if (IsContainerOnly(cls)) {
            if (reason) *reason = "container-only";
            return NO;
        }
        if (IsCCClassName(cls)) {
            return YES;
        }
    }
    if (reason) *reason = "no-cc-ancestor";
    return NO;
}

static BOOL ModuleShown(UIView *mat) {
    if (!mat.window || mat.hidden) return NO;
    CGFloat a = mat.alpha;
    NSNumber *orig = objc_getAssociatedObject(mat, kOrigAlphaKey);
    if (orig && objc_getAssociatedObject(mat, kZeroedKey)) {
        a = [orig doubleValue];
    }
    return a > 0.05;
}

static BOOL FocusOversized(UIView *mat) {
    BOOL inFocus = NO;
    UIView *p = mat.superview;
    for (int i = 0; p && i < 8; i++, p = p.superview) {
        NSString *cls = NSStringFromClass([p class]);
        if ([cls hasPrefix:@"FCUI"] || [cls hasPrefix:@"_FCUI"]) {
            inFocus = YES;
            break;
        }
    }
    if (!inFocus) return NO;
    CGRect r = [mat.superview convertRect:mat.frame toView:nil];
    return CGRectGetHeight(r) > 110.0;
}

static BOOL HasContentSubviews(UIView *v) {
    for (UIView *sub in v.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if (![cls hasPrefix:@"MT"] && ![cls hasPrefix:@"_UIBackdrop"] && ![cls hasPrefix:@"_UIVisualEffect"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL HasOurGlassNextToIt(UIView *v) {
    UIView *sup = v.superview;
    if (!sup) return NO;
    return [sup viewWithTag:kGlassTag] != nil;
}

// ============================================================================
// Glass Layer Construction, Styling & Layout
// ============================================================================

static CGFloat HiddenAlpha(UIView *mat) {
    return objc_getAssociatedObject(mat, kBgModeKey) ? 0.011 : 0.0;
}

static CGFloat GlassOnAlpha(void) {
    return gBackdropGlass ? 1.0 : 0.55;
}

static void MarkStyled(UIView *mat) {
    objc_setAssociatedObject(mat, kStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [StyledMats() addObject:mat];
}

static void NeutralizeMaterial(UIView *mat) {
    if (HasContentSubviews(mat)) {
        SEL sel = NSSelectorFromString(@"setWeighting:");
        if ([mat respondsToSelector:sel]) {
            ((void (*)(id, SEL, double))objc_msgSend)(mat, sel, 0.0);
        }
        return;
    }
    if (!objc_getAssociatedObject(mat, kZeroedKey)) {
        objc_setAssociatedObject(mat, kZeroedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(mat, kOrigAlphaKey, @(mat.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    gInternal = YES;
    mat.alpha = HiddenAlpha(mat);
    gInternal = NO;
}

static NSArray *MakeBackdropFilters(void) {
    Class CAFilter = NSClassFromString(@"CAFilter");
    SEL sel = NSSelectorFromString(@"filterWithType:");
    if (!CAFilter || ![CAFilter respondsToSelector:sel]) return nil;
    @try {
        id blur = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"gaussianBlur");
        [blur setValue:@(12.0 * gBlurMul) forKey:@"inputRadius"];
        [blur setValue:@YES forKey:@"inputNormalizeEdges"];

        id sat = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorSaturate");
        double satVal = g27 ? (0.85 + 0.1 * gColorMul) : (1.0 + 0.5 * gIntensity * gColorMul);
        [sat setValue:@(satVal) forKey:@"inputAmount"];

        id bright = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorBrightness");
        [bright setValue:@(g27 ? -0.05 : 0.0) forKey:@"inputAmount"];

        return @[blur, sat, bright];
    } @catch (NSException *e) {
        return nil;
    }
}

static CALayer *MakeBackdropLayer(void) {
    Class CABackdropLayer = NSClassFromString(@"CABackdropLayer");
    Class CAFilter = NSClassFromString(@"CAFilter");
    if (!CABackdropLayer || !CAFilter) return nil;
    SEL sel = NSSelectorFromString(@"filterWithType:");
    if (![CAFilter respondsToSelector:sel]) return nil;
    @try {
        id blur = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"gaussianBlur");
        [blur setValue:@(12.0 * gBlurMul) forKey:@"inputRadius"];
        [blur setValue:@YES forKey:@"inputNormalizeEdges"];

        id sat = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorSaturate");
        double satVal = g27 ? (0.85 + 0.1 * gColorMul) : (1.0 + 0.5 * gIntensity * gColorMul);
        [sat setValue:@(satVal) forKey:@"inputAmount"];

        id bright = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorBrightness");
        [bright setValue:@(g27 ? -0.05 : 0.0) forKey:@"inputAmount"];

        CALayer *bd = [[CABackdropLayer alloc] init];
        bd.name = @"backdrop";
        [bd setValue:@YES forKey:@"enabled"];
        [bd setValue:@0.5 forKey:@"scale"];
        bd.filters = @[blur, sat, bright];
        return bd;
    } @catch (NSException *e) {
        return nil;
    }
}

static void ApplyEdgeStyle(CAGradientLayer *rim, CAGradientLayer *dark) {
    UIColor *(^W)(CGFloat) = ^UIColor *(CGFloat a) {
        return [UIColor colorWithWhite:1.0 alpha:a];
    };
    UIColor *(^B)(CGFloat) = ^UIColor *(CGFloat a) {
        return [UIColor colorWithWhite:0.0 alpha:a];
    };

    if (g27) {
        rim.startPoint = CGPointMake(0.0, 0.0);
        rim.endPoint   = CGPointMake(1.0, 1.0);
        rim.colors = @[
            (id)W(MIN(1.0, (g27 ? 0.8 : 0.85) * gIntensity * gRimMul)).CGColor,
            (id)W(0.0).CGColor,
            (id)W(0.0).CGColor,
            (id)W(MIN(0.9, (g27 ? 0.35 : 0.72) * gIntensity * gRimMul)).CGColor
        ];
        rim.locations = @[@0, @0.38, @0.72, @1];

        dark.startPoint = CGPointMake(0.0, 0.0);
        dark.endPoint   = CGPointMake(1.0, 1.0);
        dark.colors = @[
            (id)B(0.0).CGColor,
            (id)B(0.0).CGColor,
            (id)B(MIN(0.5, (g27 ? 0.4 : 0.34) * gIntensity * gDepthMul)).CGColor
        ];
        dark.locations = @[@0, @0.45, @1];
    } else {
        rim.startPoint = CGPointMake(0.5, 0.0);
        rim.endPoint   = CGPointMake(0.5, 1.0);
        rim.colors = @[
            (id)W(MIN(1.0, (g27 ? 0.8 : 0.85) * gIntensity * gRimMul)).CGColor,
            (id)W(0.0).CGColor,
            (id)W(0.0).CGColor,
            (id)W(MIN(0.9, (g27 ? 0.35 : 0.72) * gIntensity * gRimMul)).CGColor
        ];
        rim.locations = @[@0, @0.2, @0.8, @1];

        dark.startPoint = CGPointMake(0.0, 0.5);
        dark.endPoint   = CGPointMake(1.0, 0.5);
        dark.colors = @[
            (id)B(MIN(0.5, (g27 ? 0.4 : 0.34) * gIntensity * gDepthMul)).CGColor,
            (id)B(MIN(0.25, (g27 ? 0.0 : 0.14) * gIntensity * gDepthMul)).CGColor,
            (id)B(MIN(0.25, (g27 ? 0.0 : 0.14) * gIntensity * gDepthMul)).CGColor,
            (id)B(MIN(0.5, (g27 ? 0.4 : 0.34) * gIntensity * gDepthMul)).CGColor
        ];
        dark.locations = @[@0, @0.2, @0.8, @1];
    }

    if ([rim.mask isKindOfClass:[CAShapeLayer class]]) {
        ((CAShapeLayer *)rim.mask).lineWidth = g27 ? 1.3 : 0.6;
    }
    if ([dark.mask isKindOfClass:[CAShapeLayer class]]) {
        ((CAShapeLayer *)dark.mask).lineWidth = g27 ? 1.2 : 0.8;
    }
}

static void AddGlassLayers(UIView *v) {
    CALayer *root = v.layer;

    CALayer *tint = [CALayer layer];
    tint.name = @"tint";
    tint.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(g27 ? 0.17 : 0.11) * gIntensity * gTintMul].CGColor;
    [root addSublayer:tint];

    CAGradientLayer *shade = [CAGradientLayer layer];
    shade.name = @"shade";
    shade.startPoint = CGPointMake(0.5, 0.0);
    shade.endPoint   = CGPointMake(0.5, 1.0);
    shade.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.2, (g27 ? 0.05 : 0.1) * gIntensity * gDepthMul)].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    [root addSublayer:shade];

    CAGradientLayer *spec = [CAGradientLayer layer];
    spec.name = @"spec";
    spec.type = kCAGradientLayerRadial;
    spec.startPoint = CGPointMake(0.3, 0.16);
    spec.endPoint   = CGPointMake(0.85, 0.75);
    spec.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    [root addSublayer:spec];

    CAGradientLayer *sheen = [CAGradientLayer layer];
    sheen.name = @"sheen";
    sheen.startPoint = CGPointMake(0.5, 0.0);
    sheen.endPoint   = CGPointMake(0.5, 0.45);
    sheen.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:(g27 ? 0.04 : 0.12) * gIntensity * gTintMul].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    [root addSublayer:sheen];

    CAShapeLayer *glow = [CAShapeLayer layer];
    glow.name = @"glow";
    glow.fillColor = nil;
    glow.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.06, 0.025 * gIntensity * gRimMul)].CGColor;
    glow.lineWidth = 2.5;
    [root addSublayer:glow];

    CAGradientLayer *touchglow = [CAGradientLayer layer];
    touchglow.name = @"touchglow";
    touchglow.type = kCAGradientLayerRadial;
    touchglow.bounds = CGRectMake(0.0, 0.0, 180.0, 180.0);
    touchglow.startPoint = CGPointMake(0.5, 0.5);
    touchglow.endPoint   = CGPointMake(1.0, 1.0);
    touchglow.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.2 * gIntensity].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    touchglow.opacity = 0.0f;
    [root addSublayer:touchglow];

    CAGradientLayer *dark = [CAGradientLayer layer];
    dark.name = @"dark";
    dark.startPoint = CGPointMake(0.0, 0.5);
    dark.endPoint   = CGPointMake(1.0, 0.5);
    dark.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.5, (g27 ? 0.4 : 0.34) * gIntensity * gDepthMul)].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.25, (g27 ? 0.0 : 0.14) * gIntensity * gDepthMul)].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.25, (g27 ? 0.0 : 0.14) * gIntensity * gDepthMul)].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.5, (g27 ? 0.4 : 0.34) * gIntensity * gDepthMul)].CGColor
    ];
    dark.locations = @[@0, @0.2, @0.8, @1];
    CAShapeLayer *darkMask = [CAShapeLayer layer];
    darkMask.fillColor = nil;
    darkMask.strokeColor = [UIColor blackColor].CGColor;
    darkMask.lineWidth = g27 ? 1.2 : 0.8;
    dark.mask = darkMask;
    [root addSublayer:dark];

    CAGradientLayer *rim = [CAGradientLayer layer];
    rim.name = @"rim";
    rim.startPoint = CGPointMake(0.5, 0.0);
    rim.endPoint   = CGPointMake(0.5, 1.0);
    rim.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:MIN(1.0, (g27 ? 0.8 : 0.85) * gIntensity * gRimMul)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:MIN(0.9, (g27 ? 0.35 : 0.72) * gIntensity * gRimMul)].CGColor
    ];
    rim.locations = @[@0, @0.2, @0.8, @1];
    CAShapeLayer *rimMask = [CAShapeLayer layer];
    rimMask.fillColor = nil;
    rimMask.strokeColor = [UIColor blackColor].CGColor;
    rimMask.lineWidth = g27 ? 1.3 : 0.6;
    rim.mask = rimMask;
    [root addSublayer:rim];

    ApplyEdgeStyle(rim, dark);
}

static UIView *MakeGlass(CGRect frame) {
    UIView *v = nil;
    CALayer *bd = MakeBackdropLayer();
    if (bd) {
        gBackdropGlass = YES;
        v = [[UIView alloc] initWithFrame:frame];
        v.backgroundColor = [UIColor clearColor];
        [v.layer insertSublayer:bd atIndex:0];
    } else {
        gBackdropGlass = NO;
        v = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
        v.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        v.alpha = 0.55;
        v.frame = frame;
    }
    v.tag = kGlassTag;
    v.userInteractionEnabled = NO;
    v.clipsToBounds = YES;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    AddGlassLayers(v);
    return v;
}

static CGFloat RadiusFor(UIView *v) {
    if (SliderAncestor(v)) {
        return MIN(CGRectGetWidth(v.bounds), CGRectGetHeight(v.bounds)) * 0.5;
    }
    CGFloat w = CGRectGetWidth(v.bounds);
    CGFloat h = CGRectGetHeight(v.bounds);
    CGFloat r = v.layer.cornerRadius;
    if (r <= 0.0) {
        r = v.superview.layer.cornerRadius;
    }
    if (r > 0.0) return r;
    if (fabs(w - h) < 1.0 || h < 80.0) {
        return MIN(w, h) / 2.0;
    }
    return MIN(40.0, MIN(w, h) / 2.0);
}

static void SetRadiusAnimated(CALayer *l, CGFloat r, CFTimeInterval duration) {
    CGFloat from = l.presentationLayer ? l.presentationLayer.cornerRadius : l.cornerRadius;
    l.cornerRadius = r;
    if (duration > 0.0 && fabs(from - r) > 0.5) {
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
        anim.fromValue = @(from);
        anim.toValue   = @(r);
        anim.duration  = duration;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [l addAnimation:anim forKey:@"cc18radius"];
    }
}

static void LayoutGlassLayers(UIView *glass, CGFloat radius, CFTimeInterval duration) {
    CGRect b = glass.bounds;
    NSValue *prev = objc_getAssociatedObject(glass, kLayoutKey);
    if (prev) {
        CGRect pr = [prev CGRectValue];
        if (CGSizeEqualToSize(pr.size, b.size) && fabs(pr.origin.x - radius) < 0.01) {
            return;
        }
    }
    objc_setAssociatedObject(glass, kLayoutKey, [NSValue valueWithCGRect:CGRectMake(radius, 0.0, b.size.width, b.size.height)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [CATransaction begin];
    if (duration > 0.0) {
        [CATransaction setAnimationDuration:duration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    } else {
        [CATransaction setDisableActions:YES];
    }

    for (CALayer *l in glass.layer.sublayers) {
        NSString *name = l.name;
        if (!name) continue;
        if ([name isEqualToString:@"tint"] ||
            [name isEqualToString:@"sheen"] ||
            [name isEqualToString:@"backdrop"] ||
            [name isEqualToString:@"shade"] ||
            [name isEqualToString:@"spec"]) {
            l.frame = b;
        } else if ([name isEqualToString:@"glow"]) {
            l.frame = b;
            CGRect inset = CGRectInset(b, 1.25, 1.25);
            ((CAShapeLayer *)l).path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0.0, radius - 1.25)].CGPath;
        } else if ([name isEqualToString:@"rimcolor"]) {
            l.frame = b;
            CAShapeLayer *m = (CAShapeLayer *)l.mask;
            m.frame = b;
            CGFloat d = (g27 ? 1.2 : 0.8) + 0.2 + 1.2;
            CGRect inset = CGRectInset(b, d, d);
            m.path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0.0, radius - d)].CGPath;
        } else if ([name isEqualToString:@"dark"]) {
            l.frame = b;
            CAShapeLayer *m = (CAShapeLayer *)l.mask;
            m.frame = b;
            CGFloat d = (g27 ? 1.2 : 0.8) / 2.0;
            CGRect inset = CGRectInset(b, d, d);
            m.path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0.0, radius - d)].CGPath;
        } else if ([name isEqualToString:@"rim"]) {
            l.frame = b;
            CAShapeLayer *m = (CAShapeLayer *)l.mask;
            m.frame = b;
            CGFloat d = (g27 ? 1.2 : 0.8) + (g27 ? 1.3 : 0.6) / 2.0;
            CGRect inset = CGRectInset(b, d, d);
            m.path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0.0, radius - d)].CGPath;
        }
    }

    [CATransaction commit];
}

static void PlaceGlassWithDuration(UIView *glass, UIView *mat, CFTimeInterval duration) {
    glass.bounds = mat.bounds;
    glass.center = mat.center;
    glass.transform = mat.transform;
    CGFloat r = RadiusFor(mat);
    SetRadiusAnimated(glass.layer, r, duration);
    LayoutGlassLayers(glass, r, duration);
}

static void PlaceGlass(UIView *glass, UIView *mat) {
    [UIView performWithoutAnimation:^{
        PlaceGlassWithDuration(glass, mat, 0.0);
    }];
}

static void RestyleGlass(UIView *glass) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CAGradientLayer *dark = nil;
    CAGradientLayer *rim  = nil;

    for (CALayer *l in glass.layer.sublayers) {
        NSString *name = l.name;
        if (!name) continue;
        if ([name isEqualToString:@"backdrop"]) {
            NSArray *filters = MakeBackdropFilters();
            if (filters) l.filters = filters;
        } else if ([name isEqualToString:@"tint"]) {
            l.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(g27 ? 0.17 : 0.11) * gIntensity * gTintMul].CGColor;
        } else if ([name isEqualToString:@"shade"]) {
            ((CAGradientLayer *)l).colors = @[
                (id)[UIColor colorWithWhite:0.0 alpha:MIN(0.2, (g27 ? 0.05 : 0.1) * gIntensity * gDepthMul)].CGColor,
                (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
            ];
        } else if ([name isEqualToString:@"sheen"]) {
            ((CAGradientLayer *)l).colors = @[
                (id)[UIColor colorWithWhite:1.0 alpha:(g27 ? 0.04 : 0.12) * gIntensity * gTintMul].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
            ];
        } else if ([name isEqualToString:@"glow"]) {
            ((CAShapeLayer *)l).strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.06, 0.025 * gIntensity * gRimMul)].CGColor;
        } else if ([name isEqualToString:@"touchglow"]) {
            ((CAGradientLayer *)l).colors = @[
                (id)[UIColor colorWithWhite:1.0 alpha:0.2 * gIntensity].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
            ];
        } else if ([name isEqualToString:@"dark"]) {
            dark = (CAGradientLayer *)l;
        } else if ([name isEqualToString:@"rim"]) {
            rim = (CAGradientLayer *)l;
        }
    }

    if (rim && dark) {
        ApplyEdgeStyle(rim, dark);
    }
    [CATransaction commit];
}

// ============================================================================
// Background Replacement & Slider Mask
// ============================================================================

static UIView *MakeBackground(CGRect frame) {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = [UIColor clearColor];
    v.tag = kBgTag;
    v.userInteractionEnabled = NO;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    Class CABackdropLayer = NSClassFromString(@"CABackdropLayer");
    Class CAFilter = NSClassFromString(@"CAFilter");
    SEL sel = NSSelectorFromString(@"filterWithType:");
    if (CABackdropLayer && CAFilter && [CAFilter respondsToSelector:sel]) {
        @try {
            id blur = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"gaussianBlur");
            [blur setValue:@(gBgBlurPref) forKey:@"inputRadius"];
            [blur setValue:@YES forKey:@"inputNormalizeEdges"];

            id sat = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorSaturate");
            [sat setValue:@(gBgSatPref) forKey:@"inputAmount"];

            id bright = ((id (*)(id, SEL, NSString *))objc_msgSend)(CAFilter, sel, @"colorBrightness");
            [bright setValue:@(-gBgDarkPref * 0.9) forKey:@"inputAmount"];

            CALayer *bd = [[CABackdropLayer alloc] init];
            bd.name = @"bgbackdrop";
            [bd setValue:@YES forKey:@"enabled"];
            [bd setValue:@1.0 forKey:@"scale"];
            bd.filters = @[blur, sat, bright];
            bd.frame = v.bounds;
            [v.layer addSublayer:bd];
        } @catch (NSException *e) {
        }
    }

    if (v.layer.sublayers.count == 0) {
        UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        ev.frame = v.bounds;
        ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [v addSubview:ev];
    }

    CALayer *dim = [CALayer layer];
    dim.name = @"bgdim";
    dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:gBgDarkPref * 0.6].CGColor;
    dim.frame = v.bounds;
    [v.layer addSublayer:dim];

    CAGradientLayer *top = [CAGradientLayer layer];
    top.name = @"bgtop";
    top.startPoint = CGPointMake(0.5, 0.0);
    top.endPoint   = CGPointMake(0.5, 1.0);
    top.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.9 * gBgTopPref].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.35 * gBgTopPref].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    top.locations = @[@0.0, @0.18, @0.42];
    top.frame = v.bounds;
    [v.layer addSublayer:top];

    return v;
}

static void ReduceBackgroundBlur(UIWindow *win) {
    if (!win) return;
    static CFTimeInterval last = 0;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - last < 0.4) return;
    last = now;
    ReduceBlurInLayer(win.layer, [UIScreen mainScreen].bounds.size, 0);
}

static void ApplyBackground(UIView *mat) {
    UIView *sup = mat.superview;
    if (!sup) return;
    MarkStyled(mat);
    objc_setAssociatedObject(mat, kBgModeKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NeutralizeMaterial(mat);

    for (UIView *sub in sup.subviews) {
        if (sub == mat || sub.tag == kBgTag) continue;
        if (![NSStringFromClass([sub class]) isEqualToString:@"UIView"]) continue;
        if (sub.subviews.count > 0) continue;
        if (CGRectGetWidth(sub.bounds) < CGRectGetWidth(sup.bounds) - 1.0 || CGRectGetHeight(sub.bounds) < 300.0) continue;
        CGFloat w = 1.0, a = 0.0;
        if ([sub.backgroundColor getWhite:&w alpha:&a] && a > 0.01 && w < 0.4) {
            sub.backgroundColor = [UIColor clearColor];
        }
    }

    UIView *bg = [sup viewWithTag:kBgTag];
    if (!bg || bg.superview != sup) {
        bg = MakeBackground(mat.frame);
        [sup insertSubview:bg aboveSubview:mat];
        NSLog(@"[CC18Glass] background replaced (blur %.0f), size=%@", gBgBlurPref, NSStringFromCGSize(mat.bounds.size));
    }

    ReduceBackgroundBlur(mat.window);

    [UIView performWithoutAnimation:^{
        bg.transform = CGAffineTransformIdentity;
        bg.frame = mat.bounds;
        for (CALayer *l in bg.layer.sublayers) {
            if ([l.name isEqualToString:@"bgbackdrop"] ||
                [l.name isEqualToString:@"bgdim"] ||
                [l.name isEqualToString:@"bgtop"]) {
                l.frame = bg.bounds;
            }
        }
    }];

    SyncGlass(mat);
}

static void HideDarkEdgeIn(UIView *v, int depth) {
    if (depth > 6) return;
    for (UIView *sub in v.subviews) {
        if (sub.tag == kGlassTag) {
            for (CALayer *l in sub.layer.sublayers) {
                if ([l.name isEqualToString:@"dark"]) {
                    l.opacity = 0.0f;
                }
            }
        }
        HideDarkEdgeIn(sub, depth + 1);
    }
}

static void ApplySliderMask(UIView *slider) {
    CGRect b = slider.bounds;
    if (b.size.width < 30.0 || b.size.height < 30.0) return;
    CGFloat r = MIN(b.size.width, b.size.height) * 0.5;

    CAShapeLayer *mask = [slider.layer.mask isKindOfClass:[CAShapeLayer class]] ? (CAShapeLayer *)slider.layer.mask : nil;
    if (!mask || ![mask.name isEqualToString:@"cc18slidermask"]) {
        mask = [CAShapeLayer layer];
        mask.name = @"cc18slidermask";
        mask.fillColor = [UIColor blackColor].CGColor;
        slider.layer.mask = mask;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = b;
    mask.path = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r].CGPath;
    [CATransaction commit];

    CAShapeLayer *ring = nil;
    for (CALayer *l in [slider.layer.sublayers copy]) {
        if ([l.name isEqualToString:@"cc18ringdark"]) {
            [l removeFromSuperlayer];
        } else if ([l.name isEqualToString:@"cc18ringlite"]) {
            ring = (CAShapeLayer *)l;
        }
    }
    if (!ring) {
        ring = [CAShapeLayer layer];
        ring.name = @"cc18ringlite";
        ring.fillColor = nil;
        ring.lineWidth = 0.8;
        ring.zPosition = 1001.0;
        [slider.layer addSublayer:ring];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    ring.frame = b;
    CGRect inset = CGRectInset(b, 0.6, 0.6);
    ring.path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0.0, r - 0.6)].CGPath;
    ring.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.45, 0.28 * gIntensity * gRimMul)].CGColor;
    HideDarkEdgeIn(slider, 0);
    [CATransaction commit];
}

// ============================================================================
// Ghost Slabs, Dylv Glass & Module Background Cleanup
// ============================================================================

static void ClearLayerShadow(CALayer *l) {
    if (l.shadowOpacity > 0.0f) {
        l.shadowOpacity = 0.0f;
    }
}

static BOOL IsDarkOpaque(UIColor *c) {
    if (!c) return NO;
    CGFloat w = 0.0, a = 0.0;
    if (![c getWhite:&w alpha:&a]) {
        CGFloat r = 0.0, g = 0.0, b = 0.0;
        if (![c getRed:&r green:&g blue:&b alpha:&a]) return NO;
        w = (r + g + b) / 3.0;
    }
    return a > 0.05 && w < 0.4;
}

static void ClearModuleBackgrounds(UIView *mat, UIView *glass) {
    UIView *sup = mat.superview;
    if (!sup) return;
    ClearLayerShadow(mat.layer);
    ClearLayerShadow(sup.layer);
    if (sup.superview) {
        ClearLayerShadow(sup.superview.layer);
    }
    for (UIView *sub in sup.subviews) {
        if (sub == mat || sub == glass) continue;
        ClearLayerShadow(sub.layer);
        if ([NSStringFromClass([sub class]) isEqualToString:@"UIView"] &&
            IsDarkOpaque(sub.backgroundColor) &&
            sub.subviews.count == 0 &&
            !sub.layer.masksToBounds) {
            sub.backgroundColor = [UIColor clearColor];
        }
    }
}

static void HideDylvGlassIn(UIView *v, int depth) {
    if (depth > 4) return;
    for (UIView *sub in v.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls isEqualToString:@"LGLiveBackdropView"] || [cls isEqualToString:@"LGBlurView"]) {
            if (!sub.hidden || sub.alpha > 0.0) {
                [UIView performWithoutAnimation:^{
                    sub.alpha = 0.0;
                    sub.hidden = YES;
                }];
            }
            continue;
        }
        if (sub.tag != kGlassTag) {
            HideDylvGlassIn(sub, depth + 1);
        }
    }
}

static BOOL ViewPaints(UIView *v) {
    CGFloat bgAlpha = v.backgroundColor ? CGColorGetAlpha(v.backgroundColor.CGColor) : 0.0;
    return bgAlpha > 0.01 || v.layer.borderWidth > 0.0 || v.layer.shadowOpacity > 0.01f;
}

static void ClearPaint(UIView *v) {
    v.backgroundColor = [UIColor clearColor];
    v.layer.borderWidth = 0.0;
    v.layer.shadowOpacity = 0.0f;
}

static BOOL ViewHasContent(UIView *v, int depth) {
    if (depth > 6) return NO;
    if (v.tag == kGlassTag || v.tag == kBgTag) return YES;
    if ([v isKindOfClass:[UILabel class]] ||
        [v isKindOfClass:[UIImageView class]] ||
        [v isKindOfClass:[UIControl class]] ||
        [v isKindOfClass:[UIScrollView class]] ||
        [v isKindOfClass:[UITextView class]]) {
        return YES;
    }
    if ([NSStringFromClass([v class]) isEqualToString:@"MTMaterialView"]) return YES;
    for (UIView *sub in v.subviews) {
        if (ViewHasContent(sub, depth + 1)) return YES;
    }
    return NO;
}

static void HideGhostViewsIn(UIView *root, UIView *mat, UIView *glass, CGRect targetRect, int depth) {
    if (depth > 6) return;
    for (UIView *sub in root.subviews) {
        if (sub == mat || sub == glass || sub.tag == kGlassTag || sub.tag == kBgTag) continue;
        if ([mat isDescendantOfView:sub] || [glass isDescendantOfView:sub]) {
            if (ViewPaints(sub) && RectHugs([sub.superview convertRect:sub.frame toView:nil], targetRect)) {
                ClearPaint(sub);
            }
            HideGhostViewsIn(sub, mat, glass, targetRect, depth + 1);
            continue;
        }
        if (sub.hidden && sub.alpha <= 0.001) continue;
        CGRect r = [sub.superview convertRect:sub.frame toView:nil];
        if (RectHugs(r, targetRect) && !ViewHasContent(sub, 0)) {
            static int logged = 0;
            if (logged < 12) {
                logged++;
                NSLog(@"[CC18Glass] ghost view hidden: %@ %@ (glass %@)",
                      NSStringFromClass([sub class]), NSStringFromCGRect(r), NSStringFromCGRect(targetRect));
            }
            sub.alpha = 0.0;
            sub.hidden = YES;
            continue;
        }
        if (RectHugs(r, targetRect) && ViewPaints(sub)) {
            ClearPaint(sub);
        }
        if (sub.subviews.count) {
            HideGhostViewsIn(sub, mat, glass, targetRect, depth + 1);
        }
    }
}

static void HideGhostLayersIn(CALayer *parent, UIView *glass, CGRect targetFrame) {
    for (CALayer *l in parent.sublayers) {
        if (l == glass.layer || [l.delegate isKindOfClass:[UIView class]] || l.hidden) continue;
        if (RectHugs(l.frame, targetFrame)) {
            static int logged = 0;
            if (logged < 12) {
                logged++;
                NSLog(@"[CC18Glass] ghost layer hidden: %@ %@", NSStringFromClass([l class]), NSStringFromCGRect(l.frame));
            }
            l.hidden = YES;
        }
    }
}

static void HideGhostSlabs(UIView *mat, UIView *glass) {
    UIView *sup = mat.superview;
    if (!sup || !glass.window || glass.hidden) return;
    CGRect wr = WindowRect(glass);
    if (wr.size.height < 20.0 || wr.size.width / wr.size.height < 2.2) return;
    UIView *host = sup.superview ?: sup;
    HideGhostViewsIn(host, mat, glass, wr, 0);
    HideGhostLayersIn(sup.layer, glass, glass.frame);
    HideGhostLayersIn(host.layer, glass, host.bounds);
}

// ============================================================================
// Core Glass Lifecycle: OwnGlass, ApplyGlass, SyncGlass, Reconcile, Refresh
// ============================================================================

static UIView *OwnGlass(UIView *mat) {
    NSMapTable *map = GlassToMat();
    for (UIView *sub in mat.superview.subviews) {
        if (sub.tag == kGlassTag && [map objectForKey:sub] == mat) {
            return sub;
        }
    }
    return nil;
}

static BOOL IsDuplicateOfAncestorGlass(UIView *mat, UIView *selfGlass) {
    CGRect mr = WindowRect(mat);
    UIView *p = mat.superview;
    for (int i = 0; p && i < 6; i++, p = p.superview) {
        for (UIView *sub in p.subviews) {
            if (sub.tag != kGlassTag || sub == selfGlass || sub.hidden) continue;
            CGRect sr = WindowRect(sub);
            if (fabs(sr.origin.x - mr.origin.x) < 6.0 &&
                fabs(sr.origin.y - mr.origin.y) < 6.0 &&
                fabs(sr.size.width - mr.size.width) < 6.0 &&
                fabs(sr.size.height - mr.size.height) < 6.0) {
                return YES;
            }
        }
    }
    return NO;
}

static void SyncGlass(UIView *mat) {
    if (objc_getAssociatedObject(mat, kBgModeKey)) {
        UIView *bg = [mat.superview viewWithTag:kBgTag];
        if (!bg) return;
        CGFloat a = mat.alpha;
        NSNumber *orig = objc_getAssociatedObject(mat, kOrigAlphaKey);
        if (orig && objc_getAssociatedObject(mat, kZeroedKey)) {
            a = [orig doubleValue];
        }
        NSNumber *wNum = objc_getAssociatedObject(mat, kWeightKey);
        CGFloat w = wNum ? MAX(0.0, MIN(1.0, [wNum doubleValue])) : 1.0;
        bg.alpha = a * w;
        return;
    }

    UIView *glass = OwnGlass(mat);
    if (!glass) return;

    if ([objc_getAssociatedObject(glass, kDupKey) boolValue] ||
        [objc_getAssociatedObject(glass, kOverlapKey) boolValue]) {
        if (!glass.hidden) {
            [UIView performWithoutAnimation:^{
                glass.hidden = YES;
            }];
        }
        return;
    }

    if (FocusOversized(mat) || IsFocusListBackdrop(mat)) {
        if (!glass.hidden) {
            [UIView performWithoutAnimation:^{
                glass.hidden = YES;
            }];
        }
        return;
    }

    if (!mat.hidden && glass.hidden) {
        [UIView performWithoutAnimation:^{
            PlaceGlassWithDuration(glass, mat, 0.0);
        }];
    }

    CGFloat a = mat.alpha;
    NSNumber *orig = objc_getAssociatedObject(mat, kOrigAlphaKey);
    if (orig && objc_getAssociatedObject(mat, kZeroedKey)) {
        a = [orig doubleValue];
    }
    NSNumber *prevNum = objc_getAssociatedObject(glass, kPrevAlphaKey);
    CGFloat prevA = prevNum ? [prevNum doubleValue] : 0.0;
    objc_setAssociatedObject(glass, kPrevAlphaKey, @(a), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    BOOL hide = mat.hidden;
    CGFloat target = a * GlassOnAlpha();
    if (fabs(a - prevA) > 0.001 && (a <= 0.01 || prevA <= 0.01)) {
        [UIView performWithoutAnimation:^{
            glass.alpha = target;
            glass.hidden = hide;
        }];
    } else {
        glass.alpha = target;
        if (glass.hidden != hide) {
            [UIView performWithoutAnimation:^{
                glass.hidden = hide;
            }];
        }
    }
}

static void ApplyGlass(UIView *mat) {
    if (!gEnabled) return;

    if (IsFullScreenMatInCC(mat)) {
        UIView *curBg = [BgMatHolder() anyObject];
        if (IsControlCenterBackground(mat) && (!curBg || curBg == mat || !curBg.window)) {
            [BgMatHolder() removeAllObjects];
            [BgMatHolder() addObject:mat];
            ApplyBackground(mat);
        } else {
            MarkStyled(mat);
            NeutralizeMaterial(mat);
        }
        return;
    }

    if (IsFocusListBackdrop(mat)) {
        MarkStyled(mat);
        NeutralizeMaterial(mat);
        UIView *g = OwnGlass(mat);
        if (g) {
            [UIView performWithoutAnimation:^{
                g.hidden = YES;
            }];
        }
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();
    NSValue *lastSz = objc_getAssociatedObject(mat, kApplySizeKey);
    NSNumber *lastT = objc_getAssociatedObject(mat, kApplyTimeKey);
    if (lastSz && lastT &&
        CGSizeEqualToSize([lastSz CGSizeValue], mat.bounds.size) &&
        (now - [lastT doubleValue]) < 0.35 &&
        OwnGlass(mat) != nil) {
        return;
    }
    objc_setAssociatedObject(mat, kApplySizeKey, [NSValue valueWithCGSize:mat.bounds.size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(mat, kApplyTimeKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    const char *reason = "";
    BOOL ok = ShouldStyle(mat, &reason);

    static NSMutableSet *seen;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        seen = [NSMutableSet set];
    });

    NSMutableString *chain = [NSMutableString string];
    BOOL hasCC = NO;
    UIView *p = mat;
    for (int i = 0; p && i < 6; i++, p = p.superview) {
        NSString *cls = NSStringFromClass([p class]);
        if (IsCCClassName(cls)) hasCC = YES;
        [chain appendFormat:@"%@ < ", cls];
    }
    if (ok || hasCC) {
        NSString *key = [NSString stringWithFormat:@"%d|%@", ok, chain];
        if (![seen containsObject:key]) {
            [seen addObject:key];
            if (ok) {
                NSLog(@"[CC18Glass] styled: %@ size=%@ content=%d", chain, NSStringFromCGSize(mat.bounds.size), HasContentSubviews(mat));
            } else {
                NSLog(@"[CC18Glass] SKIPPED(%s): %@ size=%@", reason, chain, NSStringFromCGSize(mat.bounds.size));
            }
        }
    }

    if (!ok) return;

    UIView *sup = mat.superview;
    if (!sup) return;

    if (FocusOversized(mat)) {
        UIView *g = OwnGlass(mat);
        if (g) {
            [UIView performWithoutAnimation:^{
                g.hidden = YES;
            }];
        }
        MarkStyled(mat);
        NeutralizeMaterial(mat);
        return;
    }

    UIView *glass = OwnGlass(mat);
    if (IsDuplicateOfAncestorGlass(mat, glass)) {
        MarkStyled(mat);
        NeutralizeMaterial(mat);
        if (glass) {
            objc_setAssociatedObject(glass, kDupKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [UIView performWithoutAnimation:^{
                glass.hidden = YES;
            }];
        }
        return;
    }

    if (glass) {
        objc_setAssociatedObject(glass, kDupKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    MarkStyled(mat);
    BOOL hasContent = HasContentSubviews(mat);
    NeutralizeMaterial(mat);

    if (glass && glass.superview != sup) {
        [glass removeFromSuperview];
        glass = nil;
    }

    BOOL created = NO;
    if (!glass) {
        created = YES;
        glass = MakeGlass(mat.frame);
        [GlassToMat() setObject:mat forKey:glass];
        if (hasContent) {
            [sup insertSubview:glass belowSubview:mat];
        } else {
            [sup insertSubview:glass aboveSubview:mat];
        }
    }

    if (created) {
        [UIView performWithoutAnimation:^{
            PlaceGlassWithDuration(glass, mat, 0.0);
        }];
    } else {
        PlaceGlass(glass, mat);
    }

    [TouchGlasses() addObject:glass];
    [GlassToMat() setObject:mat forKey:glass];

    UIView *slider = SliderAncestor(mat);
    if (slider) {
        ApplySliderMask(slider);
    }

    HideDylvGlassIn(sup, 0);
    ClearModuleBackgrounds(mat, glass);
    HideGhostSlabs(mat, glass);
    SyncGlass(mat);
}

static void ReconcileGlasses(void) {
    if (!gEnabled) return;
    static int gGhostPass = 0;
    gGhostPass++;

    NSMapTable *map = GlassToMat();
    if ((gGhostPass % 10) == 0) {
        for (UIView *mat in [StyledMats() allObjects]) {
            if (mat.window && mat.superview && IsControlCenterBackground(mat) && ![mat.superview viewWithTag:kBgTag]) {
                ApplyGlass(mat);
            }
            if (mat.window && !mat.hidden && mat.superview &&
                CGRectGetHeight(mat.bounds) <= 420.0 &&
                CGRectGetWidth(mat.bounds) <= 400.0 &&
                OwnGlass(mat) == nil &&
                ModuleShown(mat)) {
                ApplyGlass(mat);
            }
        }
    }

    for (UIView *glass in [[map keyEnumerator] allObjects]) {
        UIView *mat = [map objectForKey:glass];
        if (!mat || !mat.superview || mat.superview != glass.superview) {
            NSLog(@"[CC18Glass] reconcile: removed orphan glass %@", NSStringFromCGRect(glass.frame));
            if (glass.superview) {
                [glass removeFromSuperview];
            }
            [map removeObjectForKey:glass];
            continue;
        }
        if (!mat.window) {
            if (!glass.hidden) {
                [UIView performWithoutAnimation:^{
                    glass.hidden = YES;
                }];
            }
            continue;
        }
        if ([objc_getAssociatedObject(glass, kDupKey) boolValue]) {
            if (!IsDuplicateOfAncestorGlass(mat, glass)) {
                objc_setAssociatedObject(glass, kDupKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                SyncGlass(mat);
            }
            continue;
        }
        if (FocusOversized(mat) || IsFocusListBackdrop(mat)) {
            if (!glass.hidden) {
                [UIView performWithoutAnimation:^{
                    glass.hidden = YES;
                }];
            }
            continue;
        }
        if (!mat.hidden && glass.hidden) {
            SyncGlass(mat);
        }
        if ((gGhostPass % 15) == 0) {
            HideGhostSlabs(mat, glass);
        }
        if ([objc_getAssociatedObject(glass, kOverlapKey) boolValue]) continue;

        CGRect gr = WindowRect(glass);
        CGRect mr = WindowRect(mat);
        if (fabs(gr.origin.x - mr.origin.x) > 1.5 ||
            fabs(gr.origin.y - mr.origin.y) > 1.5 ||
            fabs(gr.size.width - mr.size.width) > 1.5 ||
            fabs(gr.size.height - mr.size.height) > 1.5) {
            NSLog(@"[CC18Glass] reconcile: stale glass %@ vs module %@", NSStringFromCGRect(gr), NSStringFromCGRect(mr));
            PlaceGlass(glass, mat);
        }
    }

    NSMutableArray *live = [NSMutableArray array];
    for (UIView *glass in [[map keyEnumerator] allObjects]) {
        UIView *mat = [map objectForKey:glass];
        if (!mat || mat.superview != glass.superview || !mat.window || !ModuleShown(mat)) continue;
        if ([objc_getAssociatedObject(glass, kDupKey) boolValue] || FocusOversized(mat) || IsFocusListBackdrop(mat)) continue;
        [live addObject:glass];
    }

    NSMutableSet *overlapped = [NSMutableSet set];
    for (NSUInteger i = 0; i < live.count; i++) {
        for (NSUInteger j = i + 1; j < live.count; j++) {
            CGRect ri = WindowRect(live[i]);
            CGRect rj = WindowRect(live[j]);
            CGFloat aspI = ri.size.width / MAX(1.0, ri.size.height);
            CGFloat aspJ = rj.size.width / MAX(1.0, rj.size.height);
            if (MAX(aspI, aspJ) < 2.2) continue;
            if (RectTwins(ri, rj) && NearRelatives(live[i], live[j])) {
                CGFloat ai = ri.size.width * ri.size.height;
                CGFloat aj = rj.size.width * rj.size.height;
                UIView *bigger  = (ai > aj) ? live[i] : live[j];
                UIView *smaller = (ai > aj) ? live[j] : live[i];
                if (!smaller.hidden || [objc_getAssociatedObject(smaller, kOverlapKey) boolValue]) {
                    [overlapped addObject:bigger];
                }
            }
        }
    }

    for (UIView *glass in live) {
        BOOL ov = [overlapped containsObject:glass];
        BOOL prevOv = [objc_getAssociatedObject(glass, kOverlapKey) boolValue];
        if (ov == prevOv) continue;
        objc_setAssociatedObject(glass, kOverlapKey, @(ov), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (ov) {
            NSLog(@"[CC18Glass] ghost glass hidden (bigger glass over a smaller one): %@", NSStringFromCGRect(WindowRect(glass)));
            [UIView performWithoutAnimation:^{
                glass.hidden = YES;
            }];
        } else {
            UIView *mat = [map objectForKey:glass];
            if (mat) SyncGlass(mat);
        }
    }
}

static void RefreshAllGlass(void) {
    NSMapTable *map = GlassToMat();
    BOOL turnedOn = gEnabled && !gWasEnabled;
    gWasEnabled = gEnabled;

    if (gEnabled && !turnedOn) {
        for (UIView *glass in [[map keyEnumerator] allObjects]) {
            RestyleGlass(glass);
            UIView *mat = [map objectForKey:glass];
            if (mat) {
                objc_setAssociatedObject(glass, kLayoutKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                PlaceGlass(glass, mat);
            }
            UIView *slider = mat ? SliderAncestor(mat) : nil;
            if (slider) {
                ApplySliderMask(slider);
            }
        }
    }

    for (UIView *mat in [StyledMats() allObjects]) {
        BOOL isBg = objc_getAssociatedObject(mat, kBgModeKey) != nil;
        if (!gEnabled || turnedOn || isBg) {
            UIView *sup = mat.superview;
            UIView *g = OwnGlass(mat);
            if (g) [g removeFromSuperview];
            for (UIView *k in [[map keyEnumerator] allObjects]) {
                if ([map objectForKey:k] == mat) {
                    [k removeFromSuperview];
                    [map removeObjectForKey:k];
                }
            }
            UIView *bg = [sup viewWithTag:kBgTag];
            if (bg) [bg removeFromSuperview];
            objc_setAssociatedObject(mat, kApplySizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (!gEnabled) {
                NSNumber *orig = objc_getAssociatedObject(mat, kOrigAlphaKey);
                objc_setAssociatedObject(mat, kZeroedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(mat, kStyledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(mat, kBgModeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                gInternal = YES;
                mat.alpha = orig ? [orig doubleValue] : 1.0;
                gInternal = NO;
            }
            [mat setNeedsLayout];
            [sup setNeedsLayout];
            if (gEnabled && mat.window && sup) {
                if (turnedOn || isBg) {
                    ApplyGlass(mat);
                }
            }
        }
    }
}

// ============================================================================
// Pager Liquid Animation & Polling
// ============================================================================

static UIView *FindPagerIn(UIView *v, int depth) {
    if (depth > 14) return nil;
    if ([NSStringFromClass([v class]) isEqualToString:@"C18PageScrollView"]) {
        return v;
    }
    for (UIView *sub in v.subviews) {
        UIView *found = FindPagerIn(sub, depth + 1);
        if (found) return found;
    }
    return nil;
}

static BOOL HasVisibleTile(UIView *v, int depth) {
    if (depth > 8) return NO;
    for (UIView *sub in v.subviews) {
        if ([NSStringFromClass([sub class]) isEqualToString:@"C18Tile"]) {
            return YES;
        }
        if (HasVisibleTile(sub, depth + 1)) return YES;
    }
    return NO;
}

static void CollectGlassModules(UIView *v, NSMutableArray *out, int depth) {
    if (depth > 12) return;
    for (UIView *sub in v.subviews) {
        if (sub.tag == kGlassTag && !sub.hidden) {
            [out addObject:v];
            continue;
        }
        if (sub.tag != kGlassTag) {
            CollectGlassModules(sub, out, depth + 1);
        }
    }
}

static void CollectC18Modules(UIView *v, NSMutableArray *out, int depth) {
    if (depth > 10) return;
    for (UIView *sub in v.subviews) {
        if ([NSStringFromClass([sub class]) isEqualToString:@"C18ModuleView"]) {
            if (sub.bounds.size.width > 250.0 && HasVisibleTile(sub, 0)) {
                CollectGlassModules(sub, out, 0);
            } else {
                [out addObject:sub];
            }
        } else {
            CollectC18Modules(sub, out, depth + 1);
        }
    }
}

static UIView *PageOf(UIView *v) {
    for (UIView *p = v.superview; p; p = p.superview) {
        if ([NSStringFromClass([p class]) isEqualToString:@"C18PageView"]) {
            return p;
        }
    }
    return nil;
}

static void PagerLiquid(UIView *root, int dir, CGFloat baseShift, CGFloat extraShift) {
    if (!gEnabled || gAnimMul <= 0.01) return;
    NSMutableArray *mods = [NSMutableArray array];
    CollectC18Modules(root, mods, 0);
    if (mods.count == 0) {
        CollectGlassModules(root, mods, 0);
    }
    if (mods.count == 0) return;

    NSSet *set = [NSSet setWithArray:mods];
    NSMutableArray *top = [NSMutableArray array];
    for (UIView *v in mods) {
        BOOL nested = NO;
        for (UIView *p = v.superview; p && p != root; p = p.superview) {
            if ([set containsObject:p]) {
                nested = YES;
                break;
            }
        }
        if (!nested) [top addObject:v];
    }

    CGFloat scrH = [UIScreen mainScreen].bounds.size.height;
    CFTimeInterval now = CACurrentMediaTime();

    for (UIView *v in top) {
        UIView *page = PageOf(v);
        CGFloat y = 0.0;
        CGFloat ph = scrH;
        if (page) {
            y  = [v.superview convertPoint:v.center toView:page].y;
            ph = MAX(1.0, page.bounds.size.height);
        } else {
            y  = [v.superview convertPoint:v.center toView:nil].y;
        }
        CGFloat norm = MAX(0.0, MIN(1.0, y / ph));
        if (dir < 0) norm = 1.0 - norm;

        int rank = 0;
        for (UIView *o in top) {
            if (o == v) continue;
            UIView *op = PageOf(o);
            if (page && op && op != page) continue;
            CGFloat oy = op ? [o.superview convertPoint:o.center toView:op].y : [o.superview convertPoint:o.center toView:nil].y;
            if ((dir > 0 && oy < y - 10.0) || (dir < 0 && oy > y + 10.0)) {
                rank++;
            }
        }

        CGFloat dy = dir * (baseShift + extraShift * norm) * gAnimMul * (g27 ? 1.25 : 1.0);
        CASpringAnimation *pos = [CASpringAnimation animationWithKeyPath:@"transform.translation.y"];
        pos.fromValue = @(dy);
        pos.toValue   = @0.0;
        pos.mass      = 1.0;
        pos.stiffness = g27 ? 225.0 : 484.0;
        pos.damping   = g27 ? 18.0  : 44.0;
        pos.initialVelocity = 0.0;
        pos.duration  = pos.settlingDuration;
        pos.beginTime = now + MIN(0.05, 0.012 * rank);
        pos.fillMode  = kCAFillModeBackwards;
        [v.layer addAnimation:pos forKey:@"cc18PagerLiquid"];

        if (g27) {
            CGRect wr = [v.superview convertRect:v.frame toView:nil];
            BOOL offscreen = CGRectGetMaxY(wr) < 0.0 || CGRectGetMinY(wr) > scrH;
            if (offscreen) {
                float op = v.layer.opacity;
                CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
                fade.fromValue = @(op * 0.25f);
                fade.toValue   = @(op);
                fade.duration  = 0.3;
                fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
                fade.beginTime = pos.beginTime;
                fade.fillMode  = kCAFillModeBackwards;
                [v.layer addAnimation:fade forKey:@"cc18PagerFade"];
            }
        }

        BOOL isNP = v.bounds.size.width > 200.0 && v.bounds.size.height > 120.0;
        CGFloat stretch = MIN(0.22, (0.07 + 0.06 * norm) * (isNP ? 1.5 : 1.0) * gAnimMul * gStretchMul);
        if (stretch > 0.005) {
            CASpringAnimation *sy = [CASpringAnimation animationWithKeyPath:@"transform.scale.y"];
            sy.fromValue = @(1.0 + stretch);
            sy.toValue   = @1.0;
            sy.mass      = 1.0;
            sy.stiffness = isNP ? 190.0 : 260.0;
            sy.damping   = isNP ? 11.0  : 15.0;
            sy.initialVelocity = 0.0;
            sy.duration  = sy.settlingDuration;
            sy.beginTime = pos.beginTime;
            sy.fillMode  = kCAFillModeBackwards;
            [v.layer addAnimation:sy forKey:@"cc18PagerStretchY"];

            CASpringAnimation *sx = [CASpringAnimation animationWithKeyPath:@"transform.scale.x"];
            sx.fromValue = @(1.0 - stretch * 0.45);
            sx.toValue   = @1.0;
            sx.mass      = 1.0;
            sx.stiffness = isNP ? 190.0 : 260.0;
            sx.damping   = isNP ? 11.0  : 15.0;
            sx.initialVelocity = 0.0;
            sx.duration  = sx.settlingDuration;
            sx.beginTime = pos.beginTime;
            sx.fillMode  = kCAFillModeBackwards;
            [v.layer addAnimation:sx forKey:@"cc18PagerPinchX"];
        }
    }
}

static void PagerPoll(UIWindow *win) {
    static __weak UIScrollView *pager = nil;
    static CGFloat prevY = 0.0;
    static CGFloat acc   = 0.0;
    static int look      = 0;
    static int still     = 0;
    static BOOL moved    = NO;

    if (!pager || !pager.window) {
        if ((++look % 30) != 1 || !win) return;
        pager = (UIScrollView *)FindPagerIn(win, 0);
        if (pager) {
            prevY = pager.contentOffset.y;
            acc = 0.0;
        }
        return;
    }

    CGFloat y  = pager.contentOffset.y;
    CGFloat dy = y - prevY;
    prevY = y;

    if (fabs(dy) >= 0.2) {
        moved = YES;
        still = 0;
    } else if (moved && ++still > 70) {
        moved = NO;
        still = 0;
        DumpHorizontalModules();
    }

    if (pager.isTracking || fabs(dy) < 0.2) {
        acc = 0.0;
        return;
    }

    acc += dy;
    CFTimeInterval now = CACurrentMediaTime();
    if (fabs(acc) > 30.0 && now - gPagerLast > 0.6) {
        int dir = acc > 0.0 ? 1 : -1;
        gPagerLast = now;
        acc = 0.0;
        PagerLiquid(pager, dir, 20.0, 150.0);
    }
}

// ============================================================================
// Touch Lean & Glow
// ============================================================================

static CALayer *TouchGlowLayer(UIView *glass) {
    for (CALayer *l in glass.layer.sublayers) {
        if ([l.name isEqualToString:@"touchglow"]) {
            return l;
        }
    }
    return nil;
}

static UIView *GlassUnder(CGPoint winPt) {
    UIView *best = nil;
    CGFloat bestArea = DBL_MAX;
    for (UIView *g in [TouchGlasses() allObjects]) {
        if (!g.window || g.hidden || g.alpha < 0.05) continue;
        CGRect r = [g.superview convertRect:g.frame toView:nil];
        if (!CGRectContainsPoint(r, winPt)) continue;
        CGFloat area = r.size.width * r.size.height;
        if (area < bestArea) {
            bestArea = area;
            best = g;
        }
    }
    return best;
}

static void TouchMove(UIView *glass, CGPoint winPt, BOOL began) {
    CALayer *glow = TouchGlowLayer(glass);
    if (!glow) return;
    CGPoint p = [glass convertPoint:winPt fromView:nil];
    CGRect b = glass.bounds;
    CGFloat nx = MAX(-1.0, MIN(1.0, (p.x - b.size.width / 2.0) / MAX(1.0, b.size.width / 2.0)));
    CGFloat ny = MAX(-1.0, MIN(1.0, (p.y - b.size.height / 2.0) / MAX(1.0, b.size.height / 2.0)));
    CGFloat shift = MIN(b.size.width, b.size.height) * 0.03;

    [CATransaction begin];
    [CATransaction setAnimationDuration:began ? 0.16 : 0.08];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    glow.position = p;
    CATransform3D t = CATransform3DMakeTranslation(nx * shift, ny * shift, 0.0);
    t = CATransform3DScale(t, 1.035, 1.035, 1.0);
    glass.layer.sublayerTransform = t;
    [CATransaction commit];
}

static void TouchEnd(UIView *glass) {
    CALayer *glow = TouchGlowLayer(glass);
    if (glow) {
        float fromOp = glow.presentationLayer ? glow.presentationLayer.opacity : glow.opacity;
        glow.opacity = 0.0f;
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @(fromOp);
        fade.toValue   = @0.0;
        fade.duration  = 0.55;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [glow addAnimation:fade forKey:@"cc18touchfade"];
    }

    CATransform3D fromT = glass.layer.presentationLayer ? glass.layer.presentationLayer.sublayerTransform : glass.layer.sublayerTransform;
    glass.layer.sublayerTransform = CATransform3DIdentity;
    CASpringAnimation *sp = [CASpringAnimation animationWithKeyPath:@"sublayerTransform"];
    sp.fromValue = [NSValue valueWithCATransform3D:fromT];
    sp.toValue   = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    sp.mass      = 1.0;
    sp.stiffness = 140.0;
    sp.damping   = 9.0;
    sp.initialVelocity = 0.0;
    sp.duration  = sp.settlingDuration;
    [glass.layer addAnimation:sp forKey:@"cc18touchlean"];
}

static void TouchSafetyNet(void) {
    if (gTouchGlass) return;
    for (UIView *g in [TouchGlasses() allObjects]) {
        CALayer *glow = TouchGlowLayer(g);
        if (glow && glow.opacity > 0.001f && ![glow animationForKey:@"cc18touchfade"]) {
            glow.opacity = 0.0f;
        }
        if (![g.layer animationForKey:@"cc18touchlean"] && !CATransform3DIsIdentity(g.layer.sublayerTransform)) {
            g.layer.sublayerTransform = CATransform3DIdentity;
        }
    }
}

static void LogTap(NSString *tag, id arg) {
    if (!gTapLog) gTapLog = [NSMutableString string];
    NSString *desc = arg ? [[arg description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] : @"nil";
    if (desc.length > 180) {
        desc = [desc substringToIndex:180];
    }
    NSString *title = @"";
    if ([arg isKindOfClass:[UIView class]]) {
        id lbl = [arg respondsToSelector:NSSelectorFromString(@"titleLabel")] ? [arg valueForKey:@"titleLabel"] : nil;
        if ([lbl isKindOfClass:[UILabel class]]) {
            title = [(UILabel *)lbl text] ?: @"";
        }
    }
    [gTapLog appendFormat:@"%@ arg=%@ title=\"%@\" :: %@\n",
     tag,
     arg ? NSStringFromClass([arg class]) : @"nil",
     title,
     desc];
    if (gTapLog.length > 4000) {
        [gTapLog deleteCharactersInRange:NSMakeRange(0, gTapLog.length - 4000)];
    }
}

// ============================================================================
// Expand / Pop Animations & Geometry Resync
// ============================================================================

static void PopView(UIView *v) {
    (void)v;
}

static BOOL HasStyledMaterialAbove(UIView *mat) {
    UIView *p = mat.superview.superview;
    for (int i = 0; p && i < 6; i++, p = p.superview) {
        for (UIView *sub in p.subviews) {
            if (sub != mat &&
                [NSStringFromClass([sub class]) isEqualToString:@"MTMaterialView"] &&
                objc_getAssociatedObject(sub, kStyledKey) &&
                !objc_getAssociatedObject(sub, kBgModeKey)) {
                return YES;
            }
        }
    }
    return NO;
}

static void PopWhenAppearing(UIView *mat) {
    if (!mat.window) return;
    if (objc_getAssociatedObject(mat, kBgModeKey)) return;
    if (!objc_getAssociatedObject(mat, kStyledKey)) return;
    UIView *g = OwnGlass(mat);
    if (!g || g.hidden) return;
    if (HasStyledMaterialAbove(mat)) return;
    PopView(mat.superview);
}

static void PopModulesIn(UIView *root) {
    if (!root) return;
    NSMutableArray *mods = [NSMutableArray array];
    CollectGlassModules(root, mods, 0);
    NSSet *set = [NSSet setWithArray:mods];
    for (UIView *v in mods) {
        BOOL nested = NO;
        for (UIView *p = v.superview; p && p != root; p = p.superview) {
            if ([set containsObject:p]) {
                nested = YES;
                break;
            }
        }
        if (!nested) {
            PopView(v);
        }
    }
}

static BOOL IsExpandedModule(UIView *mat) {
    CGSize sz = mat.bounds.size;
    if (sz.width > 250.0 && sz.height > 300.0) return YES;
    if (SliderAncestor(mat) && CGRectGetHeight(mat.bounds) > 230.0) return YES;
    return NO;
}

static void KillFadeStep(UIView *mat) {
    CGSize scr = [UIScreen mainScreen].bounds.size;
    UIView *p = mat.superview;
    for (int i = 0; p && i < 8; i++, p = p.superview) {
        if ([p isKindOfClass:[UIWindow class]]) break;
        if (p.bounds.size.width >= scr.width - 2.0 && p.bounds.size.height >= scr.height - 2.0) break;
        if (p.alpha < 0.999 || [p.layer animationForKey:@"opacity"]) {
            [p.layer removeAnimationForKey:@"opacity"];
            [UIView performWithoutAnimation:^{
                p.alpha = 1.0;
            }];
        }
    }
}

static void KillExpandFade(UIView *mat) {
    if (!gEnabled || !IsExpandedModule(mat)) return;
    KillFadeStep(mat);
    dispatch_async(dispatch_get_main_queue(), ^{
        KillFadeStep(mat);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        KillFadeStep(mat);
    });
}

static void ResyncGeometry(UIView *mat) {
    if (!objc_getAssociatedObject(mat, kStyledKey)) return;
    UIView *glass = OwnGlass(mat);
    if (!glass) return;
    if ([objc_getAssociatedObject(glass, kDupKey) boolValue]) return;
    if (FocusOversized(mat)) {
        [UIView performWithoutAnimation:^{
            glass.hidden = YES;
        }];
        return;
    }
    PlaceGlass(glass, mat);
    UIView *slider = SliderAncestor(mat);
    if (slider) {
        ApplySliderMask(slider);
    }
}

// ============================================================================
// Diagnostic Dump Helpers & Conflict Scanner
// ============================================================================

static void FindTiles(UIView *v, NSMutableArray *out, int depth) {
    if (depth > 30 || out.count >= 8) return;
    for (UIView *sub in v.subviews) {
        if ([NSStringFromClass([sub class]) isEqualToString:@"C18Tile"] && !sub.hidden) {
            [out addObject:sub];
        } else {
            FindTiles(sub, out, depth + 1);
        }
    }
}

static void ProbeLayers(NSMutableString *out, CALayer *l, CGFloat effOpacity, int depth, NSString *chain, int *count, CGRect target) {
    if (depth > 40 || l.hidden || *count > 60) return;
    CGFloat op = effOpacity * (CGFloat)l.opacity;
    if (op < 0.01) return;
    id del = l.delegate;
    if ([del isKindOfClass:[UIView class]]) {
        NSInteger tag = [(UIView *)del tag];
        if (tag == kGlassTag || tag == kBgTag) return;
    }
    CGRect r = [l convertRect:l.bounds toLayer:nil];
    if (r.size.width > 20.0 && RectHugs(r, target)) {
        CGFloat bgAlpha = l.backgroundColor ? CGColorGetAlpha(l.backgroundColor) : 0.0;
        [out appendFormat:@"  %@ delegate=%@ rect=(%.1f,%.1f %.1fx%.1f) effOpacity=%.2f bgAlpha=%.2f corner=%.1f border=%.1f shadow=%.2f contents=%d filters=%lu\n      chain: %@\n",
         NSStringFromClass([l class]),
         del ? NSStringFromClass([del class]) : @"-",
         r.origin.x, r.origin.y, r.size.width, r.size.height,
         op, bgAlpha, l.cornerRadius, l.borderWidth, (double)l.shadowOpacity,
         l.contents != nil, (unsigned long)l.filters.count, chain];
        (*count)++;
    }
    NSString *tagName = del ? NSStringFromClass([del class]) : NSStringFromClass([l class]);
    NSString *nextChain = [NSString stringWithFormat:@"%@ > %@", chain.length > 140 ? @"..." : chain, tagName];
    for (CALayer *sub in l.sublayers) {
        ProbeLayers(out, sub, op, depth + 1, nextChain, count, target);
    }
}

static void DumpClassInfo(NSMutableString *out, NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) {
        [out appendFormat:@"CLASS %@: not found\n", name];
        return;
    }
    [out appendFormat:@"CLASS %@", name];
    for (Class sc = class_getSuperclass(cls); sc; sc = class_getSuperclass(sc)) {
        [out appendFormat:@" < %@", NSStringFromClass(sc)];
    }
    [out appendString:@"\n"];

    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        [out appendFormat:@"  ivar %s %s\n", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i])];
    }
    free(ivars);

    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count && i < 90; i++) {
        [out appendFormat:@"  - %@\n", NSStringFromSelector(method_getName(methods[i]))];
    }
    free(methods);
}

static void ProbeTile(NSMutableString *out, UIView *v, int depth) {
    if (depth > 4) return;
    NSString *pad = [@"" stringByPaddingToLength:(NSUInteger)(depth * 2 + 2) withString:@" " startingAtIndex:0];
    CGRect r = v.superview ? [v.superview convertRect:v.frame toView:nil] : v.frame;
    NSMutableString *line = [NSMutableString stringWithFormat:@"%@%@ (%.0f,%.0f %.0fx%.0f) alpha=%.2f hidden=%d ui=%d",
                             pad, NSStringFromClass([v class]),
                             r.origin.x, r.origin.y, r.size.width, r.size.height,
                             v.alpha, v.hidden, v.userInteractionEnabled];
    if ([v isKindOfClass:[UILabel class]]) {
        [line appendFormat:@" text=\"%@\"", [(UILabel *)v text] ?: @""];
    }
    if (v.accessibilityLabel.length) {
        [line appendFormat:@" axLabel=\"%@\"", v.accessibilityLabel];
    }
    if ([v isKindOfClass:[UIControl class]]) {
        UIControl *c = (UIControl *)v;
        UIControlEvents evs[4] = {
            UIControlEventTouchUpInside,
            UIControlEventTouchDown,
            UIControlEventValueChanged,
            UIControlEventPrimaryActionTriggered
        };
        for (id tgt in c.allTargets) {
            for (NSUInteger i = 0; i < 4; i++) {
                NSArray *acts = [c actionsForTarget:tgt forControlEvent:evs[i]] ?: @[];
                for (NSString *act in acts) {
                    [line appendFormat:@" action=%@(event %lu) on %@", act, (unsigned long)evs[i], NSStringFromClass([tgt class])];
                }
            }
        }
    }
    if ([v respondsToSelector:NSSelectorFromString(@"menu")]) {
        id menu = [v valueForKey:@"menu"];
        if (menu) {
            [line appendFormat:@" MENU=%@", NSStringFromClass([menu class])];
        }
        if ([v respondsToSelector:NSSelectorFromString(@"showsMenuAsPrimaryAction")]) {
            [line appendFormat:@" primary=%@", [v valueForKey:@"showsMenuAsPrimaryAction"]];
        }
    }
    [out appendFormat:@"%@\n", line];

    for (UIGestureRecognizer *gr in v.gestureRecognizers) {
        NSString *d = [gr description];
        if (d.length > 220) d = [d substringToIndex:220];
        [out appendFormat:@"%@  gesture: %@\n", pad, d];
    }
    for (UIView *sub in v.subviews) {
        ProbeTile(out, sub, depth + 1);
    }
}

static void DumpPainters(NSMutableString *out, UIView *v, CGFloat effAlpha, NSString *chain, int depth) {
    if (depth > 30 || v.hidden) return;
    CGFloat ea = effAlpha * v.alpha;
    if (ea < 0.01) return;
    NSString *cls = NSStringFromClass([v class]);
    CGRect r = v.superview ? [v.superview convertRect:v.frame toView:nil] : v.frame;
    CGRect scr = [UIScreen mainScreen].bounds;
    BOOL onScreen = CGRectIntersectsRect(r, scr) && r.origin.y >= 0.0 && CGRectGetMaxY(r) <= scr.size.height + 1.0;
    BOOL isPill = r.size.height >= 40.0 && r.size.height <= 200.0 &&
                  r.size.width >= 90.0 && r.size.width <= 400.0 &&
                  (r.size.width / r.size.height) >= 1.8;
    CGFloat w = 0.0, bgA = 0.0;
    [v.backgroundColor getWhite:&w alpha:&bgA];
    BOOL paints = bgA > 0.02 ||
                  v.layer.borderWidth > 0.0 ||
                  v.layer.shadowOpacity > 0.01f ||
                  v.tag == kGlassTag ||
                  [cls containsString:@"Material"] ||
                  [cls containsString:@"Backdrop"] ||
                  [cls containsString:@"Blur"] ||
                  [v isKindOfClass:[UIVisualEffectView class]];

    if (onScreen && isPill && paints) {
        [out appendFormat:@"VIEW %@  rect=(%.1f,%.1f %.1fx%.1f) effAlpha=%.2f own=%.2f corner=%.1f bg=%.2f border=%.1f shadow=%.2f tag=%ld\n    chain: %@\n",
         cls, r.origin.x, r.origin.y, r.size.width, r.size.height,
         ea, v.alpha, v.layer.cornerRadius, bgA, v.layer.borderWidth, (double)v.layer.shadowOpacity,
         (long)v.tag, chain];
    }

    if (v.tag != kGlassTag) {
        for (CALayer *l in v.layer.sublayers) {
            if ([l.delegate isKindOfClass:[UIView class]] || l.hidden || (CGFloat)l.opacity * ea < 0.01) continue;
            CGRect lr = [v.layer convertRect:l.frame toLayer:nil];
            BOOL lPill = lr.size.height >= 40.0 && lr.size.height <= 200.0 &&
                         lr.size.width >= 90.0 && lr.size.width <= 400.0 &&
                         (lr.size.width / lr.size.height) >= 1.8 &&
                         CGRectIntersectsRect(lr, scr) && lr.origin.y >= 0.0;
            if (lPill) {
                [out appendFormat:@"LAYER %@ name=%@ rect=(%.1f,%.1f %.1fx%.1f) opacity=%.2f corner=%.1f  (inside %@)\n    chain: %@\n",
                 NSStringFromClass([l class]), l.name ?: @"-",
                 lr.origin.x, lr.origin.y, lr.size.width, lr.size.height,
                 (double)l.opacity, l.cornerRadius, cls, chain];
            }
        }
    }

    NSString *nextChain = [NSString stringWithFormat:@"%@ > %@", chain.length > 160 ? @"..." : chain, cls];
    for (UIView *sub in v.subviews) {
        DumpPainters(out, sub, ea, nextChain, depth + 1);
    }
}

static void DumpHorizontalModules(void) {
    UIWindow *win = nil;
    for (UIView *g in [[GlassToMat() keyEnumerator] allObjects]) {
        if (g.window) {
            win = g.window;
            break;
        }
    }
    if (!win) {
        NSLog(@"[CC18Glass] dump: no window");
        return;
    }

    NSMutableString *out = [NSMutableString stringWithFormat:@"CC18 painters dump %@ (open control center, wait 4 s)\nscreen=%@\n\n",
                            [NSDate date], NSStringFromCGSize([UIScreen mainScreen].bounds.size)];
    CGRect scr = [UIScreen mainScreen].bounds;

    NSMutableArray *tiles = [NSMutableArray array];
    FindTiles(win, tiles, 0);
    UIView *firstTile = [tiles firstObject];
    CGFloat effA = 1.0;
    for (UIView *p = firstTile; p; p = p.superview) {
        effA *= p.alpha;
    }
    [out appendFormat:@"CONNECTIVITY PAGE OPEN: %@ (first C18Tile effective alpha %.2f)\n\n",
     (firstTile && effA > 0.9) ? @"YES" : @"NO - swipe to the connectivity page and wait", effA];

    [out appendString:@"=== GLASS STATUS (every glass on screen) ===\n"];
    NSMapTable *map = GlassToMat();
    for (UIView *g in [[map keyEnumerator] allObjects]) {
        UIView *mat = [map objectForKey:g];
        CGRect r = g.window ? WindowRect(g) : CGRectZero;
        if (!mat || !g.window || !CGRectIntersectsRect(r, scr)) continue;
        const char *reason = "";
        BOOL should = ShouldStyle(mat, &reason);
        NSMutableString *chain = [NSMutableString string];
        int i = 0;
        for (UIView *p = mat.superview; p && i < 5; p = p.superview, i++) {
            [chain appendFormat:@"%@%@", chain.length ? @" < " : @"", NSStringFromClass([p class])];
        }
        NSNumber *orig = objc_getAssociatedObject(mat, kOrigAlphaKey);
        [out appendFormat:@"rect=(%.0f,%.0f %.0fx%.0f) hidden=%d alpha=%.2f dup=%d overlap=%d | mat alpha=%.2f hidden=%d orig=%@ zeroed=%d shown=%d shouldStyle=%d(%s) oversized=%d | %@ in %@\n",
         r.origin.x, r.origin.y, r.size.width, r.size.height,
         g.hidden, g.alpha,
         [objc_getAssociatedObject(g, kDupKey) boolValue],
         [objc_getAssociatedObject(g, kOverlapKey) boolValue],
         mat.alpha, mat.hidden,
         orig ?: @"-",
         objc_getAssociatedObject(mat, kZeroedKey) != nil,
         ModuleShown(mat),
         should, reason,
         FocusOversized(mat),
         NSStringFromClass([mat class]), chain];
    }

    [out appendString:@"\n=== GHOST PROBE (layers hugging a module; the plate behind the pill is one of these) ===\n"];
    int wideCount = 0;
    int sqCount   = 0;
    for (UIView *g in [[map keyEnumerator] allObjects]) {
        if (!g.window || g.hidden) continue;
        CGRect r = WindowRect(g);
        if (!CGRectIntersectsRect(r, scr)) continue;
        UIView *mat = [map objectForKey:g];
        const char *reason = "";
        if (!mat || !ShouldStyle(mat, &reason) || !ModuleShown(mat)) continue;
        BOOL isWide = r.size.height >= 20.0 && (r.size.width / r.size.height) >= 2.2;
        BOOL isSq   = fabs(r.size.width - r.size.height) < 2.0 && r.size.width > 50.0 && r.size.width < 80.0;
        if (!((isWide && wideCount < 2) || (isSq && sqCount < 1))) continue;
        if (isWide) wideCount++;
        else sqCount++;
        [out appendFormat:@"module glass rect=(%.0f,%.0f %.0fx%.0f)\n", r.origin.x, r.origin.y, r.size.width, r.size.height];
        int cnt = 0;
        ProbeLayers(out, win.layer, 1.0, 0, @"window", &cnt, r);
    }

    [out appendString:@"\n=== C18 CLASSES ===\n"];
    for (NSString *clsName in @[@"C18Tile", @"C18ConnectivityView", @"C18ButtonModuleView", @"C18NowPlayingView"]) {
        DumpClassInfo(out, clsName);
    }

    [out appendString:@"\n=== C18 TILES ON SCREEN (how Wi-Fi / Bluetooth / AirDrop are built) ===\n"];
    NSMutableArray *allTiles = [NSMutableArray array];
    FindTiles(win, allTiles, 0);
    for (UIView *t in allTiles) {
        [out appendString:@"TILE\n"];
        ProbeTile(out, t, 0);
    }

    [out appendFormat:@"\n=== LAST TAPS ON CONNECTIVITY (tap Wi-Fi, Bluetooth and AirDrop, then open the dump again) ===\n%@\n",
     gTapLog ?: @"(none yet)"];

    [out appendString:@"\n=== PILL-SHAPED PAINTERS ===\n"];
    DumpPainters(out, win, 1.0, @"window", 0);

    [out writeToFile:@"/var/mobile/Library/Caches/cc18glass-dump.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[CC18Glass] dump written (%lu chars)", (unsigned long)out.length);
}

static void ScanConflicts(void) {
    static BOOL done = NO;
    if (done) return;
    done = YES;

    Dl_info selfInfo;
    NSString *selfPath = (dladdr((void *)ScanConflicts, &selfInfo) && selfInfo.dli_fname)
        ? [NSString stringWithUTF8String:selfInfo.dli_fname]
        : @"";

    NSArray *classes = @[
        @"CCUIModularControlCenterOverlayViewController",
        @"CCUIContentModuleContainerView",
        @"CCUIContentModuleContentContainerView",
        @"CCUIButtonModuleView",
        @"CCUIRoundButton",
        @"CCUIContinuousSliderView",
        @"CCUIScrollView",
        @"CCUIHeaderPocketView",
        @"CCUIStatusBar",
        @"CCUIConnectivityModuleViewController",
        @"CCUIMenuModuleViewController",
        @"MRUControlCenterView",
        @"FCUIActivityControl",
        @"FCUIActivityListView",
        @"MTMaterialView",
        @"SBControlCenterController",
        @"SBControlCenterWindow"
    ];

    NSMutableDictionary<NSString *, NSNumber *> *hits = [NSMutableDictionary dictionary];

    for (NSString *clsName in classes) {
        Class cls = NSClassFromString(clsName);
        const char *img = cls ? class_getImageName(cls) : NULL;
        if (!img) continue;
        NSString *imgPath = [NSString stringWithUTF8String:img];
        if (![imgPath hasPrefix:@"/System/"] && ![imgPath hasPrefix:@"/usr/lib/"] && ![imgPath hasPrefix:@"/Developer/"]) {
            continue;
        }
        for (int meta = 0; meta < 2; meta++) {
            Class targetCls = (meta == 0) ? cls : object_getClass(cls);
            unsigned int count = 0;
            Method *methods = class_copyMethodList(targetCls, &count);
            for (unsigned int i = 0; i < count; i++) {
                Dl_info info;
                if (!dladdr((void *)method_getImplementation(methods[i]), &info) || !info.dli_fname) continue;
                NSString *path = [NSString stringWithUTF8String:info.dli_fname];
                if (![path containsString:@"DynamicLibraries"] &&
                    ![path containsString:@"TweakInject"] &&
                    ![path containsString:@"MobileSubstrate"]) {
                    continue;
                }
                if ([path isEqualToString:selfPath]) continue;
                NSString *tweak = [[path lastPathComponent] stringByDeletingPathExtension];
                if ([[tweak lowercaseString] containsString:@"c18"] || [[tweak lowercaseString] containsString:@"cc18"]) {
                    continue;
                }
                hits[tweak] = @([hits[tweak] integerValue] + 1);
            }
            free(methods);
        }
    }

    NSMutableArray *list = [NSMutableArray array];
    for (NSString *k in [[hits allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        [list addObject:[NSString stringWithFormat:@"%@ (%@ hooks)", k, hits[k]]];
    }

    CFPreferencesSetAppValue(CFSTR("conflicts"), (__bridge CFPropertyListRef)list, CFSTR("com.cc18glass.prefs"));
    CFPreferencesSetAppValue(CFSTR("conflictsChecked"), kCFBooleanTrue, CFSTR("com.cc18glass.prefs"));
    CFPreferencesAppSynchronize(CFSTR("com.cc18glass.prefs"));
    NSLog(@"[CC18Glass] conflicts: %@", list);
}

// ============================================================================
// Logos Hooks (Ungrouped)
// ============================================================================

%hook MTMaterialView

- (void)didMoveToWindow {
    %orig;
    if (self.window && InCCWindow(self)) {
        ApplyGlass(self);
        PopWhenAppearing(self);
        KillExpandFade(self);
    }
}

- (void)layoutSubviews {
    %orig;
    if (self.window && InCCWindow(self)) {
        ApplyGlass(self);
    }
}

- (void)setFrame:(CGRect)frame {
    %orig;
    ResyncGeometry(self);
}

- (void)setBounds:(CGRect)bounds {
    %orig;
    ResyncGeometry(self);
}

- (void)setCenter:(CGPoint)center {
    %orig;
    ResyncGeometry(self);
}

- (void)setTransform:(CGAffineTransform)transform {
    %orig;
    ResyncGeometry(self);
}

- (void)setAlpha:(CGFloat)alpha {
    if (!gInternal && objc_getAssociatedObject(self, kZeroedKey)) {
        objc_setAssociatedObject(self, kOrigAlphaKey, @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(HiddenAlpha(self));
        SyncGlass(self);
        return;
    }
    %orig;
    if (objc_getAssociatedObject(self, kStyledKey)) {
        SyncGlass(self);
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    if (objc_getAssociatedObject(self, kStyledKey)) {
        SyncGlass(self);
    }
}

%end

%hook CALayer

- (void)setFilters:(NSArray *)filters {
    if (gEnabled && filters.count && IsFocusOrPageLayer(self)) {
        NSMutableArray *clean = [NSMutableArray array];
        for (id f in filters) {
            @try {
                if (![[f valueForKey:@"type"] isEqualToString:@"gaussianBlur"]) {
                    [clean addObject:f];
                }
            } @catch (NSException *e) {
            }
        }
        %orig(clean.count ? clean : nil);
        return;
    }
    %orig;
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    %orig;
    if (!gTouchOn || !gEnabled) return;
    if (event.type != UIEventTypeTouches) return;
    if (![NSStringFromClass([self class]) hasPrefix:@"SBControlCenter"]) return;
    UITouch *touch = [[event allTouches] anyObject];
    if (!touch) return;
    CGPoint pt = [touch locationInView:nil];
    UITouchPhase phase = touch.phase;
    if (phase == UITouchPhaseBegan) {
        gTouchGlass = GlassUnder(pt);
        if (gTouchGlass) {
            TouchMove(gTouchGlass, pt, YES);
        }
    } else if (phase == UITouchPhaseMoved) {
        if (gTouchGlass) {
            TouchMove(gTouchGlass, pt, NO);
        }
    } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        if (gTouchGlass) {
            TouchEnd(gTouchGlass);
            gTouchGlass = nil;
        }
    }
}

%end

%hook C18ConnectivityView

- (void)_itemTapped:(id)item {
    LogTap(@"_itemTapped:", item);
    %orig;
}

- (void)_presentListForItem:(id)item {
    LogTap(@"_presentListForItem:", item);
    %orig;
}

%end

// ============================================================================
// Logos Hooks (Grouped)
// ============================================================================

%group DylvGhost
%hook LGLiveBackdropView

- (void)setHidden:(BOOL)hidden {
    if (HasOurGlassNextToIt(self)) {
        %orig(YES);
        return;
    }
    %orig;
}

- (void)setAlpha:(CGFloat)alpha {
    if (HasOurGlassNextToIt(self)) {
        %orig(0.0);
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (HasOurGlassNextToIt(self) && (!self.hidden || self.alpha > 0.0)) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}

%end
%end

%group Weight
%hook MTMaterialView

- (void)setWeighting:(double)weighting {
    %orig;
    if (objc_getAssociatedObject(self, kBgModeKey)) {
        objc_setAssociatedObject(self, kWeightKey, @(weighting), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SyncGlass(self);
    }
}

%end
%end

%group PopOverlay
%hook CCUIModularControlCenterOverlayViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIView *v = self.view;
    dispatch_async(dispatch_get_main_queue(), ^{
        ReduceBackgroundBlur(v.window);
        [[CC18BlurKeeper shared] startForWindow:v.window];
        PopModulesIn(v);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DumpHorizontalModules();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ScanConflicts();
        });
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [[CC18BlurKeeper shared] stop];
}

%end
%end

%group FocusList
%hook FCUIActivityListView

- (void)layoutSubviews {
    %orig;
    StripFocusBlur(self);
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        StripFocusBlur(self);
    }
}

%end
%end

%group PopPager
%hook C18PageScrollView

- (void)setContentOffset:(CGPoint)offset {
    %orig;
    static CGFloat lastY = 0.0;
    CGFloat dy = offset.y - lastY;
    lastY = offset.y;
    CFTimeInterval now = CACurrentMediaTime();
    if (fabs(dy) > 6.0 && (now - gPagerLast) > 0.6 && !self.isTracking) {
        gPagerLast = now;
        int dir = dy > 0.0 ? 1 : -1;
        dispatch_async(dispatch_get_main_queue(), ^{
            PagerLiquid(self, dir, 20.0, 150.0);
        });
    }
}

%end
%end

// ============================================================================
// Constructor
// ============================================================================

%ctor {
    if (!NSClassFromString(@"MTMaterialView")) return;
    LoadPrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        PrefsChanged,
        CFSTR("com.cc18glass.prefs/reload"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    %init;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (NSClassFromString(@"LGLiveBackdropView")) {
            %init(DylvGhost);
            NSLog(@"[CC18Glass] dylv glass found, keeping it hidden next to our glass");
        }
        if (class_getInstanceMethod(NSClassFromString(@"MTMaterialView"), NSSelectorFromString(@"setWeighting:"))) {
            %init(Weight);
            NSLog(@"[CC18Glass] background follows the material weighting");
        }
        if (NSClassFromString(@"CCUIModularControlCenterOverlayViewController")) {
            %init(PopOverlay);
            NSLog(@"[CC18Glass] pop: hooked control center presentation");
        } else {
            NSLog(@"[CC18Glass] pop: CCUIModularControlCenterOverlayViewController not found");
        }
        if (NSClassFromString(@"FCUIActivityListView")) {
            %init(FocusList);
            NSLog(@"[CC18Glass] focus: list blur removed");
        }
        if (NSClassFromString(@"C18PageScrollView")) {
            %init(PopPager);
            NSLog(@"[CC18Glass] pop: hooked page scrolling");
        } else {
            NSLog(@"[CC18Glass] pop: C18PageScrollView not found");
        }
    });
}
