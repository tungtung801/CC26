#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "LGLiveBackdropView.h"
#import "LGSharedSupport.h"

NS_ASSUME_NONNULL_BEGIN

extern const void *kGlassKey;

typedef BOOL (^LGMaterialHostMatcher)(UIView *materialView);
typedef CGFloat (^LGMaterialHostCornerRadiusProvider)(UIView *materialView);
typedef void (^LGMaterialHostPostInstall)(UIView *materialView, UIView *glassView);

@interface LGGlassRec : NSObject
@property (nonatomic, copy) NSString *prefix;
@property (nonatomic, weak, nullable) UIView *glass;
@property (nonatomic, weak, nullable) UIView *material;
@end

@interface LGMaterialHostRoute : NSObject
@property (nonatomic, copy) NSString *prefix;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, copy) LGMaterialHostMatcher matcher;
@property (nonatomic, assign) UIEdgeInsets outset;
@property (nonatomic, copy, nullable) LGMaterialHostCornerRadiusProvider cornerRadiusProvider;
@property (nonatomic, copy, nullable) NSString *groupName;
@property (nonatomic, copy, nullable) LGMaterialHostPostInstall postInstall;
@end

BOOL hasAncestorOfClassName(UIView * _Nullable view, NSString * _Nullable className);
BOOL ancestorNameContains(UIView * _Nullable view, NSString * _Nullable substring);
BOOL isExactClass(id _Nullable obj, NSString * _Nullable className);

BOOL LGProcessMatchesExclusionList(id _Nullable exclusionList);
BOOL lgHostEnabled(NSString * _Nullable prefix);

void lgObservePreferenceReload(void (^ _Nullable handler)(void));
void lgTrackGlass(UIView * _Nullable glass, NSString * _Nullable prefix, UIView * _Nullable material);
void lgSuppressStock(UIView * _Nullable view, NSString * _Nullable prefix, BOOL hideNow);

LGLiveBackdropView * _Nullable LGCreateRegisteredGlass(CGRect frame,
                                                       NSString * _Nullable groupName,
                                                       NSString * _Nullable prefix);

UIView * _Nullable LGInstallRegisteredGlassInMaterial(UIView * _Nullable materialView,
                                                      const void * _Nullable assocKey,
                                                      NSString * _Nullable prefix,
                                                      UIEdgeInsets outset,
                                                      CGFloat cornerRadius,
                                                      NSString * _Nullable groupName);

void LGRegisterMaterialHost(NSString * _Nullable prefix,
                            NSInteger priority,
                            LGMaterialHostMatcher _Nullable matcher,
                            UIEdgeInsets outset,
                            LGMaterialHostCornerRadiusProvider _Nullable cornerRadiusProvider,
                            NSString * _Nullable groupName,
                            LGMaterialHostPostInstall _Nullable postInstall);

NS_ASSUME_NONNULL_END
