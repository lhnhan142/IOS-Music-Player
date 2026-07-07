import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_manager.dart';

enum RepeatMode { none, one, all }

class PlayerScreen extends StatefulWidget {
  final List<Song> songs;
  final int initialIndex;

  const PlayerScreen({
    Key? key,
    required this.songs,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioManager _audio = AudioManager();
  late int _currentIndex;
  Song get _currentSong => widget.songs[_currentIndex];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isDragging = false; // Để ngăn stream ghi đè slider khi kéo

  RepeatMode _repeatMode = RepeatMode.none;
  bool _autoNext = true;
  bool _isStoppedByUser = false;

  // Lưu các subscription để hủy
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (_audio.playlist == null || _audio.playlist!.isEmpty) {
      _audio.setPlaylist(widget.songs, _currentIndex);
    }

    // Lấy giá trị hiện tại từ AudioManager
    _position = _audio.currentPosition;
    _duration = _audio.currentDuration;

    // Lắng nghe stream và lưu subscription
    _positionSub = _audio.positionStream.listen((pos) {
      if (mounted && !_isDragging) {
        setState(() => _position = pos);
      }
    });
    _durationSub = _audio.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _stateSub = _audio.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
        if (state != PlayerState.stopped && state != PlayerState.completed) {
          _isStoppedByUser = false;
        }
      }
    });
    _completeSub = _audio.playerCompleteStream.listen((_) {
      if (mounted && !_isStoppedByUser) {
        _handleSongEnd();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPlaying = _audio.currentSong;
      if (currentPlaying == null || currentPlaying.localPath != _currentSong.localPath) {
        _audio.play(_currentSong);
      } else {
        setState(() {
          _isPlaying = _audio.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    // Hủy các subscription để tránh leak và setState sau dispose
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSongEnd() async {
    if (_repeatMode == RepeatMode.one) {
      await _audio.seek(Duration.zero);
      await _audio.resume();
      return;
    }

    if (_repeatMode == RepeatMode.all) {
      await _audio.next();
      final newSong = _audio.currentSong;
      if (newSong != null) {
        final index = widget.songs.indexOf(newSong);
        if (index != -1) setState(() => _currentIndex = index);
      }
      return;
    }

    if (_autoNext) {
      await _audio.next();
      final newSong = _audio.currentSong;
      if (newSong != null) {
        final index = widget.songs.indexOf(newSong);
        if (index != -1) setState(() => _currentIndex = index);
      }
    } else {
      _isStoppedByUser = true;
      await _audio.seek(Duration.zero);
      await _audio.pause();
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _changeSong(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.songs.length) {
      if (_repeatMode == RepeatMode.all) {
        if (newIndex < 0) newIndex = widget.songs.length - 1;
        else if (newIndex >= widget.songs.length) newIndex = 0;
      } else {
        return;
      }
    }
    setState(() => _currentIndex = newIndex);
    try {
      await _audio.play(widget.songs[_currentIndex]);
    } catch (e) {
      // File không tồn tại, xóa khỏi danh sách hoặc thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi phát nhạc: $e')),
      );
    }
  }

  void _toggleAutoNext() => setState(() => _autoNext = !_autoNext);
  void _toggleRepeat() {
    setState(() {
      if (_repeatMode == RepeatMode.none) _repeatMode = RepeatMode.one;
      else if (_repeatMode == RepeatMode.one) _repeatMode = RepeatMode.all;
      else _repeatMode = RepeatMode.none;
    });
  }

  IconData _getRepeatIcon() {
    switch (_repeatMode) {
      case RepeatMode.none: return Icons.repeat;
      case RepeatMode.one: return Icons.repeat_one;
      case RepeatMode.all: return Icons.repeat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxValue = _duration.inSeconds.toDouble() > 1 ? _duration.inSeconds.toDouble() : 1.0;
    final double currentValue = _position.inSeconds.toDouble().clamp(0, maxValue);

    return Scaffold(
      appBar: AppBar(title: Text(_currentSong.title)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _currentSong.thumbnailUrl != null
                ? Image.network(_currentSong.thumbnailUrl!, height: 200, fit: BoxFit.cover)
                : const Icon(Icons.album, size: 200),
            const SizedBox(height: 20),
            Text(_currentSong.title, style: const TextStyle(fontSize: 20)),
            Text(_currentSong.artist ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Slider(
              value: currentValue,
              max: maxValue,
              onChanged: (val) {
                setState(() {
                  _isDragging = true;
                  _position = Duration(seconds: val.toInt());
                });
              },
              onChangeStart: (_) {
                setState(() => _isDragging = true);
              },
              onChangeEnd: (val) {
                setState(() => _isDragging = false);
                _audio.seek(Duration(seconds: val.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(_getRepeatIcon()), onPressed: _toggleRepeat,
                    color: _repeatMode != RepeatMode.none ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => _changeSong(_currentIndex - 1)),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                  onPressed: () async {
                    if (_isPlaying) {
                      _isStoppedByUser = true;
                      await _audio.pause();
                    } else {
                      _isStoppedByUser = false;
                      if (_position.inSeconds >= _duration.inSeconds && _duration.inSeconds > 0) {
                        await _audio.seek(Duration.zero);
                      }
                      await _audio.resume();
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: () => _changeSong(_currentIndex + 1)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _toggleAutoNext,
                  color: _autoNext ? Colors.blue : Colors.grey,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Loop: ${_repeatMode.name}  |  AutoNext: ${_autoNext ? 'ON' : 'OFF'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}