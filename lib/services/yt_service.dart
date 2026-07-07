import 'dart:async';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class YoutubeService {
  final yt = YoutubeExplode();

  // 🔍 Tìm kiếm từ khóa
  Future<List<Map<String, dynamic>>> searchYoutube(String query) async {
    try {
      final searchResults = await yt.search.search(query).timeout(const Duration(seconds: 15));
      final topResults = searchResults.take(5).toList();

      return topResults.map((video) {
        return {
          'id': video.id.value,
          'title': video.title,
          'artist': video.author,
          'thumbnail': 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg',
        };
      }).toList();
    } on SocketException catch (_) {
      throw Exception('Không có kết nối internet. Vui lòng kiểm tra lại mạng.');
    } on TimeoutException catch (_) {
      throw Exception('Kết nối mạng quá yếu. Đã hết thời gian chờ.');
    } catch (e) {
      throw Exception('Lỗi hệ thống: $e');
    }
  }

  // 📋 Lấy danh sách video từ link (hỗ trợ video đơn hoặc playlist)
  Future<List<Map<String, dynamic>>> fetchVideosFromLink(String link) async {
    try {
      if (link.contains('list=')) {
        final playlist = await yt.playlists.get(link).timeout(const Duration(seconds: 15));
        final videos = await yt.playlists.getVideos(playlist.id).toList().timeout(const Duration(seconds: 30));
        return videos.map((video) {
          return {
            'id': video.id.value,
            'title': video.title,
            'artist': video.author,
            'thumbnail': 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg',
          };
        }).toList();
      } else {
        final video = await yt.videos.get(link).timeout(const Duration(seconds: 15));
        return [
          {
            'id': video.id.value,
            'title': video.title,
            'artist': video.author,
            'thumbnail': 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg',
          }
        ];
      }
    } on SocketException catch (_) {
      throw Exception('Không có kết nối internet. Vui lòng kiểm tra lại mạng.');
    } on TimeoutException catch (_) {
      throw Exception('Kết nối mạng quá yếu. Đã hết thời gian chờ.');
    } catch (e) {
      throw Exception('Lỗi hệ thống: $e');
    }
  }

  // ⬇️ Tải một bài hát (dùng muxed stream)
  Future<String> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final filePath = '${dir.path}/$safeTitle.mp4';
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20));
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isEmpty) {
        throw Exception('Không tìm thấy luồng muxed cho video này.');
      }
      muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxedStreams.first;

      return await _downloadStream(streamInfo, filePath);
    } on SocketException catch (_) {
      throw Exception('Đã mất kết nối mạng trong quá trình tải.');
    } on TimeoutException catch (_) {
      throw Exception('Mạng quá chậm, quá trình tải bị gián đoạn.');
    } catch (e) {
      throw Exception('Lỗi tải nhạc: $e');
    }
  }

  // Hàm ghi stream vào file
  Future<String> _downloadStream(StreamInfo streamInfo, String filePath) async {
    final file = File(filePath);
    final stream = yt.videos.streamsClient.get(streamInfo);
    final sink = file.openWrite();
    await stream.pipe(sink);
    await sink.close();
    final size = await file.length();
    if (size == 0) {
      throw Exception('File tải về rỗng.');
    }
    return filePath;
  }

  // 📦 Tải playlist (tuần tự)
  Future<List<Song>> downloadPlaylist(String link, Function(int, int) onProgress) async {
    final videos = await fetchVideosFromLink(link);
    final List<Song> downloaded = [];
    int total = videos.length;
    for (int i = 0; i < total; i++) {
      final v = videos[i];
      try {
        final path = await downloadAudio(v['id'], v['title']);
        downloaded.add(Song(
          title: v['title'],
          localPath: path,
          artist: v['artist'],
          thumbnailUrl: v['thumbnail'],
        ));
        onProgress(i + 1, total);
      } catch (e) {
        print('Lỗi tải bài ${v['title']}: $e');
      }
      if (i < total - 1) await Future.delayed(const Duration(seconds: 2));
    }
    return downloaded;
  }

  void dispose() {
    yt.close();
  }
}