import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/song.dart';

class YoutubeService {
  final yt = YoutubeExplode();

  // Lấy danh sách video từ link (hỗ trợ video đơn hoặc playlist)
  Future<List<Map<String, dynamic>>> fetchVideosFromLink(String link) async {
    try {
      // Kiểm tra nếu là playlist
      if (link.contains('list=')) {
        final playlist = await yt.playlists.get(link);
        // getVideos trả về Stream<Video>, dùng toList() để chờ tất cả
        final videos = await yt.playlists.getVideos(playlist.id).toList();
        return videos.map((video) {
          // Tạo URL thumbnail từ videoId (luôn có sẵn, không phụ thuộc ThumbnailSet)
          final thumbnailUrl = 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
          return {
            'id': video.id.value,
            'title': video.title,
            'artist': video.author,
            'thumbnail': thumbnailUrl,
          };
        }).toList();
      } else {
        // Video đơn
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

  // Tải audio của một video, lưu vào thư mục Documents, trả về đường dẫn file
  Future<String> downloadAudio(String videoId, String title) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Tạo tên file an toàn
      String safeTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final filePath = '${dir.path}/$safeTitle.m4a';
      final file = File(filePath);

      // Nếu file đã tồn tại, trả về luôn
      if (await file.exists()) {
        return filePath;
      }

      // Lấy manifest và chọn luồng âm thanh tốt nhất
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      // withHighestBitrate có thể trả về null, vẫn giữ kiểm tra
      if (audioStreamInfo == null) {
        throw Exception('Không tìm thấy luồng âm thanh cho video $videoId');
      }

      // Tải về
      final stream = yt.videos.streamsClient.get(audioStreamInfo);
      final fileStream = file.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      return filePath;
    } catch (e) {
      print('Lỗi downloadAudio: $e');
      rethrow;
    }
  }

  // Tải toàn bộ playlist (có delay 2s giữa các bài)
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
        // Nghỉ 2 giây trước bài tiếp theo (trừ bài cuối)
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

  // Đóng client khi không dùng
  void dispose() {
    yt.close();
  }
}