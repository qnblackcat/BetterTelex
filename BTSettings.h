// Cài đặt của tweak, đọc từ BT_PREFS_PATH (xem BTPrefs.h).

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// Cờ BOOL đọc thẳng không qua khoá (đọc lệch một nhịp lúc đổi cài đặt cũng không sao).
extern BOOL gBTEnabled;
extern BOOL gBTRestoreEnabled;
extern BOOL gBTSimpleTelex;

// Nạp lại toàn bộ cài đặt (kể cả gBTDebugLog trong BTLog.h) và từ điển cá nhân.
void BTLoadPrefs(void);
// Callback Darwin notification BT_PREFS_CHANGED: nạp lại ở hàng đợi nền.
void BTPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
// Từ điển cá nhân, chữ thường NFC: không bao giờ khôi phục. Không bao giờ nil.
NSSet<NSString *> *BTUserWords(void);
