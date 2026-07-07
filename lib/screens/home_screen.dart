import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // ✅ Import cho PlayerState
import 'package:cached_network_image/cached_network_image.dart';
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

  // 🔄 Tải danh sách, kiểm tra file tồn tại
  Future<void> _loadSongs() async {
    final songs = await _db.getAllSongs();
    final validSongs = <Song>[];
    for (var song in songs) {
      final file = File(song.localPath);
      if (await file.exists()) {
        validSongs.add(song);
      } else {
        await _db.deleteSong(song.id!);
        debugPrint('Đã xóa bài "${song.title}" do file không tồn tại');
      }
    }
    if (mounted) {
      setState(() => _songs = validSongs);
    }
    _audio.updatePlaylist(validSongs);
  }

  // 📥 Xử lý đầu vào (link hay từ khóa)
  Future<void> _handleInput(String input) async {
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bài hát hoặc link YouTube')),
      );
      return;
    }
    if (input.contains('youtube.com') || input.contains('youtu.be')) {
      await _downloadAndSave(input);
    } else {
      await _searchAndShowBottomSheet(input);
    }
  }

  // 🔎 Tìm kiếm và hiển thị BottomSheet
  Future<void> _searchAndShowBottomSheet(String keyword) async {
    setState(() => _isLoading = true);
    try {
      final results = await _ytService.searchYoutube(keyword);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy bài hát nào.')),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final video = results[index];
              return ListTile(
                leading: CachedNetworkImage(
                  imageUrl: video['thumbnail'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Icon(Icons.music_note),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                ),
                title: Text(video['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(video['artist']),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadSingleVideo(video);
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar(e);
    }
  }

  // ⬇️ Tải một video đơn (từ kết quả tìm kiếm)
  Future<void> _downloadSingleVideo(Map<String, dynamic> video) async {
    setState(() => _isLoading = true);
    try {
      final path = await _ytService.downloadAudio(video['id'], video['title']);
      final song = Song(
        title: video['title'],
        localPath: path,
        artist: video['artist'],
        thumbnailUrl: video['thumbnail'],
      );
      await _db.insertSong(song);
      await _loadSongs();
      _urlController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tải thành công: ${video['title']}')),
      );
    } catch (e) {
      if (mounted) _showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📥 Tải từ link (hỗ trợ playlist)
  Future<void> _downloadAndSave(String url) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập link YouTube')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final downloaded = await _ytService.downloadPlaylist(
        url,
            (current, total) {
          debugPrint('Đã tải $current/$total');
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
      if (mounted) _showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🛑 Hiển thị lỗi đẹp
  void _showErrorSnackBar(dynamic error) {
    final message = error.toString().replaceAll('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 🔍 Tìm kiếm trong thư viện với debounce
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

  // 🗑️ Xóa bài: xác nhận + xóa file + cập nhật playlist
  Future<bool> _deleteSong(Song song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài hát'),
        content: Text('Bạn có chắc muốn xóa "${song.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    // 1. Xóa DB
    await _db.deleteSong(song.id!);

    // 2. Xóa file vật lý
    try {
      final file = File(song.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Lỗi xóa file: $e');
    }

    // 3. Lấy danh sách mới
    final newSongs = _songs.where((s) => s.id != song.id).toList();

    // 4. Xử lý nếu bài đang phát bị xóa
    final currentSong = _audio.currentSong;
    if (currentSong != null && currentSong.id == song.id) {
      if (newSongs.isNotEmpty) {
        await _audio.stop();
        _audio.updatePlaylist(newSongs);
        await _audio.play(newSongs[0]);
      } else {
        await _audio.stop();
        _audio.updatePlaylist([]);
      }
    } else {
      _audio.updatePlaylist(newSongs);
    }

    // 5. Cập nhật UI
    setState(() => _songs = newSongs);

    return true;
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
                          hintText: 'Nhập tên bài hát hoặc dán link YouTube...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        enabled: !_isLoading,
                        onSubmitted: _handleInput,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _isLoading ? null : () => _handleInput(_urlController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm trong thư viện...',
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
            itemBuilder: (ctx, i) {
              final song = _songs[i];
              return Dismissible(
                key: Key(song.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await _deleteSong(song);
                },
                child: SongItem(
                  song: song,
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
              );
            },
          ),
          _buildMiniPlayer(),
        ],
      ),
    );
  }

  // 🎵 Mini player
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
                      ? CachedNetworkImage(
                    imageUrl: thumbnail,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                    const Icon(Icons.music_note, color: Colors.white),
                    errorWidget: (context, url, error) =>
                    const Icon(Icons.music_note, color: Colors.white),
                  )
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
                    onPressed: () => _audio.next(),
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