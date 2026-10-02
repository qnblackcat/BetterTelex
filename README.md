# BetterTelex

Tweak sửa lỗi bộ gõ **Telex** của bàn phím tiếng Việt mặc định trên iOS: từ đã gõ đúng bị biến đổi khi quay lại sửa.

## Lỗi được sửa

Gõ `ww` + `hat` → `what`, bấm dấu cách, xoá dấu cách, gõ thêm `s`:

| | Kết quả |
|---|---|
| iOS gốc | `ưhats` |
| BetterTelex | `whats` |

Áp dụng cho mọi ký tự Telex đã được "thoát" (`ww`, `aaa`, `dd`, `ss`…), ví dụ `isp` không còn bị đổi thành `íp`. Từ tiếng Việt vẫn sửa dấu bình thường (`viet` → xoá dấu cách → `j` → `việt`).

## Yêu cầu

- Đã test: iOS 17, jailbreak roothide
- Bàn phím Tiếng Việt, kiểu gõ Telex (VNI/VIQR không bị lỗi này)

## Build

```bash
make package FINALPACKAGE=1
```

Theos dùng scheme `roothide` (xem `Makefile`). Sau khi cài, khởi động lại `kbd` (`killall -9 kbd`) hoặc respring.

## Cách hoạt động

Bộ gõ (`TIKeyboardInputManager_vi`, chạy trong daemon `kbd`) dựng lại chuỗi phím từ chữ hiển thị bằng `decomposeTelex:`, hàm này không phải hàm ngược của Unikey nên `what` bị dựng thành `what` → `ưhat`.

Tweak hook `decomposeTelex:`: nếu kết quả chạy lại qua Unikey không ra đúng chữ hiển thị, dựng lại chuỗi phím từng ký tự, thêm phím thoát khi cần (`what` → `wwhat`). Phím vừa bấm (`addInput:`) thì giữ nguyên hành vi gốc.

## Debug

Code chẩn đoán được comment sẵn trong `Tweak.x`, đánh dấu `// [debug]` … `// [/debug]`. Bỏ `//` ở **tất cả** các khối để bật, rồi xem log trên máy:

```bash
oslog | grep -i bettertelex
```
