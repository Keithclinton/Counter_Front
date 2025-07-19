import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<Database> _initDB() async {
    final dir = await getDocumentsDirectory();
    final path = '${dir.path}/results.db';
    print('Initializing database at: $path');
    return await openDatabase(
      path,
      version: 2, // Incremented to trigger migration for existing databases
      onCreate: (db, version) async {
        print('Creating results table');
        await db.execute('''
          CREATE TABLE results (
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
        if (oldVersion < 2) {
          // Add missing columns if they don't exist
          try {
            await db.execute('ALTER TABLE results ADD COLUMN image_path TEXT');
            await db.execute('ALTER TABLE results ADD COLUMN latitude TEXT');
            await db.execute('ALTER TABLE results ADD COLUMN longitude TEXT');
            print('Columns image_path, latitude, and longitude added successfully');
          } catch (e) {
            print('Error during upgrade: $e');
          }
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> queryResults({int limit = 20, int offset = 0}) async {
    final db = await database;
    return await db.query(
      'results',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> queryAllResults() async {
    final db = await database;
    return await db.query('results', orderBy: 'timestamp DESC');
  }

  Future<void> insertResult(Map<String, dynamic> row) async {
    final db = await database;
    print('Inserting row: $row');
    await db.insert('results', row);
  }

  Future<void> deleteResult(int id) async {
    final db = await database;
    final row = await db.query('results', where: 'id = ?', whereArgs: [id]);
    if (row.isNotEmpty && row.first['image_path'] != null) {
      await File(row.first['image_path'] as String).delete();
    }
    await db.delete('results', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllResults() async {
    final db = await database;
    final results = await db.query('results');
    for (var row in results) {
      if (row['image_path'] != null) {
        await File(row['image_path'] as String).delete();
      }
    }
    await db.delete('results');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}