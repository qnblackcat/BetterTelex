// Từ điển âm tiết tiếng Việt và quyết định khôi phục từ không phải tiếng Việt.

#import <Foundation/Foundation.h>

// Đọc các file .dic trong layout/ và dựng set âm tiết. Gọi một lần ở nền.
void BTLoadSyllables(void);
// Số âm tiết đã nạp; 0 khi chưa nạp xong.
NSUInteger BTSyllableCount(void);

// Phím chốt từ, giống XKey.
BOOL BTIsWordSeparator(NSString *input);
// Từ vừa gõ (chữ hiển thị) có phải trả về phím gốc không.
BOOL BTShouldRestore(NSString *word);
