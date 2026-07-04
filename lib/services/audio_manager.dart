import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  Future<void> play(String path) async {
    if (_currentPath != path) {
      await _player.stop();
      await _player.setSource(DeviceFileSource(path));
      _currentPath = path;
    }
    await _player.resume();
  }

  Future<void> resume() async => await _player.resume();
  Future<void> pause() async => await _player.pause();
  Future<void> stop() async {
    await _player.stop();
    _currentPath = null;
  }
  Future<void> seek(Duration position) async => await _player.seek(position);
  void dispose() => _player.dispose();
}