import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentThumbnail;
  List<Song>? _playlist;
  int _currentIndex = 0;

  // Streams
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  bool get isPlaying => _player.state == PlayerState.playing;
  bool get hasSong => _currentPath != null;

  String? get title => _currentTitle;
  String? get artist => _currentArtist;
  String? get thumbnail => _currentThumbnail;

  Song? get currentSong {
    if (_currentPath == null || _playlist == null) return null;
    try {
      return _playlist!.firstWhere((s) => s.localPath == _currentPath);
    } catch (_) {
      return null;
    }
  }

  void setPlaylist(List<Song> playlist, int initialIndex) {
    _playlist = playlist;
    _currentIndex = initialIndex.clamp(0, playlist.length - 1);
  }

  Future<void> play(Song song) async {
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

  Future<void> resume() async => _player.resume();
  Future<void> pause() async => _player.pause();
  Future<void> stop() async {
    await _player.stop();
    _currentPath = null;
    _currentTitle = null;
    _currentArtist = null;
    _currentThumbnail = null;
    _playlist = null;
    _currentIndex = 0;
  }
  Future<void> seek(Duration position) async => _player.seek(position);
  void dispose() => _player.dispose();
}