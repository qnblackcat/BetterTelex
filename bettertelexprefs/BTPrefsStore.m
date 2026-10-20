#import "BTPrefsStore.h"
#import "../BTPrefs.h"
#include <roothide.h>
#include <notify.h>

@implementation BTPrefsStore

+ (NSString *)path {
	return jbroot(BT_PREFS_PATH);
}

+ (NSDictionary *)load {
	return [NSDictionary dictionaryWithContentsOfFile:[self path]] ?: @{};
}

+ (void)writeAll:(NSDictionary *)prefs {
	NSString *path = [self path];
	[[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent
		withIntermediateDirectories:YES attributes:nil error:NULL];
	[prefs writeToFile:path atomically:YES];
	notify_post(BT_PREFS_CHANGED);
}

+ (void)setObject:(id)value forKey:(NSString *)key {
	NSMutableDictionary *prefs = [[self load] mutableCopy];
	prefs[key] = value;
	[self writeAll:prefs];
}

+ (void)replaceAll:(NSDictionary *)prefs {
	NSMutableDictionary *clean = [NSMutableDictionary dictionary];
	for (NSString *key in @[BT_KEY_ENABLED, BT_KEY_RESTORE_ENABLED, BT_KEY_SIMPLE_TELEX]) {
		if ([prefs[key] isKindOfClass:NSNumber.class])
			clean[key] = prefs[key];
	}
	clean[BT_KEY_USER_WORDS] = [self normalizedWords:prefs[BT_KEY_USER_WORDS]];
	[self writeAll:clean];
}

+ (NSString *)normalizedWord:(NSString *)word {
	NSString *trimmed = [word stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	if (trimmed.length == 0)
		return nil;
	return trimmed.lowercaseString.precomposedStringWithCanonicalMapping;
}

// Chuẩn hoá, bỏ trùng, sắp xếp; phần tử không phải chuỗi hoặc rỗng thì bỏ.
+ (NSArray<NSString *> *)normalizedWords:(id)words {
	if (![words isKindOfClass:NSArray.class])
		return @[];
	NSMutableSet<NSString *> *unique = [NSMutableSet set];
	for (id word in words) {
		NSString *normalized = [word isKindOfClass:NSString.class] ? [self normalizedWord:word] : nil;
		if (normalized)
			[unique addObject:normalized];
	}
	return [unique.allObjects sortedArrayUsingSelector:@selector(localizedCompare:)];
}

+ (NSArray<NSString *> *)userWords {
	return [self normalizedWords:[self load][BT_KEY_USER_WORDS]];
}

+ (void)setUserWords:(NSArray<NSString *> *)words {
	[self setObject:[self normalizedWords:words] forKey:BT_KEY_USER_WORDS];
}

@end
