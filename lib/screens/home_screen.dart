import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/db_service.dart';
import '../services/yt_service.dart';
import '../services/audio_manager.dart';
import '../services/download_manager.dart';
import '../widgets/song_item.dart';
import 'player_screen.dart';

enum SortOption { newest, oldest, nameAsc, nameDesc }

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
  SortOption _currentSort = SortOption.newest;

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

  void _applySort() {
    setState(() {
      switch (_currentSort) {
        case SortOption.nameAsc:
          _songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case SortOption.nameDesc:
          _songs.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
          break;
        case SortOption.newest:
          _songs.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          break;
        case SortOption.oldest:
          _songs.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
          break;
      }
    });
    _audio.updatePlaylist(_songs);
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
        debugPrint('Đã xóa bài "${song.title}" do file không tồn tại');
      }
    }
    if (mounted) {
      setState(() => _songs = validSongs);
      _applySort();
    }
    _audio.updatePlaylist(validSongs);
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
          _applySort();
        }
      }
    });
  }

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

    await _db.deleteSong(song.id!);
    try {
      final file = File(song.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Lỗi xóa file: $e');
    }

    final newSongs = _songs.where((s) => s.id != song.id).toList();
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
    setState(() => _songs = newSongs);
    _applySort();
    return true;
  }

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

  Future<void> _handleInput(String input) async {
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bài hát hoặc link YouTube')),
      );
      return;
    }
    if (input.contains('youtube.com') || input.contains('youtu.be')) {
      await _fetchAndShowPlaylist(input);
    } else {
      await _searchAndShowBottomSheet(input);
    }
  }

  // 🔎 Tìm kiếm và hiển thị BottomSheet (kết quả từ khóa)
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
                  memCacheWidth: 150,
                  memCacheHeight: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Icon(Icons.music_note),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                ),
                title: Text(video['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(video['artist']),
                onTap: () {
                  Navigator.pop(ctx);
                  final downloadManager = Provider.of<DownloadManager>(context, listen: false);
                  downloadManager.downloadVideo(
                    video,
                    onSuccess: () => _loadSongs(),
                    onError: (error) => _showErrorSnackBar(error),
                  );
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

  // 📋 Lấy danh sách video từ link và mở BottomSheet chọn bài
  Future<void> _fetchAndShowPlaylist(String url) async {
    setState(() => _isLoading = true);
    try {
      final videos = await _ytService.fetchVideosFromLink(url);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (videos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy bài hát nào từ link này.')),
        );
        return;
      }

      _showPlaylistSelectionBottomSheet(videos);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar(e);
    }
  }

  void _showPlaylistSelectionBottomSheet(List<Map<String, dynamic>> videos) {
    List<bool> selected = List<bool>.filled(videos.length, true);
    bool selectAll = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final selectedCount = selected.where((e) => e).length;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chọn bài hát ($selectedCount/${videos.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            const Text('Tất cả'),
                            Checkbox(
                              value: selectAll,
                              activeColor: Colors.greenAccent,
                              onChanged: (val) {
                                setModalState(() {
                                  selectAll = val ?? false;
                                  for (int i = 0; i < selected.length; i++) {
                                    selected[i] = selectAll;
                                  }
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView.builder(
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return CheckboxListTile(
                          value: selected[index],
                          activeColor: Colors.greenAccent,
                          onChanged: (val) {
                            setModalState(() {
                              selected[index] = val ?? false;
                              selectAll = !selected.contains(false);
                            });
                          },
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: video['thumbnail'],
                              width: 50,
                              height: 50,
                              memCacheWidth: 150,
                              memCacheHeight: 150,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Icon(Icons.music_note),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                            ),
                          ),
                          title: Text(
                            video['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            video['artist'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: selectedCount == 0
                          ? null
                          : () {
                        Navigator.pop(ctx);
                        _downloadSelectedVideos(videos, selected);
                      },
                      child: Text(
                        'Tải $selectedCount bài hát',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _downloadSelectedVideos(List<Map<String, dynamic>> videos, List<bool> selected) {
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    int addedCount = 0;

    for (int i = 0; i < videos.length; i++) {
      if (selected[i]) {
        addedCount++;
        downloadManager.downloadVideo(
          videos[i],
          onSuccess: () => _loadSongs(),
          onError: (error) => _showErrorSnackBar(error),
        );
      }
    }

    if (addedCount > 0) {
      _urlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đẩy $addedCount bài hát vào hàng đợi tải ngầm.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sắp xếp',
            onSelected: (SortOption result) {
              _currentSort = result;
              _applySort();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.newest,
                child: Text('Mới thêm nhất'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.oldest,
                child: Text('Cũ nhất'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.nameAsc,
                child: Text('Tên (A-Z)'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.nameDesc,
                child: Text('Tên (Z-A)'),
              ),
            ],
          ),
        ],
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
                        decoration: InputDecoration(
                          hintText: 'Nhập tên bài hát hoặc dán link YouTube...',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _urlController.clear(),
                          ),
                        ),
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
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm trong thư viện...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                        _searchFocusNode.unfocus();
                      },
                    ),
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
              : Consumer<DownloadManager>(
            builder: (context, downloadManager, child) {
              final downloadingTasks = downloadManager.tasks.values.toList();
              final totalItems = downloadingTasks.length + _songs.length;

              if (totalItems == 0) {
                return const Center(child: Text('Chưa có bài hát nào. Hãy tải từ YouTube!'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: totalItems,
                itemBuilder: (ctx, i) {
                  if (i < downloadingTasks.length) {
                    final task = downloadingTasks[i];
                    final fakeSong = Song(
                      title: task.videoData['title'],
                      localPath: '',
                      artist: task.videoData['artist'],
                      thumbnailUrl: task.videoData['thumbnail'],
                    );

                    // ✅ Dùng ListenableBuilder để chỉ rebuild task này
                    return ListenableBuilder(
                      listenable: task,
                      builder: (context, child) {
                        return IgnorePointer(
                          ignoring: true,
                          child: SongItem(
                            song: fakeSong,
                            isDownloading: true,
                            progress: task.progress,
                            onTap: () {},
                          ),
                        );
                      },
                    );
                  } else {
                    final song = _songs[i - downloadingTasks.length];
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
                        isDownloading: false,
                        progress: 0.0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                songs: _songs,
                                initialIndex: i - downloadingTasks.length,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              );
            },
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
                      ? CachedNetworkImage(
                    imageUrl: thumbnail,
                    width: 50,
                    height: 50,
                    memCacheWidth: 150,
                    memCacheHeight: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.music_note, color: Colors.white),
                    errorWidget: (context, url, error) => const Icon(Icons.music_note, color: Colors.white),
                  )
                      : const Icon(Icons.music_note, size: 50, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
                        Text(artist, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      if (isPlaying) _audio.pause();
                      else _audio.resume();
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