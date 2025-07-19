import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:counterfeit_detector/logger.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'pombeproof.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            brand TEXT,
            batch_no TEXT,
            date TEXT,
            confidence REAL,
            timestamp TEXT,
            is_authentic INTEGER,
            image_path TEXT,
            latitude REAL,
            longitude REAL
          )
        ''');
      },
    );
  }

  Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<List<Map<String, dynamic>>> queryResults({required int limit, required int offset}) async {
    final db = await database;
    try {
      final results = await db.query('results', limit: limit, offset: offset);
      AppLogger().i('Queried $limit results with offset $offset');
      return results;
    } catch (e) {
      AppLogger().e('Error querying results: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> queryAllResults() async {
    final db = await database;
    try {
      final results = await db.query('results');
      AppLogger().i('Queried all ${results.length} results');
      return results;
    } catch (e) {
      AppLogger().e('Error querying all results: $e');
      rethrow;
    }
  }

  Future<void> insertResult(Map<String, dynamic> row) async {
    final db = await database;
    try {
      await db.insert('results', row);
      AppLogger().i('Inserted result: ${row['brand']}');
    } catch (e) {
      AppLogger().e('Error inserting result: $e');
      rethrow;
    }
  }

  Future<void> deleteResult(int id) async {
    final db = await database;
    try {
      await db.delete('results', where: 'id = ?', whereArgs: [id]);
      AppLogger().i('Deleted result with id: $id');
    } catch (e) {
      AppLogger().e('Error deleting result: $e');
      rethrow;
    }
  }

  Future<void> deleteAllResults() async {
    final db = await database;
    try {
      await db.delete('results');
      AppLogger().i('Deleted all results');
    } catch (e) {
      AppLogger().e('Error deleting all results: $e');
      rethrow;
    }
  }
}