TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = kbd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterTelex

BetterTelex_FILES = Tweak.x
BetterTelex_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
