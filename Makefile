TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = kbd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterTelex

BetterTelex_FILES = Tweak.x
BetterTelex_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
