#import <Preferences/PSListController.h>

// Trang cài đặt chính. Mọi ô có defaults = com.qn.bettertelex đọc/ghi qua BTPrefsStore thay vì cfprefsd.
@interface BTRootListController : PSListController <UIDocumentPickerDelegate>
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
// Ghi data ra file tạm tên name rồi mở bảng chia sẻ của iOS.
- (void)shareData:(NSData *)data name:(NSString *)name;
@end
