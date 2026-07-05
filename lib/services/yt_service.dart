import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/song.dart';

class YoutubeService {
  final yt = YoutubeExplode();

  Future<List<Map<String, dynamic>>> fetchVideosFromLink(String link) async {
    try {
      if (link.contains('list=')) {
        final playlist = await yt.playlists.get(link);
        final videos = await yt.playlists.getVideos(playlist.id).toList();
        return videos.map((video) {
          final thumbnailUrl = 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
          return {
            'id': video.id.value,
            'title': video.title,
            'artist': video.author,
            'thumbnail': thumbnailUrl,
          };
        }).toList();
      } else {
        final video = await yt.videos.get(link);
        final thumbnailUrl = 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
        return [
          {
            'id': video.id.value,
            'title': video.title,
            'artist': video.author,
            'thumbnail': thumbnailUrl,
          }
        ];
      }
    } catch (e) {
      print('Lỗi fetchVideosFromLink: $e');
      rethrow;
    }
  }

  Future<String> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');

      // Luôn lưu dưới dạng .mp4 tiêu chuẩn
      String filePath = '${dir.path}/$safeTitle.mp4';
      File file = File(filePath);

      // Xóa file cũ nếu tồn tại (tránh dùng file hỏng)
      if (await file.exists()) {
        await file.delete();
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      // GIẢI PHÁP: Sử dụng luồng muxed (Audio + Video) thay vì audioOnly.
      // Trình phát sẽ đọc file mp4 này như một file nhạc bình thường.
      // Dùng withLowestBitrate() để chọn chất lượng hình ảnh thấp nhất -> file nhẹ nhất.
      final muxedStreams = manifest.muxed.toList();
      if (muxedStreams.isEmpty) {
        throw Exception('Không có luồng muxed (video + audio)');
      }
      muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxedStreams.first; // bitrate thấp nhất → file nhẹ

      if (streamInfo == null) {
        throw Exception('Không tìm thấy luồng âm thanh tiêu chuẩn');
      }

      print('Đang tải luồng tiêu chuẩn: ${streamInfo.bitrate} kbps, định dạng: ${streamInfo.container}');

      // Tiến hành tải và ghi vào bộ nhớ
      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = file.openWrite();
      await stream.pipe(sink);
      await sink.close();

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File rỗng, tải thất bại');
      }

      print('✅ Tải thành công: $filePath, Kích thước: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      return filePath;
    } catch (e) {
      print('Lỗi downloadAudio: $e');
      rethrow;
    }
  }

  Future<List<Song>> downloadPlaylist(String link, Function(int, int) onProgress) async {
    try {
      final videos = await fetchVideosFromLink(link);
      List<Song> downloadedSongs = [];
      int total = videos.length;

      for (int i = 0; i < total; i++) {
        final video = videos[i];
        try {
          final localPath = await downloadAudio(video['id'], video['title']);
          final song = Song(
            title: video['title'],
            localPath: localPath,
            artist: video['artist'],
            thumbnailUrl: video['thumbnail'],
          );
          downloadedSongs.add(song);
          onProgress(i + 1, total);
        } catch (e) {
          print('Lỗi tải bài ${video['title']}: $e');
        }
        if (i < total - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      return downloadedSongs;
    } catch (e) {
      print('Lỗi downloadPlaylist: $e');
      rethrow;
    }
  }

  void dispose() {
    yt.close();
  }
}