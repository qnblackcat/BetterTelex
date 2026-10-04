# arm64e build bằng Xcode 12+ chỉ chạy trên iOS 14+ (https://theos.dev/docs/arm64e-deployment)
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = kbd

# Kiểu jailbreak: roothide (mặc định), rootless hoặc rootful — vd `make package SCHEME=rootless`
SCHEME ?= roothide
ifneq ($(SCHEME),rootful)
THEOS_PACKAGE_SCHEME = $(SCHEME)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BetterTelex

BetterTelex_FILES = Tweak.x
BetterTelex_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
