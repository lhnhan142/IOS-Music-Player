import 'package:flutter/material.dart';
import '../models/song.dart';

class SongItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const SongItem({
    Key? key,
    required this.song,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: song.thumbnailUrl != null
          ? Image.network(song.thumbnailUrl!, width: 50, height: 50)
          : const Icon(Icons.music_note),
      title: Text(song.title),
      subtitle: Text(song.artist ?? 'Unknown'),
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }
}