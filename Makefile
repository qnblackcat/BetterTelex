TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = kbd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterTelex

BetterTelex_FILES = Tweak.xm BTLog.mm BTSettings.mm BTDictionary.mm BTTelex.mm
BetterTelex_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += bettertelexprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
