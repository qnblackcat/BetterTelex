// Log chẩn đoán: chỉ ghi khi bật Cài đặt → BetterTelex → Debug → Ghi log chẩn đoán (BT_KEY_DEBUG_LOG),
// ra cả os_log (subsystem com.qn.bettertelex) lẫn file BT_LOG_PATH.

#import <Foundation/Foundation.h>

// Do BTLoadPrefs đặt. Mặc định NO: chưa đọc được cài đặt thì không ghi gì.
extern BOOL gBTDebugLog;

void BTLogMessage(NSString *message);

// Tắt debug thì không dựng chuỗi, không ghi gì.
#define BTLogf(fmt, ...) do { \
	if (!gBTDebugLog) \
		break; \
	BTLogMessage([NSString stringWithFormat:fmt, ##__VA_ARGS__]); \
} while (0)
