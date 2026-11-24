#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

BOOL LGBackboardSafeModeActive(void);
void LGClearBackboardSafeMode(void);

NSString *LGMainBundleIdentifier(void);
BOOL LGIsSpringBoardProcess(void);
BOOL LGIsPreferencesProcess(void);
BOOL LGIsExcludedSystemProcess(void);
BOOL LGIsAtLeastiOS16(void);

NSString *LGRWBDefaultWidgetBundleIDsText(void);
CGFloat LGEffectiveBannerBlur(CGFloat blur);

void LGReloadPreferences(void);
void LGObservePreferenceChanges(dispatch_block_t handler);
BOOL LGHasExplicitPreferenceValue(NSString *key);
BOOL LG_prefBool(NSString *key, BOOL fallback);
CGFloat LG_prefFloat(NSString *key, CGFloat fallback);
NSInteger LG_prefInteger(NSString *key, NSInteger fallback);
NSString *LG_prefString(NSString *key, NSString *fallback);
BOOL LG_globalEnabled(void);

BOOL LGDebugLoggingEnabled(void);
void LGLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

CGColorSpaceRef LGSharedRGBColorSpace(void);
UIImage *LGNormalizedImageForUpload(UIImage *image);
NSNumber *LGTextureScaleKey(CGFloat scale);
NSNumber *LGBlurSettingKey(CGFloat blur);
NSString *LGImageStableCacheKey(UIImage *image);
void LGSetImageStableCacheKey(UIImage *image, NSString *cacheKey);

#ifdef __cplusplus
}
#endif
