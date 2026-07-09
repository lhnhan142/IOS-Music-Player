import 'dart:async';
import 'dart:io';
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
        bool Function()? isCancelled,
      }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final filePath = '${dir.path}/$safeTitle.mp4';
      final file = File(filePath);

      // ✅ ĐÃ FIX LỖI 0:00 TẠI ĐÂY: Kiểm tra file rỗng
      if (await file.exists()) {
        if (await file.length() > 0) {
          return filePath;
        } else {
          await file.delete(); // Xóa file lỗi cũ để tải lại
        }
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20));
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isEmpty) {
        throw Exception('Không tìm thấy luồng muxed cho video này.');
      }
      muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxedStreams.first;

      return await _downloadStream(streamInfo, filePath, onProgress: onProgress, isCancelled: isCancelled);
    } on SocketException catch (_) {
      throw Exception('Đã mất kết nối mạng trong quá trình tải.');
    } on TimeoutException catch (_) {
      throw Exception('Mạng quá chậm, quá trình tải bị gián đoạn.');
    } catch (e) {
      throw Exception('Lỗi tải nhạc: $e');
    }
  }

  // 🧠 Hàm ghi stream với tính năng tiến độ (có throttle + idle timeout detection)
  Future<String> _downloadStream(
      StreamInfo streamInfo,
      String filePath, {
        Function(double)? onProgress,
        bool Function()? isCancelled,
      }) async {
    // Download to temp file
    final tempFile = File('$filePath.tmp');
    final file = File(filePath);
    final stream = yt.videos.streamsClient.get(streamInfo);
    final sink = tempFile.openWrite();

    final totalBytes = streamInfo.size?.totalBytes ?? 0;
    int downloadedBytes = 0;
    int lastPercentage = -1;
    DateTime lastChunkTime = DateTime.now();
    final idleTimeout = const Duration(seconds: 30); // Phát hiện mạng bị đứng

    try {
      await for (final data in stream) {
        // Kiểm tra nếu bị hủy
        if (isCancelled != null && isCancelled()) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Đã hủy tải.');
        }

        // Kiểm tra idle timeout (nếu không nhận dữ liệu trong 30 giây)
        final now = DateTime.now();
        if (now.difference(lastChunkTime) > idleTimeout) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Kết nối bị mất, không nhận được dữ liệu trong 30 giây.');
        }
        lastChunkTime = now;

        downloadedBytes += data.length;
        sink.add(data);

        if (totalBytes > 0 && onProgress != null) {
          final progress = downloadedBytes / totalBytes;
          final percentage = (progress * 100).toInt();

          // ✅ Chỉ gọi update UI khi % thực sự tăng lên (throttle)
          if (percentage > lastPercentage) {
            lastPercentage = percentage;
            onProgress(progress.clamp(0.0, 1.0));
          }
        }
      }

      await sink.close();
      final size = await tempFile.length();
      if (size == 0) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('File tải về rỗng.');
      }

      // Rename temp file to actual file when download is complete
      await tempFile.rename(filePath);
      return filePath;
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) await tempFile.delete();
      rethrow;
    }
  }

  // 📦 Tải playlist
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