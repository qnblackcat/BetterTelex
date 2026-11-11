# "latest" chọn SDK của Xcode, không có private framework Preferences: dùng SDK 16.5 đã vá trong $(THEOS)/sdks.
TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

BT_VERSION := $(shell awk '/^Version:/ {print $$2}' ../control)

BUNDLE_NAME = BetterTelexPrefs
BetterTelexPrefs_FILES = BTPrefsStore.m BTRootListController.m BTUserWordsController.m
BetterTelexPrefs_INSTALL_PATH = /Library/PreferenceBundles
BetterTelexPrefs_FRAMEWORKS = UIKit UniformTypeIdentifiers
BetterTelexPrefs_PRIVATE_FRAMEWORKS = Preferences
BetterTelexPrefs_CFLAGS = -fobjc-arc -DBT_VERSION=\"$(BT_VERSION)\"

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BetterTelexPrefs.plist$(ECHO_END)
