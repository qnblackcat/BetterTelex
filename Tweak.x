// BetterTelex — sửa lỗi Telex của bàn phím tiếng Việt iOS.
//
// TIKeyboardInputManager_vi (TextInput_vi.bundle, chạy trong daemon kbd) giữ 2 dạng chuỗi:
//   - internal: chuỗi phím đã bấm, vd "wwhat"
//   - external: chữ hiển thị, = internalStringToExternal(internal) qua Unikey, vd "what"
//
// 1. Gõ lại vào từ đã chốt: iOS dựng lại internal từ chữ hiển thị bằng decomposeTelex:, vốn không phải hàm
//    ngược của Unikey ("what" -> "what" -> Unikey ra "ưhat"). Hook decomposeTelex: dựng lại từng ký tự,
//    dùng phím thoát của Telex (gõ đúp, vd "ww" -> "w") cho ký tự bị Unikey biến đổi ngoài ý muốn.
// 2. Khôi phục từ không phải tiếng Việt (iOS 15+): Unikey của iOS đã tự bỏ qua từ sai luật ghép vần ("inters"),
//    nhưng "does" vẫn ra "doé". Khi chốt từ bằng " ", "," hoặc ".", từ có dấu mà không có trong từ điển thì bật
//    compositionDisabled trước khi iOS chốt: internalStringToExternal: trả nguyên chuỗi phím, iOS tự thay "é" bằng "es".
// 3. Telex đơn giản: "w" đứng một mình giữ là "w".
//
// Log chẩn đoán (BTLogf) chỉ ghi khi bật Cài đặt → BetterTelex → Debug → Ghi log chẩn đoán,
// ra cả os_log (subsystem com.qn.bettertelex) lẫn file BT_LOG_PATH.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <os/lock.h>
#import <os/log.h>
#import <unistd.h>
#include <roothide.h>
#include "BTPrefs.h"

@interface TIKeyboardInputManager_vi : NSObject
- (NSString *)decomposeTelex:(NSString *)external;
- (NSString *)internalStringToExternal:(NSString *)internal;
- (NSString *)internalStringToExternal:(NSString *)internal ignoreCompositionDisabled:(BOOL)ignore;
// Kế thừa từ TIKeyboardInputManager. inputString là chữ hiển thị của từ đang gõ, vd "doé".
- (NSString *)inputString;
- (BOOL)compositionDisabled;
- (void)setCompositionDisabled:(BOOL)disabled;
// 0 = Telex; lớp con VNI trả 2, VIQR trả 3.
- (int)vietnameseType;
@end

#pragma mark - Cài đặt

// Cờ BOOL đọc thẳng không qua khoá (đọc lệch một nhịp lúc đổi cài đặt cũng không sao);
// khoá chỉ giữ cho các NSSet được thay trên hàng đợi nền.
static BOOL gBTEnabled = YES;
static BOOL gBTRestoreEnabled = YES;
static BOOL gBTSimpleTelex;
static BOOL gBTDebugLog;
static os_unfair_lock gBTLock = OS_UNFAIR_LOCK_INIT;
// Từ điển cá nhân, chữ thường NFC: không bao giờ khôi phục.
static NSSet<NSString *> *gBTUserWords;
// Âm tiết tiếng Việt, chữ thường NFC. nil khi chưa nạp xong: lúc đó không khôi phục gì.
static NSSet<NSString *> *gBTSyllables;

#pragma mark - Log chẩn đoán

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

// Tắt debug thì không dựng chuỗi, không ghi gì.
#define BTLogf(fmt, ...) do { \
	if (!gBTDebugLog) \
		break; \
	NSString *_m = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; \
	os_log(BTLog(), "[BetterTelex] %{public}@", _m); \
	BTLogToFile(_m); \
} while (0)

#pragma mark - Nạp cài đặt và từ điển

