#import <Foundation/Foundation.h>

// Đọc/ghi file cài đặt (BTPrefs.h) và báo cho tweak nạp lại sau mỗi lần ghi.
@interface BTPrefsStore : NSObject
+ (NSDictionary *)load;
+ (void)setObject:(id)value forKey:(NSString *)key;
// Thay toàn bộ cài đặt (dùng khi nhập file). Chỉ giữ các khoá BetterTelex biết, sai kiểu thì bỏ.
+ (void)replaceAll:(NSDictionary *)prefs;

// Từ điển cá nhân: chữ thường, NFC, không trùng, đã sắp xếp.
+ (NSArray<NSString *> *)userWords;
+ (void)setUserWords:(NSArray<NSString *> *)words;
// Chuẩn hoá một từ người dùng nhập; nil nếu rỗng.
+ (NSString *)normalizedWord:(NSString *)word;
@end
