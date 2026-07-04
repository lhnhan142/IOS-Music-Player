class Song {
  int? id;
  String title;
  String localPath;      // đường dẫn file .m4a
  String? artist;        // tên kênh/tác giả
  String? thumbnailUrl;  // ảnh bìa (có thể lấy từ YouTube)

  Song({
    this.id,
    required this.title,
    required this.localPath,
    this.artist,
    this.thumbnailUrl,
  });

  // Chuyển đổi từ Map (đọc từ DB)
  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      localPath: map['local_path'],
      artist: map['artist'],
      thumbnailUrl: map['thumbnail_url'],
    );
  }

  // Chuyển sang Map (ghi vào DB)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'local_path': localPath,
      'artist': artist,
      'thumbnail_url': thumbnailUrl,
    };
  }
}