static BOOL BTBool(NSDictionary *prefs, NSString *key, BOOL fallback) {
	id value = prefs[key];
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static void BTLoadPrefs(void) {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:jbroot(BT_PREFS_PATH)];
	// Đặt trước dòng log bên dưới để lần bật công tắc cũng được ghi lại.
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

static void BTPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		BTLoadPrefs();
	});
}

// hunspell-vi (GPLv2, cài qua layout/) gộp dấu mới (hoà) lẫn dấu cũ (hóa), cộng danh sách bổ sung vi-BetterTelex.dic
// (từ hunspell thiếu như "quí", "ừm"; không có dòng đếm, "#" là chú thích).
static void BTLoadSyllables(void) {
	NSString *directory = @"/Library/Application Support/BetterTelex";
	NSMutableSet<NSString *> *syllables = [NSMutableSet setWithCapacity:8192];
	for (NSString *name in @[@"vi-DauMoi.dic", @"vi-DauCu.dic", @"vi-BetterTelex.dic"]) {
		NSString *path = jbroot([directory stringByAppendingPathComponent:name]);
		NSError *error = nil;
		NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		if (!content) {
			BTLogf(@"không đọc được từ điển %@: %@", path, error);
			continue;
		}
		// Dòng đầu của file .dic hunspell là số từ; các dòng sau dạng "từ" hoặc "từ/cờ affix".
		__block BOOL header = ![name isEqualToString:@"vi-BetterTelex.dic"];
		[content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
			if (header) {
				header = NO;
				return;
			}
			if ([line hasPrefix:@"#"])
				return;
			NSString *word = [[line componentsSeparatedByString:@"/"].firstObject
				stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			if (word.length)
				[syllables addObject:word.lowercaseString.precomposedStringWithCanonicalMapping];
		}];
	}
	BTLogf(@"nạp từ điển: %lu âm tiết", (unsigned long)syllables.count);
	if (syllables.count == 0)
		return;
	NSSet<NSString *> *loaded = [syllables copy];
	os_unfair_lock_lock(&gBTLock);
	gBTSyllables = loaded;
	os_unfair_lock_unlock(&gBTLock);
}

#pragma mark - Dựng lại chuỗi phím

// Từ dài hơn mức này thì bỏ qua, giữ nguyên hành vi gốc (thuật toán dựng lại là O(n^2) lần gọi Unikey).
static const NSUInteger kBTMaxWordLength = 48;

// Phím đang xử lý trong addInput:. iOS cũng chuyển chính phím vừa bấm qua decomposeTelex:,
// mà phím bấm luôn là phím Telex thật — không được biến nó thành phím thoát ("w" -> "ww").
static NSString *gBTTypingKey;

// Đang trong deleteFromInput:. Khi xoá giữa lúc gõ, iOS đổi chữ cuối cùng ngược ra phím qua decomposeTelex: rồi
// xoá đúng chừng ấy phím (RE iOS 17.1). "w" dựng lại thành "ww" sẽ làm xoá 2 chữ một lúc, nên giữ kết quả gốc.
static BOOL gBTDeleting;

// iOS 14 chỉ có internalStringToExternal:, các bản mới hơn có thêm biến thể ignoreCompositionDisabled:.
static BOOL gBTHasIgnoreVariant;

// iOS 14 (experimental): internalStringToExternal: trả nguyên chuỗi phím khi compositionDisabled bật,
// nên lúc đó không kiểm tra khứ hồi được. Đọc thẳng ivar m_compositionDisabled; -1 = không đọc được.
static ptrdiff_t gBTCompositionDisabledOffset = -1;

// Chạy Unikey trên chuỗi phím, bỏ qua compositionDisabled vì decomposeTelex: chỉ được gọi khi đang compose.
static NSString *BTCompose(TIKeyboardInputManager_vi *im, NSString *internal) {
	if (gBTHasIgnoreVariant)
		return [im internalStringToExternal:internal ignoreCompositionDisabled:YES];
	return [im internalStringToExternal:internal];
}

