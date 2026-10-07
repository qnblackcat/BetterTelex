# BetterTelex

Tweak sửa lỗi bộ gõ **Telex** của bàn phím tiếng Việt mặc định trên iOS: từ đã gõ đúng bị biến đổi khi quay lại sửa.

## Lỗi được sửa

Gõ `ww` + `hat` → `what`, bấm dấu cách, xoá dấu cách, gõ thêm `s`:

| | Kết quả |
|---|---|
| iOS gốc | `ưhats` |
| BetterTelex | `whats` |

Áp dụng cho mọi ký tự Telex đã được "thoát" (`ww`, `aaa`, `dd`, `ss`…), ví dụ `isp` không còn bị đổi thành `íp`. Từ tiếng Việt vẫn sửa dấu bình thường (`viet` → xoá dấu cách → `j` → `việt`).

https://github.com/user-attachments/assets/c6722d9c-9932-422c-8436-a910e1de78c6

## Yêu cầu

- iOS 15.0 trở lên (đã test: iOS 16, iOS 17 roothide; các bản khác cùng cơ chế nhưng chưa test)
- iOS 14.x và thấp hơn: **experimental**, chưa test trên máy thật. iOS 14 trở về trước thiếu `internalStringToExternal:ignoreCompositionDisabled:` nên tweak đọc thẳng flag `m_compositionDisabled` và không can thiệp khi cờ bật hoặc không đọc được, tệ nhất cũng chỉ như bàn phím gốc

## Build

```bash
make package FINALPACKAGE=1 SCHEME=rootless   #rootless
make package FINALPACKAGE=1 SCHEME=roothide   #roothide
make package FINALPACKAGE=1                   #rootful

```
iOS 12–13 trên máy A12 trở lên không được hỗ trợ: arm64e build bằng Xcode 12+ chỉ chạy từ iOS 14 ([Theos – arm64e deployment](https://theos.dev/docs/arm64e-deployment))
