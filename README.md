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

Màn hình **Luyện nghe và đọc** tự nhận diện MP3 và PDF trong `assets/audio/`, cùng PDF trong `assets/documents/`. Khi tên MP3 và PDF có chung mã đề (ví dụ `H10901.mp3` và `H10901.pdf`), chuyển giữa hai phần **Nghe** và **Đọc** sẽ mở đúng phần câu hỏi và trang tương ứng trong PDF. Nếu đề chưa có trong `assets/audio/exam_database.json`, ứng dụng tự đọc đáp án từ PDF, tạo JSON trong bộ nhớ ứng dụng và dùng đáp án đó để chấm; câu trả lời chữ (như phần viết HSK3) dùng ô nhập thay vì lựa chọn A–F. Có thể đóng gói học liệu mới vào assets (hiển thị sau lần build tiếp theo), chọn **Quét thư mục học liệu** để tự nhập các MP3/PDF trong thư mục và thư mục con, hoặc dùng **Nhập tài liệu** để chọn tệp riêng. Các tệp RAR cần giải nén trước khi nhập. Xóa dữ liệu người dùng chỉ xóa tài liệu đã nhập và JSON tự tạo; học liệu đóng gói sẵn vẫn được giữ lại.

Thư viện quét `AssetManifest` của Flutter thay vì phụ thuộc `assets/library/catalog.json`, vì vậy các mục cũ trỏ tới tệp đã đổi tên hoặc xóa không gây lỗi khi mở ứng dụng. Hai thư mục `assets/audio/` và `assets/documents/` được đăng ký cố định trong `pubspec.yaml`; chỉ cần đặt học liệu vào đúng thư mục rồi tạo lại gói ứng dụng.

`lib/main.dart` là điểm vào ứng dụng và giữ export tương thích cho các API dữ liệu đang được test sử dụng.

## Từ điển tích hợp

Ứng dụng nạp dữ liệu ngoại tuyến từ `assets/data/complete_han_viet.json`, gồm 11.470 mục với Hán tự giản thể/phồn thể, pinyin và nghĩa tiếng Việt. Tìm kiếm trong tab Từ điển hỗ trợ các trường này và có thể lọc theo HSK.

Dữ liệu nguồn phân loại riêng HSK 1–6 và gộp HSK 7–9 vào một nhóm; ứng dụng hiển thị và lọc nhóm này như một cấp độ duy nhất.

## Luyện gõ tiếng Trung

Từ trang **Bài học**, chọn **Luyện nghe**, **Đọc báo**, **Luyện nói** hoặc **Luyện gõ** để mở từng khu vực. Nút cài đặt ở góc trên dẫn đến trang **Cài đặt**. Trong tab **Luyện gõ**, chọn toàn bộ từ điển, từ cá nhân hoặc một nhóm HSK; có thể luyện 10 từ, 25 từ hoặc toàn bộ từ phù hợp. Đáp án chấp nhận chữ giản thể hoặc các dạng phồn thể trong từ điển.

## Luyện thanh điệu và giao diện

Mục **Luyện nói** có bài tập bốn thanh với mẫu phát âm Sherpa ONNX, ghi âm tối đa 6 giây và biểu đồ cao độ ước lượng ngay trên thiết bị. Điểm phản hồi dựa trên hướng biến thiên cao độ, chỉ mang tính tham khảo; bản ghi không được lưu hoặc gửi đi. Cấp quyền micro khi được hỏi để dùng bài tập.

Trong **Cài đặt**, chọn một trong ba speaker tiếng Phổ thông Sherpa. Gói VITS lượng tử hóa (khoảng 40 MB) được tải khi người dùng yêu cầu phát mẫu lần đầu; sau đó có thể phát ngoại tuyến. Cùng mục cài đặt có công tắc **Giao diện tối**, lựa chọn giao diện được lưu trên thiết bị.

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
