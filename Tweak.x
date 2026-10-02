// BetterTelex — sửa lỗi Telex của bàn phím tiếng Việt iOS khi gõ lại vào một từ đã chốt.
//
// TIKeyboardInputManager_vi (TextInput_vi.bundle, chạy trong daemon kbd) giữ 2 dạng chuỗi:
//   - internal: chuỗi phím đã bấm, vd "wwhat"
//   - external: chữ hiển thị, = internalStringToExternal(internal) qua Unikey, vd "what"
// Khi con trỏ quay lại cuối một từ đã chốt (xoá dấu cách rồi gõ tiếp), iOS dựng lại internal
// từ chữ hiển thị bằng externalStringToInternal: -> decomposeTelex: (ICU transliterator).
// decomposeTelex không phải hàm ngược của Unikey: "what" -> "what" -> Unikey ra "ưhat".
//
// Cách sửa: hook decomposeTelex:, kiểm tra kết quả có ra lại đúng chữ hiển thị không.
// Nếu không, dựng lại chuỗi phím từng ký tự một, dùng phím thoát của Telex (gõ đúp, vd "ww" -> "w")
// cho những ký tự bị Unikey biến đổi ngoài ý muốn.
//
// DEBUG: code chẩn đoán được comment sẵn, mỗi khối đánh dấu [debug]. Bỏ "//" ở đầu các dòng
// trong mọi khối [debug] để bật lại. Log có tiền tố [BetterTelex], subsystem com.qn.bettertelex.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// [debug]
// #import <os/log.h>
//
// static os_log_t BTLog(void) {
// 	static os_log_t log;
// 	static dispatch_once_t once;
// 	dispatch_once(&once, ^{
// 		log = os_log_create("com.qn.bettertelex", "telex");
// 	});
// 	return log;
// }
//
// #define BTLogf(fmt, ...) do { \
// 	NSString *_m = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; \
// 	os_log(BTLog(), "%{public}@", _m); \
// 	NSLog(@"[BetterTelex] %@", _m); \
// } while (0)
// [/debug]

@interface TIKeyboardInputManager_vi : NSObject
- (NSString *)decomposeTelex:(NSString *)external;
- (NSString *)internalStringToExternal:(NSString *)internal;
- (NSString *)internalStringToExternal:(NSString *)internal ignoreCompositionDisabled:(BOOL)ignore;
@end

// Từ dài hơn mức này thì bỏ qua, giữ nguyên hành vi gốc (thuật toán dựng lại là O(n^2) lần gọi Unikey).
static const NSUInteger kBTMaxWordLength = 48;

// Phím đang được xử lý trong addInput:. iOS cũng chuyển chính phím vừa bấm qua decomposeTelex:,
// mà phím bấm luôn là phím Telex thật — không được biến nó thành phím thoát ("w" -> "ww").
static NSString *gBTTypingKey;

// iOS 14 chỉ có internalStringToExternal:, các bản mới hơn có thêm biến thể ignoreCompositionDisabled:.
static BOOL gBTHasIgnoreVariant;

// Chạy Unikey trên chuỗi phím, bỏ qua compositionDisabled vì decomposeTelex: chỉ được gọi khi đang compose.
static NSString *BTCompose(TIKeyboardInputManager_vi *im, NSString *internal) {
	if (gBTHasIgnoreVariant)
		return [im internalStringToExternal:internal ignoreCompositionDisabled:YES];
	return [im internalStringToExternal:internal];
}

%hook TIKeyboardInputManager_vi

- (NSString *)decomposeTelex:(NSString *)external {
	NSString *internal = %orig;
	// [debug]
	// BTLogf(@"decomposeTelex: %@ -> %@", external, internal);
	// [/debug]
	if (!internal || external.length == 0 || external.length > kBTMaxWordLength)
		return internal;

	// Đang chuyển phím vừa bấm, không phải dựng lại từ đã chốt: giữ hành vi gốc.
	if (gBTTypingKey && [external isEqualToString:gBTTypingKey])
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
			// [debug]
			// BTLogf(@"giveup external=%@ orig=%@ at=%lu", external, internal, (unsigned long)i);
			// [/debug]
			return internal;
		}
		[built appendString:picked];
		i = NSMaxRange(r);
	}

	// [debug]
	// BTLogf(@"fixed external=%@ orig=%@ new=%@", external, internal, built);
	// [/debug]
	return built;
}

