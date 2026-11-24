#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGLiveBackdropView : UIView

@property (nonatomic, copy, nullable) NSString *lgFilterType;
@property (nonatomic, copy, nullable) NSNumber *lgSpecularEnabledOverride;
@property (nonatomic, assign) CGRect lgShapeRect;
@property (nonatomic, assign) CGFloat lgShapeCornerRadius;
@property (nonatomic, assign) CGFloat lgBackdropZoom;

- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame groupName:(nullable NSString *)groupName;
- (instancetype)initWithFrame:(CGRect)frame
                    groupName:(nullable NSString *)groupName
                   filterType:(nullable NSString *)filterType;

- (NSString *)lgEffectiveFilterType;
- (void)updateNativeBlurOverlayWithRadius:(CGFloat)radius;
- (void)updateSpecular;
- (void)applySpecularAngle:(double)angle;
- (void)applyFilters;
- (void)reapplyFilterForParameterReload;
- (void)lgInvalidateFilterContents;
- (BOOL)lgFilterAttached;

@end

#ifdef __cplusplus
extern "C" {
#endif

id _Nullable LGGlassPreferenceValue(NSString * _Nullable key);
void LGInvalidateGlassPreferenceCache(void);
NSString * _Nullable LGFilterTypeForHostPrefix(NSString * _Nullable prefix);

void LGInjectGlassIntoMaterialGroupType(UIView * _Nullable material,
                                        const void *assocKey,
                                        UIEdgeInsets outset,
                                        CGFloat cornerRadius,
                                        NSString * _Nullable groupName,
                                        NSString * _Nullable filterType);
void LGResyncGlassGeometry(UIView * _Nullable material, const void *assocKey);
void LGRemoveGlassFromMaterial(UIView * _Nullable material, const void *assocKey);
BOOL LGMaterialHasGlass(UIView * _Nullable material, const void *assocKey);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
