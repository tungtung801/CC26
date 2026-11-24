THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:16.4:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CC18LiquidGlass

CC18LiquidGlass_FILES = Tweak.x \
	Shared/LGFramework.m \
	Shared/LGGlassKit.x \
	Shared/LGLiveBackdropView.m \
	Shared/LGSharedSupport.m
CC18LiquidGlass_CFLAGS = -fobjc-arc -IShared
CC18LiquidGlass_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics CoreText CoreMotion

SUBPROJECTS += CC18LiquidGlassPrefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
