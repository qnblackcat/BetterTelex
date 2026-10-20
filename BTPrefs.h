// Cài đặt dùng chung giữa tweak (kbd) và bundle cài đặt (Settings).
// Lưu thẳng vào file plist qua jbroot() thay vì cfprefsd, để kbd đọc được ở mọi scheme (rootful/rootless/roothide).

#define BT_PREFS_PATH @"/var/mobile/Library/Preferences/com.qn.bettertelex.plist"
// File log chẩn đoán, cạnh file cài đặt (thư mục kbd đọc và Settings ghi được). Vượt BT_LOG_MAX_BYTES thì đổi tên
// thành BT_LOG_OLD_PATH (ghi đè bản .old cũ) và ghi file mới, nên tổng không quá ~2 lần giới hạn.
#define BT_LOG_PATH @"/var/mobile/Library/Preferences/com.qn.bettertelex.log"
#define BT_LOG_OLD_PATH @"/var/mobile/Library/Preferences/com.qn.bettertelex.log.old"
#define BT_LOG_MAX_BYTES (1024 * 1024)
// Darwin notification bundle cài đặt gửi sau mỗi lần ghi, tweak nghe để nạp lại ngay, không cần respring.
#define BT_PREFS_CHANGED "com.qn.bettertelex/ReloadPrefs"

// BOOL, mặc định YES: công tắc tổng. NO thì tweak không can thiệp gì, bàn phím như iOS gốc.
#define BT_KEY_ENABLED @"Enabled"
// BOOL, mặc định YES: khôi phục từ không phải tiếng Việt khi chốt từ.
#define BT_KEY_RESTORE_ENABLED @"RestoreEnabled"
// BOOL, mặc định NO: Telex đơn giản, "w" đứng một mình giữ là "w" (muốn "ư" thì gõ "uw").
#define BT_KEY_SIMPLE_TELEX @"SimpleTelex"
// BOOL, mặc định NO: ghi log chẩn đoán (trang Debug). Không đi theo file xuất/nhập cài đặt.
#define BT_KEY_DEBUG_LOG @"DebugLog"
// Mảng NSString: từ điển cá nhân, những từ không bao giờ bị khôi phục. Lưu chữ thường, NFC.
#define BT_KEY_USER_WORDS @"UserWords"
