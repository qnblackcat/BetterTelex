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

## Khôi phục từ không phải tiếng Việt (iOS 15+)

Gõ tiếng Anh bằng bàn phím Telex hay bị thêm dấu ngoài ý muốn. Khi bấm dấu cách, `,` hoặc `.`, nếu từ vừa gõ có dấu mà không phải âm tiết tiếng Việt thì BetterTelex trả về đúng các phím đã gõ:

| Gõ | iOS gốc | BetterTelex |
|---|---|---|
| `does` + dấu cách | `doé ` | `does ` |
| `vieets` + dấu cách | `viết ` | `viết ` |

- Unikey của iOS đã tự bỏ qua những từ sai luật ghép vần (`inters`, `viets` vẫn giữ nguyên), nên BetterTelex chỉ xử lý những từ đúng luật mà không có thật, như `doé`.
- Để biết từ nào là tiếng Việt, tweak dùng danh sách âm tiết [hunspell-vi](https://github.com/1ec5/hunspell-vi) (cả dấu mới `hoà` lẫn dấu cũ `hóa`). Danh sách này cài cùng gói vào `/Library/Application Support/BetterTelex/` (rootless: `/var/jb/...`). Giấy phép GNU GPLv2, xem `README-dictionaries.txt` và `COPYING-dictionaries` trong thư mục đó.
- Không khôi phục: từ một ký tự (`đ`), viết tắt không có nguyên âm (`đk`, `đm`, `HĐ`, `ĐHQG`), từ có số hoặc ký hiệu, và từ đang sửa giữa chừng.
- Từ hợp lệ nhưng không có trong danh sách sẽ bị trả về phím gốc. `vi-BetterTelex.dic` cùng thư mục bổ sung sẵn những từ hunspell thiếu (`quí`, `ừm`, `nguệch`…).
- **Cài đặt → BetterTelex**: công tắc tổng **Bật tweak** ở đầu trang (tắt thì bàn phím như iOS gốc), công tắc bật/tắt tính năng này, và **Từ điển cá nhân** để thêm từ không bao giờ bị khôi phục (nhập nhiều từ cách nhau bằng dấu cách/dấu phẩy, vuốt trái để xoá). Thay đổi có hiệu lực ngay, không cần respring. Cài đặt lưu ở `/var/mobile/Library/Preferences/com.qn.bettertelex.plist`. **Xuất cài đặt / Nhập cài đặt** sao lưu toàn bộ cài đặt (cả từ điển cá nhân) ra một file `.plist` để chuyển sang máy khác.
- Đã test trên iOS 17; iOS 16 dùng cùng cơ chế (đã đối chiếu mã máy iOS 16.3) nhưng chưa test trên máy. iOS 15: **chưa kiểm chứng**, bật thử; nếu không chạy thì bàn phím vẫn như iOS gốc. iOS 14 trở xuống: tắt hẳn.

## Telex đơn giản (iOS 15+)

Bật trong **Cài đặt → BetterTelex → Telex đơn giản** (mặc định tắt, có hiệu lực ngay). Chỉ áp dụng cho bàn phím Telex.

| Gõ | Telex | Telex đơn giản |
|---|---|---|
| `what` | `ưhat` | `what` |
| `tw` | `tư` | `tw` |
| `ww` | `w` | `ww` |
| `uw`, `tuw`, `nguwowif`, `tranw` | `ư`, `tư`, `người`, `trăn` | như Telex |

`w` chỉ còn tác dụng khi từ đang gõ đã có `a`/`o`/`u` (ă, ơ, ư); muốn `ư` đứng riêng thì gõ `uw`. Unikey của iOS không có sẵn kiểu gõ này, nên tweak nhân đôi những `w` đứng một mình thành `ww` (phím thoát của Telex) trước khi đưa vào Unikey.

## Báo lỗi

Bật **Cài đặt → BetterTelex → Debug → Ghi log chẩn đoán** (mặc định tắt), gõ lại trường hợp bị lỗi, rồi bấm **Chia sẻ file log** trong cùng trang để gửi file (lưu vào Tệp, AirDrop, gửi qua tin nhắn…). Log cũng có trong Console.app trên Mac (cắm máy, chọn thiết bị, lọc `BetterTelex`). File log nằm ở `/var/mobile/Library/Preferences/com.qn.bettertelex.log`, tối đa khoảng 2MB. Log có chứa chữ bạn gõ, nên tắt và bấm **Xoá file log** khi không cần.

## Yêu cầu

- iOS 15.0 trở lên (đã test: iOS 16, iOS 17 roothide; các bản khác cùng cơ chế nhưng chưa test)
- iOS 14.x và thấp hơn: **experimental**, chưa test trên máy thật. iOS 14 trở về trước thiếu `internalStringToExternal:ignoreCompositionDisabled:` nên tweak đọc thẳng flag `m_compositionDisabled` và không can thiệp khi cờ bật hoặc không đọc được, tệ nhất cũng chỉ như bàn phím gốc

## Build

<details>
<summary>Build instructions</summary>

Build the package with roothide's fork of Theos. 

```sh
make package FINALPACKAGE=1 SCHEME=rootless   #rootless
make package FINALPACKAGE=1 SCHEME=roothide   #roothide
make package FINALPACKAGE=1                   #rootful

```

iOS 12–13 trên máy A12 trở lên không được hỗ trợ: arm64e build bằng Xcode 12+ chỉ chạy từ iOS 14 ([Theos – arm64e deployment](https://theos.dev/docs/arm64e-deployment))

</details>

## Xem thêm

- [PerAppKeyboard](https://github.com/qnblackcat/PerAppKeyboard): chọn bàn phím mặc định cho từng app, vd mở Zalo là bàn phím Tiếng Việt, mở Safari là Tiếng Anh.

## Giấy phép
© 2026 Qn (Đạt Nguyễn). [GNU GPLv3](LICENSE)
