import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'dart:io';

final logger = Logger();

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/scans.db';
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE scans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          brand TEXT,
          batch_no TEXT,
          date TEXT,
          confidence TEXT,
          timestamp TEXT,
          is_authentic INTEGER,
          image_path TEXT,
          latitude TEXT,
          longitude TEXT
        )
      ''');
    });
  }

  Future<List<Map<String, dynamic>>> loadResults({int limit = 10, int offset = 0}) async {
    try {
      final db = await database;
      final results = await db.query('scans', limit: limit, offset: offset);
      logger.i('Loaded ${results.length} history entries');
      return results;
    } catch (e) {
      logger.e('Error loading history: $e');
      throw Exception('Error loading history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadAllResults() async {
    try {
      final db = await database;
      final results = await db.query('scans');
      logger.i('Loaded all ${results.length} history entries');
      return results;
    } catch (e) {
      logger.e('Error loading all history: $e');
      throw Exception('Error loading all history: $e');
    }
  }

  Future<void> deleteResult(int id) async {
    try {
      final db = await database;
      await db.delete('scans', where: 'id = ?', whereArgs: [id]);
      logger.i('Deleted history entry with id: $id');
    } catch (e) {
      logger.e('Error deleting entry: $e');
      throw Exception('Error deleting entry: $e');
    }
  }

  Future<void> deleteAllResults() async {
    try {
      final db = await database;
      await db.delete('scans');
      logger.i('Deleted all history entries');
    } catch (e) {
      logger.e('Error deleting all history: $e');
      throw Exception('Error deleting all history: $e');
    }
  }

  Future<void> insertResult(Map<String, dynamic> entry) async {
    try {
      final db = await database;
      await db.insert('scans', entry);
      logger.i('Inserted history entry: ${entry['brand']}');
    } catch (e) {
      logger.e('Error inserting entry: $e');
      throw Exception('Error inserting entry: $e');
    }
  }
}