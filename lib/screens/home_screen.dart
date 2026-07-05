import 'dart:async';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/db_service.dart';
import '../services/yt_service.dart';
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
    setState(() => _songs = songs);
  }

  Future<void> _downloadAndSave(String url) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập link YouTube')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final videos = await _ytService.fetchVideosFromLink(url);
      List<Song> downloaded = [];

      if (videos.length == 1) {
        final video = videos.first;
        final path = await _ytService.downloadAudio(video['id'], video['title']);
        final song = Song(
          title: video['title'],
          localPath: path,
          artist: video['artist'],
          thumbnailUrl: video['thumbnail'],
        );
        await _db.insertSong(song);
        downloaded = [song];
      } else {
        downloaded = await _ytService.downloadPlaylist(url, (current, total) {
          print('Đã tải $current/$total');
        });
        for (var song in downloaded) {
          await _db.insertSong(song);
        }
      }

      await _loadSongs();
      _urlController.clear();
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
        if (mounted) {
          setState(() => _songs = results);
        }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
          ? const Center(child: Text('Chưa có bài hát nào. Hãy tải từ YouTube!'))
          : ListView.builder(
        itemCount: _songs.length,
        itemBuilder: (ctx, i) => SongItem(
          song: _songs[i],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  songs: _songs,
                  initialIndex: i,
                ),
              ),
            );
          },
          onLongPress: () => _deleteSong(_songs[i]),
        ),
      ),
    );
  }
}