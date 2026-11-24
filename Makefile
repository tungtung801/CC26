THEOS_PACKAGE_SCHEME ?= roothide

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
	ARCHS = arm64e
else
	ARCHS = arm64 arm64e
endif

TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CC18LiquidGlass

# NOTE: Shared/*.m and Shared/LGGlassKit.x are intentionally excluded from compilation.
# Tweak.x renders its own Liquid Glass layers independently; compiling Shared/ caused
# duplicate ObjC class collisions (LGLiveBackdropView, etc.) and double-hooking of
# MTMaterialView with dylv.liquidass, leading to SpringBoard SafeMode crashes.
CC18LiquidGlass_FILES = Tweak.x
CC18LiquidGlass_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
CC18LiquidGlass_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics

SUBPROJECTS += CC18LiquidGlassPrefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