// BTCompose có cho ra đúng kết quả Unikey không. Không chắc thì trả NO để tweak không can thiệp.
static BOOL BTCanCompose(TIKeyboardInputManager_vi *im) {
	if (gBTHasIgnoreVariant)
		return YES;
	if (gBTCompositionDisabledOffset < 0)
		return NO;
	return !*(BOOL *)((uint8_t *)(__bridge void *)im + gBTCompositionDisabledOffset);
}

#pragma mark - Telex đơn giản

// Unikey của iOS không có Telex đơn giản (RE iOS 17.1: UnikeySetInputMethod(5) rơi về Telex thường), nên sửa chuỗi
// phím trước khi đưa vào Unikey: "w" đầu tiên của từ mà trước nó chưa có a/o/u được nhân đôi thành phím thoát "ww".
// Chỉ nhân đôi một lần vì sau một lần thoát Unikey để nguyên phần còn lại của từ: "what" -> "wwhat" -> "what",
// "ww" -> "www" -> "ww". Sau a/o/u thì giữ nguyên: "uw" -> "ư", "tranw" -> "trăn".
static NSString *BTSimpleTelexKeys(NSString *internal) {
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

#pragma mark - Khôi phục từ không phải tiếng Việt

// Đã kiểm chứng trên máy iOS 17; RE iOS 16.3 giống hệt. iOS 15 bật thử (chưa RE, chưa test): nếu addInput: ghi đè
// cờ thì chỉ là không khôi phục. iOS 14 trở xuống hoặc thiếu method thì tắt.
static BOOL gBTCanRestore;

// Phím chốt từ, giống XKey.
static BOOL BTIsWordSeparator(NSString *input) {
	return [input isEqualToString:@" "] || [input isEqualToString:@","] || [input isEqualToString:@"."];
}

// Từ vừa gõ (chữ hiển thị) có phải trả về phím gốc không.
static BOOL BTShouldRestore(NSString *word) {
	if (!gBTEnabled || !gBTRestoreEnabled || word.length < 2)
		return NO;
	os_unfair_lock_lock(&gBTLock);
	NSSet<NSString *> *syllables = gBTSyllables;
	NSSet<NSString *> *userWords = gBTUserWords;
	os_unfair_lock_unlock(&gBTLock);
	if (!syllables)
		return NO;

	NSString *nfc = word.precomposedStringWithCanonicalMapping;
	NSCharacterSet *letters = NSCharacterSet.letterCharacterSet;
	BOOL marked = NO;
	for (NSUInteger i = 0; i < nfc.length; i++) {
		unichar c = [nfc characterAtIndex:i];
		// Có số hay ký hiệu thì không phải một âm tiết đang gõ: không đoán.
		if (![letters characterIsMember:c])
			return NO;
		if (c > 0x7F)
			marked = YES;
	}
	// Không có dấu: Unikey chưa biến đổi gì, không có gì để trả về.
	if (!marked)
		return NO;
	NSString *lower = nfc.lowercaseString;
	// Không có nguyên âm thì chỉ có thể là "dd" -> "đ" trong viết tắt (đk, đm, HĐ, ĐHQG): giữ nguyên.
	static NSCharacterSet *vowels;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		vowels = [NSCharacterSet characterSetWithCharactersInString:@"aeiouy"];
	});
	NSString *folded = [lower stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:nil];
	if ([folded rangeOfCharacterFromSet:vowels].location == NSNotFound)
		return NO;
	return ![syllables containsObject:lower] && ![userWords containsObject:lower];
}

%hook TIKeyboardInputManager_vi

