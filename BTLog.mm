#import <os/log.h>
#include <roothide.h>
#include "BTLog.h"
#include "BTPrefs.h"

BOOL gBTDebugLog;

static os_log_t BTLog(void) {
	static os_log_t log;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		log = os_log_create("com.qn.bettertelex", "telex");
	});
	return log;
}

// Hàng đợi riêng giữ thứ tự và không chặn bàn phím. Mở-ghi-đóng mỗi dòng nên trang Debug xoá file lúc nào cũng được.
// Kiểm tra lại gBTDebugLog trong hàng đợi: tắt debug thì các dòng còn xếp hàng cũng không được ghi.
static void BTLogToFile(NSString *message) {
	static dispatch_queue_t queue;
	static NSDateFormatter *formatter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("com.qn.bettertelex.log", DISPATCH_QUEUE_SERIAL);
		formatter = [NSDateFormatter new];
		formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
		formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
	});
	NSDate *date = [NSDate date];
	dispatch_async(queue, ^{
		if (!gBTDebugLog)
			return;
		NSString *path = jbroot(BT_LOG_PATH);
		NSFileManager *fm = NSFileManager.defaultManager;
		if ([[fm attributesOfItemAtPath:path error:NULL] fileSize] >= BT_LOG_MAX_BYTES) {
			NSString *old = jbroot(BT_LOG_OLD_PATH);
			[fm removeItemAtPath:old error:NULL];
			[fm moveItemAtPath:path toPath:old error:NULL];
		}
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:date], message];
		NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
		if (!handle) {
			[fm createFileAtPath:path contents:data attributes:nil];
			return;
		}
		[handle seekToEndOfFile];
		[handle writeData:data];
		[handle closeFile];
	});
}

void BTLogMessage(NSString *message) {
	// Kiểm tra lần nữa cho trường hợp gọi thẳng, không qua BTLogf.
	if (!gBTDebugLog)
		return;
	os_log(BTLog(), "[BetterTelex] %{public}@", message);
	BTLogToFile(message);
}