- (NSString *)addInput:(NSString *)input flags:(unsigned int)flags point:(CGPoint)point firstDelete:(unsigned long long *)firstDelete {
	NSString *previousKey = gBTTypingKey;
	gBTTypingKey = input;
	NSString *result = %orig;
	gBTTypingKey = previousKey;
	return result;
}

%end

// [debug] Hook chỉ để ghi log, xem iOS thực sự đi qua đường nào. Mỗi nhóm chỉ init khi method tồn tại.
// %group DiagExt
// %hook TIKeyboardInputManager_vi
// - (NSString *)externalStringToInternal:(NSString *)s {
// 	NSString *r = %orig;
// 	BTLogf(@"externalStringToInternal: %@ -> %@", s, r);
// 	return r;
// }
// %end
// %end
//
// %group DiagExtIgnore
// %hook TIKeyboardInputManager_vi
// - (NSString *)externalStringToInternal:(NSString *)s ignoreCompositionDisabled:(BOOL)ignore {
// 	NSString *r = %orig;
// 	BTLogf(@"externalStringToInternal:ignore=%d %@ -> %@", ignore, s, r);
// 	return r;
// }
// %end
// %end
//
// %group DiagSetInputIndex
// %hook TIKeyboardInputManager_vi
// - (void)setInput:(NSString *)s withIndex:(unsigned int)index {
// 	BTLogf(@"setInput:%@ withIndex:%u", s, index);
// 	%orig;
// }
// %end
// %end
//
// %group DiagSetInput
// %hook TIKeyboardInputManager_vi
// - (void)setInput:(NSString *)s {
// 	BTLogf(@"setInput:%@", s);
// 	%orig;
// }
// %end
// %end
//
// %group DiagAddInput
// %hook TIKeyboardInputManager_vi
// - (NSString *)addInput:(NSString *)s flags:(unsigned int)flags point:(CGPoint)point firstDelete:(unsigned long long *)firstDelete {
// 	NSString *r = %orig;
// 	BTLogf(@"addInput:%@ flags:0x%x -> %@", s, flags, r);
// 	return r;
// }
// %end
// %end
//
// static void BTDumpMethods(Class cls) {
// 	unsigned int count = 0;
// 	Method *methods = class_copyMethodList(cls, &count);
// 	NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
// 	for (unsigned int i = 0; i < count; i++)
// 		[names addObject:NSStringFromSelector(method_getName(methods[i]))];
// 	free(methods);
// 	BTLogf(@"%s super=%s methods(%u): %@", class_getName(cls), class_getName(class_getSuperclass(cls)),
// 		count, [names componentsJoinedByString:@" "]);
// }
// [/debug]

%ctor {
	// [debug]
	// BTLogf(@"loaded into %@ (pid %d)", NSProcessInfo.processInfo.processName, getpid());
	// [/debug]

	// Bundle tiếng Việt bình thường chỉ được nạp khi người dùng chuyển sang bàn phím tiếng Việt.
	// Nạp sẵn để hook ngay; Unikey chỉ khởi tạo khi input manager thật sự được tạo nên gần như không tốn gì.
	dlopen("/System/Library/TextInput/TextInput_vi.bundle/TextInput_vi", RTLD_NOW);
	Class cls = objc_getClass("TIKeyboardInputManager_vi");
	if (!cls || !class_getInstanceMethod(cls, @selector(decomposeTelex:))) {
		// [debug]
		// BTLogf(@"không tìm thấy TIKeyboardInputManager_vi hoặc decomposeTelex:, chưa hook (dlerror: %s)", dlerror());
		// [/debug]
		return;
	}

	gBTHasIgnoreVariant = class_getInstanceMethod(cls, @selector(internalStringToExternal:ignoreCompositionDisabled:)) != NULL;
	%init;

	// [debug]
	// BTLogf(@"hooks installed");
	// BTDumpMethods(cls);
	// if (class_getInstanceMethod(cls, @selector(externalStringToInternal:))) %init(DiagExt);
	// if (class_getInstanceMethod(cls, @selector(externalStringToInternal:ignoreCompositionDisabled:))) %init(DiagExtIgnore);
	// if (class_getInstanceMethod(cls, @selector(setInput:withIndex:))) %init(DiagSetInputIndex);
	// if (class_getInstanceMethod(cls, @selector(setInput:))) %init(DiagSetInput);
	// if (class_getInstanceMethod(cls, @selector(addInput:flags:point:firstDelete:))) %init(DiagAddInput);
	// [/debug]
}
