import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';

// ✅ Đổi tên thành LoopMode để tránh xung đột với Flutter's RepeatMode
enum LoopMode { none, one, all }

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  AudioManager._internal() {
    _player.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      _positionController.add(pos);
    });
    _player.onDurationChanged.listen((dur) {
      _currentDuration = dur;
      _durationController.add(dur);
    });
    _player.onPlayerStateChanged.listen((state) {
      _playerStateController.add(state);
    });
    _player.onPlayerComplete.listen((_) {
      _playerCompleteController.add(null);
      if (!_isStoppedByUser) {
        _handleAutoNextGlobally();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentThumbnail;
  List<Song>? _playlist;
  int _currentIndex = 0;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isStoppedByUser = false;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _playerCompleteController = StreamController<void>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<void> get playerCompleteStream => _playerCompleteController.stream;

  Duration get currentPosition => _currentPosition;
  Duration get currentDuration => _currentDuration;

  bool get isPlaying => _player.state == PlayerState.playing;
  bool get hasSong => _currentPath != null;

  String? get title => _currentTitle;
  String? get artist => _currentArtist;
  String? get thumbnail => _currentThumbnail;
  List<Song>? get playlist => _playlist;
  int get currentIndex => _currentIndex;

  LoopMode loopMode = LoopMode.none;
  bool autoNext = true;

  Song? get currentSong {
    if (_currentPath == null || _playlist == null) return null;
    try {
      return _playlist!.firstWhere((s) => s.localPath == _currentPath);
    } catch (_) {
      return null;
    }
  }

  // ✅ Set loop mode (dùng ReleaseMode của audioplayers)
  Future<void> setLoopMode(LoopMode mode) async {
    loopMode = mode;
    if (mode == LoopMode.one) {
      await _player.setReleaseMode(ReleaseMode.loop);
    } else {
      await _player.setReleaseMode(ReleaseMode.release);
    }
  }

  // ✅ Xử lý khi bài hát kết thúc
  Future<void> _handleAutoNextGlobally() async {
    if (_playlist == null || _playlist!.isEmpty) return;
    if (_isStoppedByUser) return;

    if (loopMode == LoopMode.one) {
      // ReleaseMode.loop đã tự xử lý lặp, không cần làm gì
      return;
    }

    if (loopMode == LoopMode.all) {
      await next();
      return;
    }

    if (autoNext) {
      await next();
    } else {
      await stop();
    }
  }

  void setPlaylist(List<Song> playlist, int initialIndex) {
    _playlist = playlist;
    _currentIndex = initialIndex.clamp(0, playlist.length - 1);
  }

  void updatePlaylist(List<Song> newPlaylist, {int? currentIndex}) {
    _playlist = newPlaylist;
    if (currentIndex != null && currentIndex < newPlaylist.length) {
      _currentIndex = currentIndex;
    } else {
      if (_currentIndex >= newPlaylist.length) {
        _currentIndex = newPlaylist.length - 1;
        if (_currentIndex < 0) _currentIndex = 0;
      }
    }
  }

  Future<void> play(Song song) async {
    if (_currentPath == song.localPath && _player.state == PlayerState.playing) {
      return;
    }
    _isStoppedByUser = false;

    _currentPath = song.localPath;
    _currentTitle = song.title;
    _currentArtist = song.artist;
    _currentThumbnail = song.thumbnailUrl;

    if (_playlist != null) {
      final index = _playlist!.indexOf(song);
      if (index != -1) _currentIndex = index;
    }

    try {
      await _player.stop();
      await _player.setSource(DeviceFileSource(song.localPath));
      await _player.resume();
    } catch (e) {
      print('Lỗi phát nhạc: $e');
      rethrow;
    }
  }

  Future<void> next() async {
    if (_playlist == null || _playlist!.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist!.length;
    await play(_playlist![_currentIndex]);
  }

  Future<void> previous() async {
    if (_playlist == null || _playlist!.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _playlist!.length;
    if (_currentIndex < 0) _currentIndex = _playlist!.length - 1;
    await play(_playlist![_currentIndex]);
  }

  Future<void> resume() async {
    _isStoppedByUser = false;
    await _player.resume();
  }

  Future<void> pause() async {
    _isStoppedByUser = true;
    await _player.pause();
  }

  Future<void> stop() async {
    _isStoppedByUser = true;
    await _player.stop();
    _currentPath = null;
    _currentTitle = null;
    _currentArtist = null;
    _currentThumbnail = null;
    _playlist = null;
    _currentIndex = 0;
    _currentPosition = Duration.zero;
    _currentDuration = Duration.zero;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _currentPosition = position;
  }

  Future<void> setPlaybackRate(double rate) async => _player.setPlaybackRate(rate);

  void dispose() {
    _player.dispose();
    _positionController.close();
    _durationController.close();
    _playerStateController.close();
    _playerCompleteController.close();
  }
}