class Song {
  int? id;
  String title;
  String localPath;
  String? artist;
  String? thumbnailUrl;

  Song({
    this.id,
    required this.title,
    required this.localPath,
    this.artist,
    this.thumbnailUrl,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      localPath: map['local_path'],
      artist: map['artist'],
      thumbnailUrl: map['thumbnail_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'local_path': localPath,
      'artist': artist,
      'thumbnail_url': thumbnailUrl,
    };
  }
}