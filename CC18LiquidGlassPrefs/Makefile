THEOS_PACKAGE_SCHEME ?= roothide

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
	ARCHS = arm64e
else
	ARCHS = arm64 arm64e
endif

TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CC18LiquidGlassPrefs

CC18LiquidGlassPrefs_FILES = CC18LiquidGlassRootListController.m
CC18LiquidGlassPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics
CC18LiquidGlassPrefs_PRIVATE_FRAMEWORKS = Preferences
CC18LiquidGlassPrefs_INSTALL_PATH = /Library/PreferenceBundles
CC18LiquidGlassPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceLoader/Preferences/CC18LiquidGlass.plist$(ECHO_END)
