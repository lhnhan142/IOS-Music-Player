import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';

// Giữ nguyên enum cũ để UI không bị vỡ
enum LoopMode { none, one, all }
enum PlayerState { stopped, playing, paused, completed }

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  final ja.AudioPlayer _player = ja.AudioPlayer();
  List<Song>? _playlist;
  ja.ConcatenatingAudioSource? _playlistSource;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _playerCompleteController = StreamController<void>.broadcast();

  bool _isStoppedByUser = false;
  LoopMode _loopMode = LoopMode.none;
  bool autoNext = true;

  AudioManager._internal() {
    _initAudioSession();

    // --- Các listener cơ bản ---
    _player.positionStream.listen((pos) => _positionController.add(pos));
    _player.durationStream.listen((dur) {
      if (dur != null) _durationController.add(dur);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        _playerStateController.add(PlayerState.completed);
        _playerCompleteController.add(null);
        if (!autoNext && _loopMode != LoopMode.all) {
          _player.pause();
        }
      } else if (state.playing) {
        _playerStateController.add(PlayerState.playing);
      } else {
        _playerStateController.add(PlayerState.paused);
      }
    });

    // ✅ QUAN TRỌNG: Lắng nghe sự thay đổi bài hát ngầm và đánh thức UI
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        // 1. Ép MiniPlayer (HomeScreen) cập nhật lại thông tin bài hát mới
        //    Bằng cách bơm lại trạng thái playing hiện tại (nếu đang play)
        _playerStateController.add(
            _player.playing ? PlayerState.playing : PlayerState.paused
        );

        // 2. Bắn tín hiệu để PlayerScreen tự động cập nhật _currentIndex
        //    (Nó đang lắng nghe playerCompleteStream)
        _playerCompleteController.add(null);
      }
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  // --- Getters dành cho UI ---
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<void> get playerCompleteStream => _playerCompleteController.stream;

  Duration get currentPosition => _player.position;
  Duration get currentDuration => _player.duration ?? Duration.zero;
  bool get isPlaying => _player.playing;
  bool get hasSong => _playlist != null && _playlist!.isNotEmpty;
  int get currentIndex => _player.currentIndex ?? 0;
  List<Song>? get playlist => _playlist;
  Song? get currentSong {
    if (_playlist == null || _playlist!.isEmpty || _player.currentIndex == null) return null;
    if (_player.currentIndex! >= _playlist!.length) return null;
    return _playlist![_player.currentIndex!];
  }
  String? get title => currentSong?.title;
  String? get artist => currentSong?.artist;
  String? get thumbnail => currentSong?.thumbnailUrl;

  LoopMode get loopMode => _loopMode;
  Future<void> setLoopMode(LoopMode mode) async {
    _loopMode = mode;
    switch (mode) {
      case LoopMode.none:
        await _player.setLoopMode(ja.LoopMode.off);
        break;
      case LoopMode.one:
        await _player.setLoopMode(ja.LoopMode.one);
        break;
      case LoopMode.all:
        await _player.setLoopMode(ja.LoopMode.all);
        break;
    }
  }

  // --- Quản lý playlist ---
  Future<void> _buildAudioSource(List<Song> songs, int startIndex) async {
    _playlist = songs;
    final audioSources = songs.map((song) => ja.AudioSource.file(song.localPath)).toList();
    _playlistSource = ja.ConcatenatingAudioSource(children: audioSources);
    await _player.setAudioSource(_playlistSource!, initialIndex: startIndex);
  }

  void setPlaylist(List<Song> playlist, int initialIndex) {
    _buildAudioSource(playlist, initialIndex);
  }

  void updatePlaylist(List<Song> newPlaylist, {int? currentIndex}) {
    final indexToPlay = currentIndex ?? this.currentIndex;
    _buildAudioSource(newPlaylist, indexToPlay.clamp(0, newPlaylist.length - 1));
  }

  Future<void> play(Song song) async {
    _isStoppedByUser = false;
    if (_playlist == null) return;
    final index = _playlist!.indexOf(song);
    if (index != -1) {
      if (_player.audioSource == null) {
        await _buildAudioSource(_playlist!, index);
      } else {
        await _player.seek(Duration.zero, index: index);
      }
      await _player.play();
    }
  }

  Future<void> next() async => await _player.seekToNext();
  Future<void> previous() async => await _player.seekToPrevious();
  Future<void> resume() async { _isStoppedByUser = false; await _player.play(); }
  Future<void> pause() async { _isStoppedByUser = true; await _player.pause(); }
  Future<void> stop() async { _isStoppedByUser = true; await _player.stop(); }
  Future<void> seek(Duration position) async => await _player.seek(position);
  Future<void> setPlaybackRate(double rate) async => await _player.setSpeed(rate);

  void dispose() {
    _player.dispose();
    _positionController.close();
    _durationController.close();
    _playerStateController.close();
    _playerCompleteController.close();
  }
}