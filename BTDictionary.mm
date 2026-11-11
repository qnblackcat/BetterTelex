#import <os/lock.h>
#include <roothide.h>
#include "BTDictionary.h"
#include "BTSettings.h"
#include "BTLog.h"

static os_unfair_lock gBTLock = OS_UNFAIR_LOCK_INIT;
// Âm tiết tiếng Việt, chữ thường NFC. nil khi chưa nạp xong: lúc đó không khôi phục gì.
static NSSet<NSString *> *gBTSyllables;

// hunspell-vi (GPLv2, cài qua layout/) gộp dấu mới (hoà) lẫn dấu cũ (hóa), cộng danh sách bổ sung vi-BetterTelex.dic
// (từ hunspell thiếu như "quí", "ừm"; không có dòng đếm, "#" là chú thích).
void BTLoadSyllables(void) {
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

NSUInteger BTSyllableCount(void) {
	os_unfair_lock_lock(&gBTLock);
	NSUInteger count = gBTSyllables.count;
	os_unfair_lock_unlock(&gBTLock);
	return count;
}

BOOL BTIsWordSeparator(NSString *input) {
	return [input isEqualToString:@" "] || [input isEqualToString:@","] || [input isEqualToString:@"."];
}

BOOL BTShouldRestore(NSString *word) {
	if (!gBTEnabled || !gBTRestoreEnabled || word.length < 2)
		return NO;
	os_unfair_lock_lock(&gBTLock);
	NSSet<NSString *> *syllables = gBTSyllables;
	os_unfair_lock_unlock(&gBTLock);
	if (!syllables)
		return NO;
	NSSet<NSString *> *userWords = BTUserWords();

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
