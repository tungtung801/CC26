#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@class LGLiveBackdropView;

@interface LGAdjustableBlurView : UIView

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat blurRadius;
@property (nonatomic, assign) CGFloat qualityScale;
@property (nonatomic, assign) BOOL capturesAppIcon;

- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)blurRadius;
- (void)applyFilters;

@end

@interface LGSpecularHighlightView : UIView

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGFloat topSpecularOpacity;
@property (nonatomic, assign) CGFloat bottomSpecularOpacity;

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)cornerRadius;

@end

@interface LGButtonView : UIControl

@property (nonatomic, strong) UIView *backgroundContainer;
@property (nonatomic, strong) LGAdjustableBlurView *blurView;
@property (nonatomic, strong) LGLiveBackdropView *lgView;
@property (nonatomic, strong) UIView *darkTintView;
@property (nonatomic, strong) UIImageView *innerGlowView;
@property (nonatomic, strong) CAGradientLayer *specularRimLayer;
@property (nonatomic, strong) CAShapeLayer *specularMaskLayer;
@property (nonatomic, strong, nullable) UIImageView *glyphImageView;
@property (nonatomic, strong, nullable) UILabel *titleLabel;
@property (nonatomic, assign) BOOL isPressed;
@property (nonatomic, assign) CGPoint touchStartPoint;
@property (nonatomic, copy, nullable) void (^actionHandler)(void);
@property (nonatomic, weak, nullable) UINavigationController *navigationController;
@property (nonatomic, strong, nullable) UIMenu *primaryMenu;
@property (nonatomic, strong, nullable) UIButton *menuAnchorButton;

- (instancetype)initWithFrame:(CGRect)frame symbolName:(NSString *)symbolName blurRadius:(CGFloat)blurRadius;
- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title blurRadius:(CGFloat)blurRadius;
- (void)updateLayoutWithFrame:(CGRect)frame;
- (void)refreshGlass;
- (void)unclipHierarchy;
- (void)presentMenu;

@end

@interface LGLiquidBlockerGesture : UIGestureRecognizer <UIGestureRecognizerDelegate>

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
