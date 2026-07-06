import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_music_player/main.dart';

void main() {
  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.text('My Music'), findsOneWidget);
  });
}