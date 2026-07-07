import 'package:flutter/material.dart';
import '../models/song.dart';
import 'yt_service.dart';
import 'db_service.dart';

class DownloadTask {
  final Map<String, dynamic> videoData;
  double progress;
  bool isComplete;

  DownloadTask({
    required this.videoData,
    this.progress = 0.0,
    this.isComplete = false,
  });
}

class DownloadManager extends ChangeNotifier {
  final YoutubeService _ytService = YoutubeService();
  final DatabaseService _db = DatabaseService();

  final Map<String, DownloadTask> _tasks = {};
  Map<String, DownloadTask> get tasks => _tasks;

  // Kiểm tra một video đang được tải không
  bool isDownloading(String videoId) => _tasks.containsKey(videoId);

  // Lấy tiến độ của một video
  double? getProgress(String videoId) => _tasks[videoId]?.progress;

  Future<void> downloadVideo(
      Map<String, dynamic> video, {
        required VoidCallback onSuccess,
        required Function(String) onError,
      }) async {
    final videoId = video['id'];

    if (_tasks.containsKey(videoId)) return;

    _tasks[videoId] = DownloadTask(videoData: video);
    notifyListeners();

    try {
      final path = await _ytService.downloadAudio(
        videoId,
        video['title'],
        onProgress: (progress) {
          _tasks[videoId]!.progress = progress;
          notifyListeners();
        },
      );

      final song = Song(
        title: video['title'],
        localPath: path,
        artist: video['artist'],
        thumbnailUrl: video['thumbnail'],
      );
      await _db.insertSong(song);

      _tasks.remove(videoId);
      notifyListeners();
      onSuccess();
    } catch (e) {
      _tasks.remove(videoId);
      notifyListeners();
      onError(e.toString());
    }
  }

  void dispose() {
    _ytService.dispose();
    super.dispose();
  }
}