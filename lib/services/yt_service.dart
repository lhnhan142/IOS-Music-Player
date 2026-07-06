import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/song.dart';

class YoutubeService {
  final yt = YoutubeExplode();

  // Lấy danh sách video từ link (hỗ trợ video đơn hoặc playlist)
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
    } on TimeoutException catch (_) {
      throw Exception('Kết nối quá chậm, vui lòng thử lại sau.');
    } catch (e) {
      print('Lỗi fetchVideosFromLink: $e');
      rethrow;
    }
  }

  // Tải một bài hát: lấy muxed (video+audio) để có container MP4 chắc chắn
  Future<String> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final filePath = '${dir.path}/$safeTitle.mp4';
      final file = File(filePath);

      if (await file.exists()) {
        print('File đã tồn tại: $filePath');
        return filePath;
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 20));

      // Lấy luồng muxed (video + audio) – luôn có container MP4
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isEmpty) {
        // Fallback: audioOnly
        final audioOnly = manifest.audioOnly.withHighestBitrate();
        if (audioOnly == null) throw Exception('Không tìm thấy luồng audio');
        print('Fallback dùng audioOnly: container=${audioOnly.container}');
        return await _downloadStream(audioOnly, filePath);
      }

      // Sắp xếp theo bitrate tăng dần, chọn luồng thấp nhất để file nhẹ
      muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxedStreams.first;
      print('Đang tải muxed: ${streamInfo.bitrate} kbps, container: ${streamInfo.container}');
      return await _downloadStream(streamInfo, filePath);
    } catch (e) {
      print('Lỗi downloadAudio: $e');
      rethrow;
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
    if (size == 0) throw Exception('File rỗng');
    return filePath;
  }

  // Tải playlist (tuần tự, mỗi bài cách nhau 2 giây)
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