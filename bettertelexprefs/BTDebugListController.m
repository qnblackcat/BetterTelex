#import "BTDebugListController.h"
#import <Preferences/PSSpecifier.h>
#import "../BTPrefs.h"
#include <roothide.h>

@implementation BTDebugListController

- (NSArray *)specifiers {
	if (!_specifiers)
		_specifiers = [self loadSpecifiersFromPlistName:@"Debug" target:self];
	return _specifiers;
}

// Gộp .old (nếu có) với file hiện tại thành một file .txt rồi chia sẻ.
- (void)shareLogTapped:(PSSpecifier *)specifier {
	NSMutableData *data = [NSMutableData data];
	for (NSString *path in @[jbroot(BT_LOG_OLD_PATH), jbroot(BT_LOG_PATH)]) {
		NSData *part = [NSData dataWithContentsOfFile:path];
		if (part)
			[data appendData:part];
	}
	if (data.length == 0) {
		[self showAlertWithTitle:@"Chưa có log"
			message:@"Bật \"Ghi log chẩn đoán\", gõ lại trường hợp bị lỗi rồi quay lại đây."];
		return;
	}

	[self shareData:data name:@"BetterTelex Log.txt"];
}

- (void)clearLogTapped:(PSSpecifier *)specifier {
	NSFileManager *fm = NSFileManager.defaultManager;
	[fm removeItemAtPath:jbroot(BT_LOG_PATH) error:NULL];
	[fm removeItemAtPath:jbroot(BT_LOG_OLD_PATH) error:NULL];
	[self showAlertWithTitle:@"Đã xoá file log" message:nil];
}

@end
