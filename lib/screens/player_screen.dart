import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart' as cached;
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

  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  RepeatMode _repeatMode = RepeatMode.none;
  bool _autoNext = true;
  bool _isStoppedByUser = false;

  // ✅ Thêm biến tốc độ phát
  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (_audio.playlist == null || _audio.playlist!.isEmpty) {
      _audio.setPlaylist(widget.songs, _currentIndex);
    }

    _audio.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _audio.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
        if (state != PlayerState.stopped && state != PlayerState.completed) {
          _isStoppedByUser = false;
        }
      }
    });

    _audio.playerCompleteStream.listen((_) {
      if (mounted && !_isStoppedByUser) {
        _handleSongEnd();
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
        if (index != -1) {
          setState(() => _currentIndex = index);
        }
      }
      return;
    }

    if (_autoNext) {
      await _audio.next();
      final newSong = _audio.currentSong;
      if (newSong != null) {
        final index = widget.songs.indexOf(newSong);
        if (index != -1) {
          setState(() => _currentIndex = index);
        }
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

  void _toggleAutoNext() => setState(() => _autoNext = !_autoNext);

  void _toggleRepeat() {
    setState(() {
      if (_repeatMode == RepeatMode.none) {
        _repeatMode = RepeatMode.one;
      } else if (_repeatMode == RepeatMode.one) {
        _repeatMode = RepeatMode.all;
      } else {
        _repeatMode = RepeatMode.none;
      }
    });
  }

  // ✅ Hàm chọn tốc độ
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

  IconData _getRepeatIcon() {
    switch (_repeatMode) {
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
                ? cached.CachedNetworkImage(
              imageUrl: _currentSong.thumbnailUrl!,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Icon(Icons.album, size: 200),
              errorWidget: (context, url, error) => const Icon(Icons.album, size: 200),
            )
                : const Icon(Icons.album, size: 200),
            const SizedBox(height: 20),
            Text(_currentSong.title, style: const TextStyle(fontSize: 20)),
            Text(_currentSong.artist ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            StreamBuilder<Duration>(
              stream: _audio.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      value: position.inSeconds.toDouble().clamp(0, maxValue),
                      max: maxValue,
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

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Nút tốc độ phát
                TextButton(
                  onPressed: _togglePlaybackRate,
                  child: Text(
                    '${_playbackRate}x',
                    style: const TextStyle(color: Colors.cyan, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_getRepeatIcon()),
                  onPressed: _toggleRepeat,
                  color: _repeatMode != RepeatMode.none ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _changeSong(_currentIndex - 1),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                  onPressed: () async {
                    if (_isPlaying) {
                      _isStoppedByUser = true;
                      await _audio.pause();
                    } else {
                      _isStoppedByUser = false;
                      final pos = _audio.currentPosition;
                      if (pos.inSeconds >= _duration.inSeconds && _duration.inSeconds > 0) {
                        await _audio.seek(Duration.zero);
                      }
                      await _audio.resume();
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _changeSong(_currentIndex + 1),
                ),
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