import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/download_manager.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DownloadManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Music App',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}