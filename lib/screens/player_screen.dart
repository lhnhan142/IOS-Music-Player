import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
  late AudioPlayerManager _audioManager;
  late int _currentIndex;
  Song get _currentSong => widget.songs[_currentIndex];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioPlayerManager();
    _currentIndex = widget.initialIndex;

    _audioManager.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioManager.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _audioManager.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrent();
    });
  }

  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }

  Future<void> _playCurrent() async {
    await _audioManager.play(_currentSong.localPath);
  }

  Future<void> _changeSong(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.songs.length) return;
    setState(() {
      _currentIndex = newIndex;
    });
    await _playCurrent();
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
                ? Image.network(
              _currentSong.thumbnailUrl!,
              height: 200,
              fit: BoxFit.cover,
            )
                : const Icon(Icons.album, size: 200),
            const SizedBox(height: 20),
            Text(_currentSong.title, style: const TextStyle(fontSize: 20)),
            Text(_currentSong.artist ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble() > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                _audioManager.seek(Duration(seconds: val.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _changeSong(_currentIndex - 1),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40),
                  onPressed: () async {
                    if (_isPlaying) {
                      await _audioManager.pause();
                    } else {
                      await _audioManager.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _changeSong(_currentIndex + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}