ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WXTabHaptic

WXTabHaptic_FILES = Tweak.xm
WXTabHaptic_CFLAGS = -fobjc-arc -Wno-error=deprecated-declarations -Wno-error=unused-variable -Wno-error=unused-function
WXTabHaptic_FRAMEWORKS = UIKit Foundation AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