- (NSString *)decomposeTelex:(NSString *)external {
	NSString *internal = %orig;
	BTLogf(@"decomposeTelex: %@ -> %@", external, internal);
	if (!internal || external.length == 0 || external.length > kBTMaxWordLength || !gBTEnabled)
		return internal;

	// Đang chuyển phím vừa bấm, không phải dựng lại từ đã chốt: giữ hành vi gốc.
	if (gBTTypingKey && [external isEqualToString:gBTTypingKey])
		return internal;

	// Phím xoá hỏi về đúng một chữ (xem gBTDeleting): giữ hành vi gốc để xoá một chữ là một phím.
	if (gBTDeleting && [external rangeOfComposedCharacterSequenceAtIndex:0].length == external.length)
		return internal;

	// iOS 14: đang compositionDisabled (hoặc không đọc được cờ) thì không kiểm tra được, giữ hành vi gốc.
	if (!BTCanCompose(self))
		return internal;

	// Từ tiếng Việt bình thường ("việt" <-> "vieejt") đi khứ hồi đúng: giữ nguyên để vẫn sửa dấu được.
	if ([BTCompose(self, internal) isEqualToString:external])
		return internal;

	// Dựng lại từng ký tự, mỗi bước kiểm tra Unikey(built) == phần đầu của chữ hiển thị.
	NSMutableString *built = [NSMutableString string];
	NSUInteger i = 0;
	while (i < external.length) {
		NSRange r = [external rangeOfComposedCharacterSequenceAtIndex:i];
		NSString *ch = [external substringWithRange:r];
		NSString *target = [external substringToIndex:NSMaxRange(r)];
		NSString *decomposed = %orig(ch) ?: ch;

		// Ứng viên theo thứ tự: phím Telex của ký tự -> chính ký tự đó (bỏ qua nếu trùng) -> gõ đúp để thoát ("w" -> "ww").
		NSString *picked = nil;
		for (int k = 0; k < 3 && !picked; k++) {
			if (k == 1 && [ch isEqualToString:decomposed])
				continue;
			NSString *candidate = k == 0 ? decomposed : k == 1 ? ch : [ch stringByAppendingString:ch];
			if ([BTCompose(self, [built stringByAppendingString:candidate]) isEqualToString:target])
				picked = candidate;
		}
		// Không dựng được thì trả về kết quả gốc, coi như không can thiệp.
		if (!picked) {
			BTLogf(@"giveup external=%@ orig=%@ at=%lu", external, internal, (unsigned long)i);
			return internal;
		}
		[built appendString:picked];
		i = NSMaxRange(r);
	}

	BTLogf(@"fixed external=%@ orig=%@ new=%@", external, internal, built);
	return built;
}

- (NSString *)addInput:(NSString *)input flags:(unsigned int)flags point:(CGPoint)point firstDelete:(unsigned long long *)firstDelete {
	NSString *previousKey = gBTTypingKey;
	gBTTypingKey = input;

	// compositionDisabled đã bật nghĩa là đang sửa giữa từ: iOS đã giữ nguyên phím gốc, không đụng vào.
	BOOL separator = gBTCanRestore && BTIsWordSeparator(input);
	BOOL restore = separator && ![self compositionDisabled] && BTShouldRestore([self inputString]);
	if (separator && gBTDebugLog) {
		os_unfair_lock_lock(&gBTLock);
		NSUInteger dictCount = gBTSyllables.count;
		os_unfair_lock_unlock(&gBTLock);
		BTLogf(@"chốt từ bằng '%@': word=%@ disabled=%d dict=%lu -> restore=%d",
			input, [self inputString], [self compositionDisabled], (unsigned long)dictCount, restore);
	}
	if (restore)
		[self setCompositionDisabled:YES];

	NSString *result = %orig;

	// iOS chỉ tự tắt cờ sau " ": với "," và "." phải tự tắt để từ sau vẫn ghép dấu được.
	if (restore && [self compositionDisabled])
		[self setCompositionDisabled:NO];

	gBTTypingKey = previousKey;
	return result;
}

- (NSString *)deleteFromInput:(unsigned long long *)firstDelete {
	BOOL previous = gBTDeleting;
	gBTDeleting = YES;
	NSString *result = %orig;
	gBTDeleting = previous;
	return result;
}

%end

