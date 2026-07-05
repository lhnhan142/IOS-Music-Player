import 'package:audioplayers/audioplayers.dart';

class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<bool> get playerStateStream => _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  Future<void> play(String path) async {
    if (_currentPath != path) {
      await _player.stop();
      // Dùng DeviceFileSource cho file cục bộ
      await _player.setSource(DeviceFileSource(path));
      _currentPath = path;
    }
    await _player.resume();
  }

  Future<void> resume() async => _player.resume();
  Future<void> pause() async => _player.pause();
  Future<void> stop() async {
    await _player.stop();
    _currentPath = null;
  }
  Future<void> seek(Duration position) async => _player.seek(position);
  void dispose() => _player.dispose();
}