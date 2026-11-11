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

// Log chẩn đoán xem BTLog.h; cài đặt BTSettings.h; từ điển và quyết định khôi phục BTDictionary.h; Telex đơn giản BTTelex.h.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <unistd.h>
#include "BTLog.h"
#include "BTSettings.h"
#include "BTDictionary.h"
#include "BTTelex.h"
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
// nên lúc đó không kiểm tra khứ hồi được. Đọc thẳng ivar m_compositionDisabled bằng MSHookIvar (chỉ khi ivar có thật, kiểu BOOL).
static BOOL gBTHasCompositionIvar;

// Chạy Unikey trên chuỗi phím, bỏ qua compositionDisabled vì decomposeTelex: chỉ được gọi khi đang compose.
static NSString *BTCompose(TIKeyboardInputManager_vi *im, NSString *internal) {
	if (gBTHasIgnoreVariant)
		return [im internalStringToExternal:internal ignoreCompositionDisabled:YES];
	return [im internalStringToExternal:internal];
}

// BTCompose có cho ra đúng kết quả Unikey không. Không chắc thì trả NO để tweak không can thiệp.
// Định nghĩa nằm sau %hook đầu tiên vì Logos chỉ chèn <substrate.h> (MSHookIvar) từ chỗ đó.
static BOOL BTCanCompose(TIKeyboardInputManager_vi *im);

#pragma mark - Khôi phục từ không phải tiếng Việt

// Đã kiểm chứng trên máy iOS 17; RE iOS 16.3 giống hệt. iOS 15 bật thử (chưa RE, chưa test): nếu addInput: ghi đè
// cờ thì chỉ là không khôi phục. iOS 14 trở xuống hoặc thiếu method thì tắt.
static BOOL gBTCanRestore;

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

	// Chọn sẵn chữ cũ rồi gõ đè (vd chọn URL trong thanh địa chỉ Safari) làm iOS đồng bộ lại và dựng chuỗi phím
	// của "ư" thành "uw". Gõ "w" lần nữa ra "uww" -> "uw" thay vì "w". "w" cũng cho "ư" và là phím người dùng thật sự đã bấm.
	if (external.length == 1 && internal.length == 2) {
		unichar e = [external characterAtIndex:0];
		if ((e == 0x01B0 || e == 0x01AF) && [internal caseInsensitiveCompare:@"uw"] == NSOrderedSame) {
			NSString *key = e == 0x01B0 ? @"w" : @"W";
			if ([BTCompose(self, key) isEqualToString:external])
				return key;
		}
	}

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
		NSUInteger dictCount = BTSyllableCount();
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

static BOOL BTCanCompose(TIKeyboardInputManager_vi *im) {
	if (gBTHasIgnoreVariant)
		return YES;
	if (!gBTHasCompositionIvar)
		return NO;
	return !MSHookIvar<BOOL>(im, "m_compositionDisabled");
}

// Hook biến thể ignoreCompositionDisabled: nên chỉ khởi tạo khi method này có (iOS 15+); iOS 14 không có Telex đơn giản.
// Biến thể không có ignore trên iOS 15+ cũng gọi qua đây. Khi compositionDisabled đang bật (iOS cần chuỗi phím gốc,
// vd lúc khôi phục) thì không được sửa.
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
		// MSHookIvar không báo lỗi khi thiếu ivar nên kiểm tra trước; chỉ tin ivar đúng kiểu BOOL ("B" hoặc "c").
		Ivar ivar = class_getInstanceVariable(cls, "m_compositionDisabled");
		const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
		gBTHasCompositionIvar = type && (strcmp(type, "B") == 0 || strcmp(type, "c") == 0);
	}

	BOOL hasCompositionFlag = class_getInstanceMethod(cls, @selector(compositionDisabled))
		&& class_getInstanceMethod(cls, @selector(setCompositionDisabled:));
	if (@available(iOS 15.0, *))
		gBTCanRestore = hasCompositionFlag && class_getInstanceMethod(cls, @selector(inputString));
	BOOL canSimpleTelex = gBTHasIgnoreVariant && hasCompositionFlag
		&& class_getInstanceMethod(cls, @selector(vietnameseType));

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, BTPrefsChanged,
		CFSTR(BT_PREFS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	if (gBTCanRestore)
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
			BTLoadSyllables();
		});

	%init;
	if (canSimpleTelex)
		%init(BTSimpleTelex);

	BTLogf(@"hooks installed (canRestore=%d, canSimpleTelex=%d)", gBTCanRestore, canSimpleTelex);
}
