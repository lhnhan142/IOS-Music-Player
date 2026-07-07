class Song {
  int? id;
  String title;
  String localPath;
  String? artist;
  String? thumbnailUrl;

  // ✅ Thêm 2 trạng thái tạm thời (không lưu DB)
  bool isDownloading;
  double downloadProgress;

  Song({
    this.id,
    required this.title,
    required this.localPath,
    this.artist,
    this.thumbnailUrl,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
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

  // Copy với trạng thái mới (dùng cho update UI)
  Song copyWith({
    int? id,
    String? title,
    String? localPath,
    String? artist,
    String? thumbnailUrl,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      localPath: localPath ?? this.localPath,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}