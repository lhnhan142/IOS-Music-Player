import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/db_service.dart';
import '../services/yt_service.dart';
import '../services/audio_manager.dart';
import '../widgets/song_item.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final YoutubeService _ytService = YoutubeService();
  final DatabaseService _db = DatabaseService();
  final AudioManager _audio = AudioManager();
  List<Song> _songs = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _ytService.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final songs = await _db.getAllSongs();
    final validSongs = <Song>[];
    for (var song in songs) {
      final file = File(song.localPath);
      if (await file.exists()) {
        validSongs.add(song);
      } else {
        await _db.deleteSong(song.id!);
        print('Xóa bài ${song.title} do file không tồn tại');
      }
    }
    if (mounted) setState(() => _songs = validSongs);
  }

  Future<void> _downloadAndSave(String url) async {
    if (url.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập link YouTube')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final downloaded = await _ytService.downloadPlaylist(
        url,
            (current, total) {
          print('Đã tải $current/$total');
        },
      );

      for (var song in downloaded) {
        await _db.insertSong(song);
      }
      await _loadSongs();
      _urlController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tải ${downloaded.length} bài thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String keyword) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (keyword.isEmpty) {
        await _loadSongs();
      } else {
        final results = await _db.searchSongs(keyword);
        if (mounted) setState(() => _songs = results);
      }
    });
  }

  Future<void> _deleteSong(Song song) async {
    await _db.deleteSong(song.id!);
    await _loadSongs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'Dán link YouTube...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        enabled: !_isLoading,
                        onSubmitted: (value) => _downloadAndSave(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _isLoading ? null : () => _downloadAndSave(_urlController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _songs.isEmpty
              ? const Center(child: Text('Chưa có bài hát nào. Hãy tải từ YouTube!'))
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _songs.length,
            itemBuilder: (ctx, i) => SongItem(
              song: _songs[i],
              onTap: () {
                if (_audio.hasSong && _audio.playlist != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        songs: _audio.playlist!,
                        initialIndex: _audio.currentIndex,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        songs: _songs,
                        initialIndex: i,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () => _deleteSong(_songs[i]),
            ),
          ),
          _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<PlayerState>(
      stream: _audio.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || state == PlayerState.stopped || !_audio.hasSong) {
          return const SizedBox.shrink();
        }

        final isPlaying = state == PlayerState.playing;
        final title = _audio.title ?? '';
        final artist = _audio.artist ?? '';
        final thumbnail = _audio.thumbnail;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              if (_audio.hasSong && _audio.playlist != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      songs: _audio.playlist!,
                      initialIndex: _audio.currentIndex,
                    ),
                  ),
                );
              } else {
                if (_songs.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        songs: _songs,
                        initialIndex: 0,
                      ),
                    ),
                  );
                }
              }
            },
            child: Container(
              height: 70,
              color: Colors.black87,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  thumbnail != null
                      ? Image.network(thumbnail, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.music_note, size: 50, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          artist,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      if (isPlaying) {
                        _audio.pause();
                      } else {
                        _audio.resume();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {
                      _audio.next();
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}