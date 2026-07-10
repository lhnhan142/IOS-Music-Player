import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/audio_manager.dart';

// ✅ Không cần import RepeatMode từ material vì đã dùng LoopMode

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
  double _playbackRate = 1.0;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _position = _audio.currentPosition;
    _duration = _audio.currentDuration;

    if (_audio.playlist == null || _audio.playlist!.isEmpty) {
      _audio.setPlaylist(widget.songs, _currentIndex);
    }

    _positionSub = _audio.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = _audio.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _stateSub = _audio.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _completeSub = _audio.playerCompleteStream.listen((_) {
      if (mounted) {
        final newSong = _audio.currentSong;
        if (newSong != null) {
          final index = widget.songs.indexOf(newSong);
          if (index != -1) setState(() => _currentIndex = index);
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
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  Future<void> _changeSong(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.songs.length) {
      if (_audio.loopMode == LoopMode.all) {
        if (newIndex < 0) {
          newIndex = widget.songs.length - 1;
        } else if (newIndex >= widget.songs.length) {
          newIndex = 0;
        }
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

  void _toggleLoop() {
    setState(() {
      if (_audio.loopMode == LoopMode.none) {
        _audio.setLoopMode(LoopMode.one);
      } else if (_audio.loopMode == LoopMode.one) {
        _audio.setLoopMode(LoopMode.all);
      } else {
        _audio.setLoopMode(LoopMode.none);
      }
    });
  }

  void _togglePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.25;
      } else if (_playbackRate == 1.25) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else if (_playbackRate == 2.0) {
        _playbackRate = 0.75;
      } else {
        _playbackRate = 1.0;
      }
      _audio.setPlaybackRate(_playbackRate);
    });
  }

  IconData _getLoopIcon() {
    switch (_audio.loopMode) {
      case LoopMode.none:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
      case LoopMode.all:
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
    // ✅ Sửa lỗi: dùng 0.0 thay vì 0 để clamp trả về double trực tiếp
    final double maxValue = _duration.inSeconds.toDouble() > 1 ? _duration.inSeconds.toDouble() : 1.0;
    final double safePosition = _position.inSeconds.toDouble().clamp(0.0, maxValue);

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
                final safePos = position.inSeconds.toDouble().clamp(0.0, maxValue);

                return Column(
                  children: [
                    Slider(
                      value: safePos,
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
                  icon: Icon(_getLoopIcon()),
                  onPressed: _toggleLoop,
                  color: _audio.loopMode != LoopMode.none ? Colors.green : Colors.grey,
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
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Loop: ${_audio.loopMode.name}  |  AutoNext: ${_audio.autoNext ? 'ON' : 'OFF'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}