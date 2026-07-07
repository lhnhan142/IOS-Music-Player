import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
          ? CachedNetworkImage(
        imageUrl: song.thumbnailUrl!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Icon(Icons.music_note),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      )
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