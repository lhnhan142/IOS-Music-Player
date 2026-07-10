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

  // ⬇️ Tải audio ổn định với luồng Muxed và tính MB
  Future<String> downloadAudio(
      String videoId,
      String title, {
        Function(double, String)? onProgress,
        bool Function()? isCancelled,
      }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final filePath = '${dir.path}/$safeTitle.mp4';
      final file = File(filePath);

      // Chống file rỗng gây lỗi 0:00
      if (await file.exists()) {
        if (await file.length() > 0) {
          return filePath;
        } else {
          await file.delete();
        }
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20));
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isEmpty) {
        throw Exception('Không tìm thấy luồng dữ liệu cho video này.');
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

  // 🧠 Hàm ghi stream với tính năng tiến độ MB và Timeout
  Future<String> _downloadStream(
      StreamInfo streamInfo,
      String filePath, {
        Function(double, String)? onProgress,
        bool Function()? isCancelled,
      }) async {
    final tempFile = File('$filePath.tmp');
    final stream = yt.videos.streamsClient.get(streamInfo);
    final sink = tempFile.openWrite();

    final totalBytes = streamInfo.size.totalBytes;
    int downloadedBytes = 0;
    int lastPercentage = -1;
    DateTime lastChunkTime = DateTime.now();
    final idleTimeout = const Duration(seconds: 30);

    try {
      await for (final data in stream) {
        // Hủy tải nếu người dùng nhấn X
        if (isCancelled != null && isCancelled()) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Đã hủy tải.');
        }

        // Chống kẹt 0%
        final now = DateTime.now();
        if (now.difference(lastChunkTime) > idleTimeout) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          throw Exception('Kết nối bị mất, không nhận được dữ liệu trong 30 giây.');
        }
        lastChunkTime = now;

        downloadedBytes += data.length;
        sink.add(data);

        // Tính % và MB
        if (totalBytes > 0 && onProgress != null) {
          final progress = downloadedBytes / totalBytes;
          final percentage = (progress * 100).toInt();

          if (percentage > lastPercentage) {
            lastPercentage = percentage;

            final downloadedMB = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            final sizeInfo = '${downloadedMB}MB / ${totalMB}MB';

            onProgress(progress.clamp(0.0, 1.0), sizeInfo);
          }
        }
      }

      await sink.close();
      final size = await tempFile.length();
      if (size == 0) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('File tải về rỗng.');
      }

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