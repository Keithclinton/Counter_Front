import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final logger = Logger();

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

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

  Future<String?> getLastBrand() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_brand');
  }

  Future<void> saveLastBrand(String brand) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_brand', brand);
    logger.i('Saved last brand: $brand');
  }

  Future<bool> isFirstScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_first_scan') ?? true;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_scan', false);
    logger.i('Onboarding completed');
  }

  Future<void> saveResult(Map<String, dynamic> result, String imagePath, dynamic position) async {
    final db = await database;
    await db.insert('scans', {
      'brand': result['brand'],
      'batch_no': result['batch_no'] ?? 'Unknown',
      'date': result['date'] ?? DateTime.now().toIso8601String(),
      'confidence': result['confidence']?.toString() ?? 'Unknown',
      'timestamp': DateTime.now().toIso8601String(),
      'is_authentic': result['is_authentic'] ? 1 : 0,
      'image_path': imagePath,
      'latitude': position?.latitude.toString() ?? '0.0',
      'longitude': position?.longitude.toString() ?? '0.0',
    });
    logger.i('Result saved: ${result['brand']}');
  }
}