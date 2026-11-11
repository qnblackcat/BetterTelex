#include "BTTelex.h"

// Unikey của iOS không có Telex đơn giản (RE iOS 17.1: UnikeySetInputMethod(5) rơi về Telex thường), nên sửa chuỗi
// phím trước khi đưa vào Unikey: "w" đầu tiên của từ mà trước nó chưa có a/o/u được nhân đôi thành phím thoát "ww".
// Chỉ nhân đôi một lần vì sau một lần thoát Unikey để nguyên phần còn lại của từ: "what" -> "wwhat" -> "what",
// "ww" -> "www" -> "ww". Sau a/o/u thì giữ nguyên: "uw" -> "ư", "tranw" -> "trăn".
NSString *BTSimpleTelexKeys(NSString *internal) {
	NSUInteger length = internal.length;
	NSMutableString *keys = nil;
	BOOL hasAOU = NO, escaped = NO;
	NSCharacterSet *letters = NSCharacterSet.letterCharacterSet;
	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [internal characterAtIndex:i];
		if (![letters characterIsMember:c]) {
			hasAOU = NO;
			escaped = NO;
		} else if (c == 'w' || c == 'W') {
			if (!hasAOU && !escaped) {
				escaped = YES;
				// Chỉ tạo chuỗi mới khi thật sự phải sửa.
				if (!keys)
					keys = [[internal substringToIndex:i] mutableCopy];
				[keys appendFormat:@"%C", c];
			}
		} else if (c == 'a' || c == 'A' || c == 'o' || c == 'O' || c == 'u' || c == 'U') {
			hasAOU = YES;
		}
		[keys appendFormat:@"%C", c];
	}
	return keys ?: internal;
}
