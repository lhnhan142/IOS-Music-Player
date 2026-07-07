import 'dart:async';
import 'dart:io';
import 'dart:developer'; // cho debugPrint
import 'package:flutter/cupertino.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class YoutubeService {
  final yt = YoutubeExplode();

  // 🔍 Tìm kiếm
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

  // 📋 Lấy video từ link
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

  // ⬇️ Tải audio với callback tiến độ
  Future<String> downloadAudio(
      String videoId,
      String title, {
        Function(double)? onProgress,
      }) async {
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

      return await _downloadStream(streamInfo, filePath, onProgress: onProgress);
    } on SocketException catch (_) {
      throw Exception('Đã mất kết nối mạng trong quá trình tải.');
    } on TimeoutException catch (_) {
      throw Exception('Mạng quá chậm, quá trình tải bị gián đoạn.');
    } catch (e) {
      throw Exception('Lỗi tải nhạc: $e');
    }
  }

  // Hàm ghi stream với tính năng tiến độ
  Future<String> _downloadStream(
      StreamInfo streamInfo,
      String filePath, {
        Function(double)? onProgress,
      }) async {
    final file = File(filePath);
    final stream = yt.videos.streamsClient.get(streamInfo);
    final sink = file.openWrite();

    // ✅ Sửa lỗi: dùng totalBytes thay vì bytes
    final totalBytes = streamInfo.size?.totalBytes ?? 0;
    int downloadedBytes = 0;

    await for (final data in stream) {
      downloadedBytes += data.length;
      sink.add(data);
      if (totalBytes > 0 && onProgress != null) {
        final progress = downloadedBytes / totalBytes;
        onProgress(progress.clamp(0.0, 1.0));
      }
    }

    await sink.close();
    final size = await file.length();
    if (size == 0) {
      throw Exception('File tải về rỗng.');
    }
    return filePath;
  }

  // 📦 Tải playlist (giữ nguyên, không có progress chi tiết)
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
        debugPrint('Lỗi tải bài ${v['title']}: $e');
      }
      if (i < total - 1) await Future.delayed(const Duration(seconds: 2));
    }
    return downloaded;
  }

  void dispose() {
    yt.close();
  }
}