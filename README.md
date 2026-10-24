# HaMy_Pocket

## Cấu trúc chương trình

- `lib/app/`: khởi tạo ứng dụng, điều hướng và giao diện màu sắc.
- `lib/core/`: tiện ích dùng chung như chuẩn hóa văn bản.
- `lib/domain/`: model từ vựng, tiến độ và quy tắc học/ôn tập.
- `lib/data/`: nguồn từ điển và repository truy cập dữ liệu.
- `lib/services/`: đọc phát âm, âm thanh và lưu tiến độ/từ cá nhân.
- `lib/features/`: màn hình bài học, nghe, nói, đọc báo, viết, từ vựng, ôn tập, kiểm tra, từ điển và cài đặt.
- `lib/shared/`: widget dùng chung và các thẻ điều hướng tính năng.
- `assets/data/`, `assets/library/`, `assets/audio/`, `assets/documents/`, `assets/images/` và `assets/archives/`: dữ liệu từ điển, danh mục và học liệu được phân loại theo loại tệp. Các thư mục `Tổng hợp .../` bên dưới từng nhóm giữ thông tin nguồn.

Màn hình **Luyện nghe** tự nhận diện MP3 trong `assets/audio/`; PDF trong `assets/documents/` được nhận diện tự động làm bài tập/tài liệu. Có thể thêm, đổi tên hoặc xóa MP3/PDF trong các thư mục này mà không cần sửa danh mục hay đường dẫn theo từng file; ứng dụng chỉ hiển thị những tệp thực sự được đóng gói ở lần build tiếp theo. Khi tên MP3 và PDF có chung mã đề (ví dụ `H10901.mp3` và `H10901.pdf`), mở bài nghe sẽ hiển thị riêng phần nghe và phần bài tập tương ứng. MP3/PDF khác và ảnh có thể được thêm bằng **Nhập tài liệu** để lưu trong bộ nhớ ứng dụng. Các tệp RAR cần giải nén trước khi nhập.

Thư viện quét `AssetManifest` của Flutter thay vì phụ thuộc `assets/library/catalog.json`, vì vậy các mục cũ trỏ tới tệp đã đổi tên hoặc xóa không gây lỗi khi mở ứng dụng. Hai thư mục `assets/audio/` và `assets/documents/` được đăng ký cố định trong `pubspec.yaml`; chỉ cần đặt học liệu vào đúng thư mục rồi tạo lại gói ứng dụng.

`lib/main.dart` là điểm vào ứng dụng và giữ export tương thích cho các API dữ liệu đang được test sử dụng.

## Từ điển tích hợp

Ứng dụng nạp dữ liệu ngoại tuyến từ `assets/data/complete_han_viet.json`, gồm 11.470 mục với Hán tự giản thể/phồn thể, pinyin và nghĩa tiếng Việt. Tìm kiếm trong tab Từ điển hỗ trợ các trường này và có thể lọc theo HSK.

Dữ liệu nguồn phân loại riêng HSK 1–6 và gộp HSK 7–9 vào một nhóm; ứng dụng hiển thị và lọc nhóm này như một cấp độ duy nhất.

## Luyện gõ tiếng Trung

Từ trang **Bài học**, chọn **Luyện nghe**, **Đọc báo**, **Luyện nói** hoặc **Luyện gõ** để mở từng khu vực. Nút cài đặt ở góc trên dẫn đến trang **Cài đặt**. Trong tab **Luyện gõ**, chọn toàn bộ từ điển, từ cá nhân hoặc một nhóm HSK; có thể luyện 10 từ, 25 từ hoặc toàn bộ từ phù hợp. Đáp án chấp nhận chữ giản thể hoặc các dạng phồn thể trong từ điển.

## Dịch Trung–Việt

Tính năng dịch chạy ngoại tuyến bằng model `assets/opus_zh_vi_onnx` (Trung → Việt). Model ONNX và tokenizer cần được đóng gói cùng ứng dụng; dung lượng model gốc lớn nên bản cài đặt cũng sẽ tăng đáng kể.

## Đọc báo

Danh sách tin hiển thị tiêu đề; chọn một bài để tải và đọc nội dung trong ứng dụng. Bôi đen đoạn tiếng Trung để tự động dịch sang tiếng Việt.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
