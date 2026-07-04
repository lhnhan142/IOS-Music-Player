import 'package:flutter/material.dart';
import '../services/yt_service.dart';
import '../services/db_service.dart';
import '../models/song.dart';
import '../widgets/song_item.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeService _ytService = YoutubeService();
  final DatabaseService _db = DatabaseService();
  List<Song> _songs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await _db.getAllSongs();
    setState(() {
      _songs = songs;
    });
  }

  Future<void> _downloadAndSave(String url) async {
    setState(() => _isLoading = true);
    try {
      final videos = await _ytService.fetchVideosFromLink(url);
      // Nếu chỉ có 1 video, tải đơn
      // Nếu có nhiều, tải playlist
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
        // Playlist
        downloaded = await _ytService.downloadPlaylist(url, (current, total) {
          // Có thể hiển thị progress
          print('Đã tải $current/$total');
        });
        for (var song in downloaded) {
          await _db.insertSong(song);
        }
      }
      await _loadSongs(); // refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) {
      await _loadSongs();
    } else {
      final results = await _db.searchSongs(keyword);
      setState(() {
        _songs = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Music'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Dán link YouTube...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.download),
                      onPressed: _isLoading ? null : () => _downloadAndSave(_urlController.text),
                    ),
                  ],
                ),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
        ),
      )
    );
  }
}