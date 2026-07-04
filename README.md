git clone <url-của-repo>
cd <tên-thư-mục>

2. Cài đặt dependencies
bash

flutter pub get

Nếu gặp lỗi pubspec.yaml has no lower-bound SDK constraint, hãy mở file pubspec.yaml và thêm vào đầu:
yaml

environment:
  sdk: ">=3.0.0 <4.0.0"

Rồi chạy lại flutter pub get.
3. Chạy trên web (kiểm tra giao diện)

Nếu chưa có thư mục web/, chạy:
bash

flutter create --platforms=web .

Sau đó:
bash

flutter run -d chrome

Ứng dụng sẽ mở trên Chrome. Lưu ý: Trên web, việc tải file và SQLite sẽ không hoạt động do bảo mật trình duyệt. Chỉ dùng để xem bố cục.
4. Chạy trên Android

    Kết nối thiết bị Android (bật USB debugging) hoặc mở emulator.

    Chạy:

bash

flutter run

5. Chạy trên iOS (cần máy Mac có Xcode)

    Mở project trong Xcode hoặc chạy:

bash

flutter run

Nếu thiếu Podfile, chạy:
bash

cd ios
pod install
cd ..
flutter run

📁 Cấu trúc dự án
text

lib/
├── main.dart                  # Điểm khởi chạy
├── models/
│   └── song.dart              # Model bài hát
├── screens/
│   ├── home_screen.dart       # Màn hình chính
│   └── player_screen.dart     # Màn hình phát nhạc
├── services/
│   ├── audio_manager.dart     # Quản lý phát nhạc
│   ├── db_service.dart        # SQLite
│   └── yt_service.dart        # Tải từ YouTube
└── widgets/
    ├── song_item.dart
    └── control_panel.dart

Các thư mục khác:

    android/ – cấu hình Android (nên commit, trừ local.properties)

    ios/ – cấu hình iOS (nên commit, trừ Pods/, .symlinks/)

    web/ – hỗ trợ web (nên commit)

    test/ – unit tests (nên commit)

    pubspec.yaml, pubspec.lock – cần commit để đồng bộ version

Không commit: build/, .dart_tool/, .idea/, *.iml, android/local.properties, ios/Pods/, ios/.symlinks/.
🐛 Lỗi thường gặp và cách khắc phục
Lỗi	Nguyên nhân	Cách sửa
pubspec.yaml has no lower-bound SDK constraint	Thiếu environment	Thêm environment: sdk: ">=3.0.0 <4.0.0" vào pubspec.yaml
Target of URI doesn't exist	Sai đường dẫn import	Kiểm tra lại tên file và đường dẫn (phân biệt hoa/thường)
The method 'PlayerScreen' isn't defined	File player_screen.dart chưa có hoặc class sai tên	Tạo file đúng tên và class PlayerScreen
Failed to fetch (trên web)	CORS / bảo mật trình duyệt	Không thể khắc phục, dùng Android/iOS thật
ThumbnailSet error	API thay đổi	Đã sửa bằng URL ảnh trực tiếp: https://img.youtube.com/vi/{id}/hqdefault.jpg
📦 Build cho iOS không cần Mac (Codemagic)

    Đẩy code lên GitHub.

    Đăng nhập Codemagic, tạo app mới.

    Chọn repository, cấu hình build iOS (có thể dùng automatic code signing).

    Tải file .ipa về và cài qua AltStore, TrollStore hoặc Scarlet.

🤝 Đóng góp

    Fork repository.

    Tạo branch mới: git checkout -b feature/ten-tinh-nang.

    Commit thay đổi: git commit -m "Mô tả thay đổi".

    Push lên branch: git push origin feature/ten-tinh-nang.

    Tạo Pull Request.

Chạy flutter analyze trước khi commit để phát hiện lỗi.
