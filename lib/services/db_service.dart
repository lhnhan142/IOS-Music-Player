import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/song.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'songs.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE songs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            local_path TEXT NOT NULL UNIQUE,
            artist TEXT,
            thumbnail_url TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertSong(Song song) async {
    final db = await database;
    return await db.insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  Future<int> deleteSong(int id) async {
    final db = await database;
    return await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Song>> searchSongs(String keyword) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      where: 'title LIKE ?',
      whereArgs: ['%$keyword%'],
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }
}