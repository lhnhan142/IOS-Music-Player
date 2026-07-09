import 'package:flutter/material.dart';
import '../models/song.dart';
import 'yt_service.dart';
import 'db_service.dart';

class DownloadTask extends ChangeNotifier {
  final Map<String, dynamic> videoData;
  double _progress = 0.0;
  bool _isComplete = false;
  bool isCancelled = false; // ✅ Cờ hủy

  DownloadTask({required this.videoData});

  double get progress => _progress;
  bool get isComplete => _isComplete;

  void updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void markComplete() {
    _isComplete = true;
    _progress = 1.0;
    notifyListeners();
  }

  void markError() {
    _isComplete = false;
    _progress = 0.0;
    notifyListeners();
  }
}

class _QueueItem {
  final Map<String, dynamic> video;
  final VoidCallback onSuccess;
  final Function(String) onError;

  _QueueItem({required this.video, required this.onSuccess, required this.onError});
}

class DownloadManager extends ChangeNotifier {
  final YoutubeService _ytService = YoutubeService();
  final DatabaseService _db = DatabaseService();

  final Map<String, DownloadTask> _tasks = {};
  Map<String, DownloadTask> get tasks => _tasks;

  final List<_QueueItem> _queue = [];
  final int _maxConcurrent = 3;

  bool isDownloading(String videoId) => _tasks.containsKey(videoId);

  DownloadTask? getTask(String videoId) => _tasks[videoId];

  // ✅ Hàm hủy tải
  void cancelDownload(String videoId) {
    _queue.removeWhere((item) => item.video['id'] == videoId);

    if (_tasks.containsKey(videoId)) {
      final task = _tasks[videoId]!;
      task.isCancelled = true;
      task.markError();
      _tasks.remove(videoId);
      notifyListeners();
      _processQueue();
    } else {
      notifyListeners();
    }
  }

  Future<void> downloadVideo(
      Map<String, dynamic> video, {
        required VoidCallback onSuccess,
        required Function(String) onError,
      }) async {
    final videoId = video['id'];
    if (_tasks.containsKey(videoId)) return;

    _queue.add(_QueueItem(video: video, onSuccess: onSuccess, onError: onError));
    _processQueue();
  }

  void _processQueue() {
    if (_tasks.length >= _maxConcurrent || _queue.isEmpty) return;

    final item = _queue.removeAt(0);
    final video = item.video;
    final videoId = video['id'];

    final task = DownloadTask(videoData: video);
    _tasks[videoId] = task;
    notifyListeners();

    _startDownload(item);
  }

  Future<void> _startDownload(_QueueItem item) async {
    final video = item.video;
    final videoId = video['id'];
    final task = _tasks[videoId]!;

    try {
      final path = await _ytService.downloadAudio(
        videoId,
        video['title'],
        onProgress: (progress) {
          if (!task.isCancelled) task.updateProgress(progress);
        },
        isCancelled: () => task.isCancelled,
      );

      if (task.isCancelled) return; // Đã hủy thì không lưu DB

      final song = Song(
        title: video['title'],
        localPath: path,
        artist: video['artist'],
        thumbnailUrl: video['thumbnail'],
      );
      await _db.insertSong(song);

      _tasks.remove(videoId);
      task.markComplete();
      notifyListeners();
      item.onSuccess();
      _processQueue();
    } catch (e) {
      if (task.isCancelled) return; // Bỏ qua lỗi do hủy

      _tasks.remove(videoId);
      task.markError();
      notifyListeners();
      item.onError(e.toString());
      _processQueue();
    }
  }

  @override
  void dispose() {
    _ytService.dispose();
    super.dispose();
  }
}