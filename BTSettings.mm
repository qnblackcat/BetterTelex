#import <os/lock.h>
#include <roothide.h>
#include "BTSettings.h"
#include "BTLog.h"
#include "BTPrefs.h"

BOOL gBTEnabled = YES;
BOOL gBTRestoreEnabled = YES;
BOOL gBTSimpleTelex;

// Khoá chỉ giữ cho NSSet được thay trên hàng đợi nền.
static os_unfair_lock gBTLock = OS_UNFAIR_LOCK_INIT;
static NSSet<NSString *> *gBTUserWords;

static BOOL BTBool(NSDictionary *prefs, NSString *key, BOOL fallback) {
	id value = prefs[key];
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

void BTLoadPrefs(void) {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:jbroot(BT_PREFS_PATH)];
	// Đặt trước dòng log bên dưới để lần bật công tắc cũng được ghi lại. Thiếu file/khoá thì tắt.
	gBTDebugLog = BTBool(prefs, BT_KEY_DEBUG_LOG, NO);
	gBTEnabled = BTBool(prefs, BT_KEY_ENABLED, YES);
	gBTRestoreEnabled = BTBool(prefs, BT_KEY_RESTORE_ENABLED, YES);
	gBTSimpleTelex = BTBool(prefs, BT_KEY_SIMPLE_TELEX, NO);

	NSMutableSet<NSString *> *userWords = [NSMutableSet set];
	id stored = prefs[BT_KEY_USER_WORDS];
	if ([stored isKindOfClass:NSArray.class]) {
		for (id word in stored) {
			if ([word isKindOfClass:NSString.class] && [word length])
				[userWords addObject:[word lowercaseString].precomposedStringWithCanonicalMapping];
		}
	}
	NSSet<NSString *> *words = [userWords copy];
	os_unfair_lock_lock(&gBTLock);
	gBTUserWords = words;
	os_unfair_lock_unlock(&gBTLock);

	BTLogf(@"nạp cài đặt: enabled=%d restoreEnabled=%d simpleTelex=%d, %lu từ cá nhân",
		gBTEnabled, gBTRestoreEnabled, gBTSimpleTelex, (unsigned long)words.count);
}

void BTPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		BTLoadPrefs();
	});
}

NSSet<NSString *> *BTUserWords(void) {
	os_unfair_lock_lock(&gBTLock);
	NSSet<NSString *> *words = gBTUserWords;
	os_unfair_lock_unlock(&gBTLock);
	return words ?: [NSSet set];
}
