
flutter run -d chrome
flutter run -d edge
flutter run -d emulator-5554
flutter clean
// làm app hoàn chỉnh
flutter build windows
flutter build apk --release
flutter build appbundle --release

dung lượng ước tính của chương trình là 4 GB khi chạy hoàn chỉnh

dự kiến:
- chuyển toàn bộ dât về AI và file nghe lên github (khi người dùng cần sẽ tải xuống)         #hoàn thành
- bổ sung tính năng nói chuyện với bot, hội thoại ngắn, hội thoại theo chủ đề                #hoàn thành
- sửa luyện thanh điệu để nó có thể đánh giá chính xác cho tôi                                          
- giảm kích thước chương trình xuống còn 500 MB                                              #hoàn thành
- tăng bảo mật của chương trình nên. thêm tính năng đồng bộ hệ thông bằng mã QR, đăng nhập bằng gg
- tích hợp dùng Ai agent nhưng gemini để có thể hỗ trợ tốt hơn cho người dùng
- mô hình đc tải về là Qwen2.5-0.5B-Instruct                                                  #hoàn thành
