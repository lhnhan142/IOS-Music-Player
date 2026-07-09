import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/audio_manager.dart';

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

  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _playbackRate = 1.0;

  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  Song get _currentSong => widget.songs[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Khởi tạo với giá trị hiện tại để tránh nhấp nháy
    _duration = _audio.currentDuration;

    if (_audio.playlist == null || _audio.playlist!.isEmpty) {
      _audio.setPlaylist(widget.songs, _currentIndex);
    }

    _durationSub = _audio.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _stateSub = _audio.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _completeSub = _audio.playerCompleteStream.listen((_) {
      if (mounted) {
        // Cập nhật chỉ số bài hát khi auto-next chuyển bài
        final newSong = _audio.currentSong;
        if (newSong != null) {
          final index = widget.songs.indexOf(newSong);
          if (index != -1) setState(() => _currentIndex = index);
        } else {
          // Nếu không còn bài hát nào, reset về 0 hoặc giữ nguyên
          // setState(() => _currentIndex = 0);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPlaying = _audio.currentSong;
      if (currentPlaying == null || currentPlaying.localPath != _currentSong.localPath) {
        _audio.play(_currentSong);
      } else {
        setState(() => _isPlaying = _audio.isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _changeSong(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.songs.length) {
      if (_audio.repeatMode == RepeatMode.all) {
        newIndex = newIndex < 0 ? widget.songs.length - 1 : 0;
      } else {
        return;
      }
    }
    setState(() => _currentIndex = newIndex);
    await _audio.play(widget.songs[_currentIndex]);
  }

  void _toggleAutoNext() {
    setState(() => _audio.autoNext = !_audio.autoNext);
  }

  void _toggleRepeat() {
    setState(() {
      if (_audio.repeatMode == RepeatMode.none) {
        _audio.repeatMode = RepeatMode.one;
      } else if (_audio.repeatMode == RepeatMode.one) {
        _audio.repeatMode = RepeatMode.all;
      } else {
        _audio.repeatMode = RepeatMode.none;
      }
    });
  }

  void _togglePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) _playbackRate = 1.25;
      else if (_playbackRate == 1.25) _playbackRate = 1.5;
      else if (_playbackRate == 1.5) _playbackRate = 2.0;
      else if (_playbackRate == 2.0) _playbackRate = 0.75;
      else _playbackRate = 1.0;
      _audio.setPlaybackRate(_playbackRate);
    });
  }

  IconData _getRepeatIcon() {
    switch (_audio.repeatMode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double maxValue = _duration.inSeconds.toDouble() > 1 ? _duration.inSeconds.toDouble() : 1.0;

    return Scaffold(
      appBar: AppBar(title: Text(_currentSong.title)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _currentSong.thumbnailUrl != null
                ? CachedNetworkImage(
              imageUrl: _currentSong.thumbnailUrl!,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Icon(Icons.album, size: 200),
              errorWidget: (context, url, error) => const Icon(Icons.album, size: 200),
            )
                : const Icon(Icons.album, size: 200),
            const SizedBox(height: 20),

            Text(
              _currentSong.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _currentSong.artist ?? 'Unknown',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            StreamBuilder<Duration>(
              stream: _audio.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                // ✅ Đảm bảo maxValue >= 1
                final double maxValue = _duration.inSeconds.toDouble() > 1 ? _duration.inSeconds.toDouble() : 1.0;
                final double safePosition = position.inSeconds.toDouble().clamp(0, maxValue);

                return Column(
                  children: [
                    Slider(
                      value: safePosition,
                      max: maxValue,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        _audio.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _togglePlaybackRate,
                  child: Text(
                    '${_playbackRate}x',
                    style: const TextStyle(color: Colors.cyan, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(_getRepeatIcon()),
                  onPressed: _toggleRepeat,
                  color: _audio.repeatMode != RepeatMode.none ? Colors.green : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: () => _changeSong(_currentIndex - 1),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 64),
                  color: Colors.blueAccent,
                  onPressed: () async {
                    if (_isPlaying) {
                      await _audio.pause();
                    } else {
                      final pos = _audio.currentPosition;
                      if (pos.inSeconds >= _duration.inSeconds && _duration.inSeconds > 0) {
                        await _audio.seek(Duration.zero);
                      }
                      await _audio.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: () => _changeSong(_currentIndex + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_play),
                  onPressed: _toggleAutoNext,
                  color: _audio.autoNext ? Colors.blue : Colors.grey,
                  tooltip: 'Tự động phát tiếp',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}