// Hook riêng vì iOS 14 không có biến thể ignoreCompositionDisabled:; trên iOS 15+ biến thể không có ignore cũng
// gọi qua đây. Khi compositionDisabled đang bật (iOS cần chuỗi phím gốc, vd lúc khôi phục) thì không được sửa.
%group BTSimpleTelex
%hook TIKeyboardInputManager_vi

- (NSString *)internalStringToExternal:(NSString *)internal ignoreCompositionDisabled:(BOOL)ignore {
	if (internal.length && gBTEnabled && gBTSimpleTelex && [self vietnameseType] == 0
		&& (ignore || ![self compositionDisabled]))
		return %orig(BTSimpleTelexKeys(internal), ignore);
	return %orig;
}

%end
%end

%ctor {
	// Nạp cài đặt trước (file nhỏ) để log khởi động biết công tắc Ghi log chẩn đoán.
	BTLoadPrefs();
	BTLogf(@"loaded into %@ (pid %d), %@", NSProcessInfo.processInfo.processName, getpid(),
		NSProcessInfo.processInfo.operatingSystemVersionString);

	// Bundle tiếng Việt bình thường chỉ được nạp khi người dùng chuyển sang bàn phím tiếng Việt.
	// Nạp sẵn để hook ngay; Unikey chỉ khởi tạo khi input manager thật sự được tạo nên gần như không tốn gì.
	dlopen("/System/Library/TextInput/TextInput_vi.bundle/TextInput_vi", RTLD_NOW);
	// Cần cả hai method (có từ iOS 14 đến ít nhất 18): thiếu addInput: thì không phân biệt được phím vừa bấm,
	// sửa decomposeTelex: một mình sẽ gây lỗi "w" -> "ww". Thiếu thì bỏ qua, giữ nguyên bàn phím gốc.
	Class cls = objc_getClass("TIKeyboardInputManager_vi");
	if (!cls || !class_getInstanceMethod(cls, @selector(decomposeTelex:))
		|| !class_getInstanceMethod(cls, @selector(addInput:flags:point:firstDelete:))) {
		BTLogf(@"không tìm thấy TIKeyboardInputManager_vi, decomposeTelex: hoặc addInput:…, chưa hook (dlerror: %s)", dlerror());
		return;
	}

	gBTHasIgnoreVariant = class_getInstanceMethod(cls, @selector(internalStringToExternal:ignoreCompositionDisabled:)) != NULL;
	if (!gBTHasIgnoreVariant) {
		// Chỉ tin ivar nếu đúng kiểu BOOL ("B" hoặc "c"), sai kiểu thì để -1: tweak không can thiệp.
		Ivar ivar = class_getInstanceVariable(cls, "m_compositionDisabled");
		const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
		if (type && (strcmp(type, "B") == 0 || strcmp(type, "c") == 0))
			gBTCompositionDisabledOffset = ivar_getOffset(ivar);
	}

	BOOL hasCompositionFlag = class_getInstanceMethod(cls, @selector(compositionDisabled))
		&& class_getInstanceMethod(cls, @selector(setCompositionDisabled:));
	if (@available(iOS 15.0, *))
		gBTCanRestore = hasCompositionFlag && class_getInstanceMethod(cls, @selector(inputString));
	BOOL canSimpleTelex = gBTHasIgnoreVariant && hasCompositionFlag
		&& class_getInstanceMethod(cls, @selector(vietnameseType));

	// Nạp lại cài đặt mỗi khi bundle cài đặt ghi file, không cần respring.
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, BTPrefsChanged,
		CFSTR(BT_PREFS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	// Đọc ~80KB và dựng set ~6.700 âm tiết ở nền để không chậm lúc kbd khởi động.
	if (gBTCanRestore)
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
			BTLoadSyllables();
		});

	%init;
	if (canSimpleTelex)
		%init(BTSimpleTelex);

	BTLogf(@"hooks installed (canRestore=%d, canSimpleTelex=%d)", gBTCanRestore, canSimpleTelex);
}
