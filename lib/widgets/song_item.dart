import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';

class SongItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isDownloading;
  final double progress;
  final String downloadSizeInfo;
  final VoidCallback? onCancelDownload;

  const SongItem({
    Key? key,
    required this.song,
    required this.onTap,
    this.isDownloading = false,
    this.progress = 0.0,
    this.downloadSizeInfo = '',
    this.onCancelDownload,
  }) : super(key: key);

  // ✅ Hàm format dung lượng
  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Xây dựng subtitle: artist + dung lượng
    String subtitle = '';
    if (isDownloading) {
      subtitle = 'Đang tải... ${(progress * 100).toInt().clamp(0, 100)}% ${downloadSizeInfo.isNotEmpty ? "($downloadSizeInfo)" : ""}';
    } else {
      final artist = song.artist ?? 'Unknown';
      final sizeText = _formatFileSize(song.fileSize);
      subtitle = sizeText.isNotEmpty ? '$artist · $sizeText' : artist;
    }

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: isDownloading ? 0.3 : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: song.thumbnailUrl != null
                  ? CachedNetworkImage(
                imageUrl: song.thumbnailUrl!,
                width: 50,
                height: 50,
                memCacheWidth: 150,
                memCacheHeight: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Icon(Icons.music_note),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              )
                  : Container(
                width: 50,
                height: 50,
                color: Colors.grey,
                child: const Icon(Icons.music_note),
              ),
            ),
          ),
          if (isDownloading) ...[
            CircularProgressIndicator(
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              strokeWidth: 3,
              color: Colors.greenAccent,
            ),
            Text(
              progress >= 0 ? '${(progress * 100).toInt().clamp(0, 100)}%' : '',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
      title: Text(
        song.title,
        style: TextStyle(color: isDownloading ? Colors.grey : Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isDownloading ? Colors.grey[600] : Colors.grey[400]),
      ),
      onTap: isDownloading ? null : onTap,
      trailing: isDownloading
          ? IconButton(
        icon: const Icon(Icons.close, color: Colors.redAccent),
        onPressed: onCancelDownload,
      )
          : IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }
}