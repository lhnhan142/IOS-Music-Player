import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';

class SongItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isDownloading;
  final double progress;

  const SongItem({
    Key? key,
    required this.song,
    required this.onTap,
    this.isDownloading = false,
    this.progress = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              // ✅ Clamp để tránh giá trị > 1.0 gây lỗi sọc vàng đen
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              strokeWidth: 3,
              color: Colors.greenAccent,
            ),
            Text(
              '${(progress * 100).toInt().clamp(0, 100)}%',
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
        isDownloading
            ? 'Đang tải... ${(progress * 100).toInt().clamp(0, 100)}%'
            : (song.artist ?? 'Unknown'),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: isDownloading ? null : onTap,
      trailing: isDownloading
          ? const SizedBox(width: 48)
          : IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }
}