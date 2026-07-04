import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_music_player/main.dart';  // nếu tên project là ios_music_player

void main() {
  testWidgets('MyMusicApp smoke test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(MyApp());

    // Kiểm tra xem có chữ "My Music" trên AppBar không
    expect(find.text('My Music'), findsOneWidget);

    // Kiểm tra xem có ô nhập liệu "Dán link YouTube..." không
    expect(find.text('Dán link YouTube...'), findsOneWidget);

    // Kiểm tra xem có ô tìm kiếm "Tìm kiếm..." không
    expect(find.text('Tìm kiếm...'), findsOneWidget);

    // Kiểm tra xem biểu tượng download có tồn tại không
    expect(find.byIcon(Icons.download), findsOneWidget);

    // Kiểm tra xem biểu tượng tìm kiếm có tồn tại không
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}