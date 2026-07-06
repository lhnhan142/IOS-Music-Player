import 'package:flutter/material.dart';
import '../models/song.dart';

class SongItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SongItem({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: song.thumbnailUrl != null
          ? Image.network(song.thumbnailUrl!, width: 50, height: 50)
          : const Icon(Icons.music_note),
      title: Text(song.title),
      subtitle: Text(song.artist ?? 'Unknown'),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }
}