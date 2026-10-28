# HaMy_Pocket

## Cấu trúc chương trình

- `lib/app/`: khởi tạo ứng dụng, điều hướng và giao diện màu sắc.
- `lib/core/`: tiện ích dùng chung như chuẩn hóa văn bản.
- `lib/domain/`: model từ vựng, tiến độ và quy tắc học/ôn tập.
- `lib/data/`: nguồn từ điển và repository truy cập dữ liệu.
- `lib/services/`: đọc phát âm, âm thanh và lưu tiến độ/từ cá nhân.
- `lib/features/`: màn hình bài học, nghe, nói, đọc báo, viết, từ vựng, ôn tập, kiểm tra, từ điển và cài đặt.
- `lib/shared/`: widget dùng chung và các thẻ điều hướng tính năng.
- `assets/data/`, `assets/library/` và `assets/images/`: dữ liệu nền tảng cần có ngay khi mở ứng dụng. Chỉ mục đáp án đề thi nằm tại `assets/audio/exam_database.json`; audio, PDF và mô hình lớn được tải riêng.

Trang chủ có mục **Tải thêm dữ liệu và AI**. Từ đây có thể tải riêng audio/PDF HSK 1–6 từ kho GitHub LFS `vodanh404/data_HaMy_Pocket`, mô hình dịch và mô hình chat; tiến độ tải được hiển thị và các gói lưu trong vùng dữ liệu ứng dụng để dùng ngoại tuyến. Từ điển và chỉ mục đáp án đề thi vẫn nằm trong bộ cài. Luyện nghe/đọc chỉ hiển thị các tài liệu đã tải hoặc do người dùng nhập. Khi tên MP3 và PDF có chung mã đề (ví dụ `H10901.mp3` và `H10901.pdf`), chuyển giữa hai phần **Nghe** và **Đọc** sẽ mở đúng câu hỏi và trang PDF. Nếu đề chưa có trong `assets/audio/exam_database.json`, ứng dụng tự đọc đáp án từ PDF, tạo JSON trong bộ nhớ ứng dụng và dùng đáp án đó để chấm.

Thư viện tiếp tục quét `AssetManifest` cho học liệu được đóng gói nhỏ, đồng thời tìm các tệp đã tải trong vùng dữ liệu ứng dụng; không cần đóng gói audio/PDF vào app. Người dùng cũng có thể chọn **Quét thư mục học liệu** để nhập MP3/PDF trong thư mục và thư mục con, hoặc **Nhập tài liệu** để chọn tệp riêng. Các tệp RAR cần giải nén trước khi nhập. Xóa dữ liệu người dùng chỉ xóa tài liệu đã nhập và JSON tự tạo; gói tải thêm được giữ lại.

`lib/main.dart` là điểm vào ứng dụng và giữ export tương thích cho các API dữ liệu đang được test sử dụng.

## Từ điển tích hợp

Ứng dụng nạp dữ liệu ngoại tuyến từ `assets/data/complete_han_viet.json`, gồm 11.470 mục với Hán tự giản thể/phồn thể, pinyin và nghĩa tiếng Việt. Tìm kiếm trong tab Từ điển hỗ trợ các trường này và có thể lọc theo HSK.

Dữ liệu nguồn phân loại riêng HSK 1–6 và gộp HSK 7–9 vào một nhóm; ứng dụng hiển thị và lọc nhóm này như một cấp độ duy nhất.

## Luyện gõ tiếng Trung

Từ trang **Bài học**, chọn **Luyện nghe**, **Đọc báo**, **Luyện nói** hoặc **Luyện gõ** để mở từng khu vực. Nút cài đặt ở góc trên dẫn đến trang **Cài đặt**. Trong tab **Luyện gõ**, chọn toàn bộ từ điển, từ cá nhân hoặc một nhóm HSK; có thể luyện 10 từ, 25 từ hoặc toàn bộ từ phù hợp. Đáp án chấp nhận chữ giản thể hoặc các dạng phồn thể trong từ điển.

## Luyện thanh điệu và giao diện

Mục **Luyện nói** có bài tập bốn thanh với mẫu phát âm Sherpa ONNX, ghi âm tối đa 6 giây và biểu đồ cao độ ước lượng ngay trên thiết bị. Điểm phản hồi dựa trên hướng biến thiên cao độ, chỉ mang tính tham khảo; bản ghi không được lưu hoặc gửi đi. Cấp quyền micro khi được hỏi để dùng bài tập.

Trong **Cài đặt**, chọn một trong ba speaker tiếng Phổ thông Sherpa. Gói VITS lượng tử hóa (khoảng 40 MB) được tải khi người dùng yêu cầu phát mẫu lần đầu; sau đó có thể phát ngoại tuyến. Cùng mục cài đặt có công tắc **Giao diện tối**, lựa chọn giao diện được lưu trên thiết bị.

Trong **Luyện nói**, chọn **Hội thoại theo chủ đề** để chat hoặc luyện nói về giới thiệu bản thân, nhà hàng, du lịch, mua sắm và sinh hoạt hằng ngày. Mô hình Qwen2.5-0.5B-Instruct GGUF Q4_K_M (khoảng 491 MB) có thể tải từ trang **Dữ liệu và AI** hoặc khi mở hội thoại lần đầu; suy luận sau đó chạy cục bộ và ngoại tuyến. Nút micro dùng dịch vụ nhận dạng tiếng Trung của hệ điều hành, có thể cần mạng; bản ghi âm không được gửi đến mô hình Qwen, chỉ văn bản nhận dạng sau khi người dùng gửi được đưa vào hội thoại.

## Dịch Trung–Việt

Tính năng dịch chạy ngoại tuyến bằng OPUS-MT Trung → Việt. Tokenizer nhẹ được đóng gói cùng ứng dụng; hai model ONNX int8 (khoảng 230 MB) tải từ [Hugging Face](https://huggingface.co/R4kSo1997/opus-mt-zh-vi-onnx-int8) khi người dùng chọn trong **Dữ liệu và AI**.

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
