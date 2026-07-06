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
  RepeatMode _repeatMode = RepeatMode.none;
  bool _autoNext = true;
  bool _isStoppedByUser = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _audio.setPlaylist(widget.songs, _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audio.play(_currentSong);
    });

    _audio.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audio.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _audio.playerStateStream.listen((state) {
      if (mounted) {
        final wasPlaying = _isPlaying;
        setState(() => _isPlaying = state == PlayerState.playing);
        if (wasPlaying && state == PlayerState.stopped && !_isStoppedByUser) {
          _handleSongEnd();
        }
        if (state != PlayerState.stopped) {
          _isStoppedByUser = false;
        }
      }
    });
  }

  @override
  void dispose() {
    // Không dispose audio manager
    super.dispose();
  }

  Future<void> _handleSongEnd() async {
    if (_repeatMode == RepeatMode.one) {
      await _audio.play(_currentSong);
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
      await _audio.stop();
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
    await _audio.play(widget.songs[_currentIndex]);
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
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
              onChanged: (val) => _audio.seek(Duration(seconds: val.toInt())),
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