import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Added for post-frame callback
import 'package:vibration/vibration.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../widgets/brand_dropdown.dart';

class ResultsScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final String? result;

  const ResultsScreen({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    this.result,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  late Database _database;
  bool _isLoading = false;
  Map<String, dynamic> resultData = {
    'is_authentic': false,
    'brand': 'Unknown',
    'batch_no': 'N/A',
    'date': 'N/A',
    'confidence': 'N/A',
    'vibrate': false,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withOpacity(0.3),
    ).animate(_animationController);

    _initDatabase();

    if (widget.result != null) {
      setState(() => _isLoading = true);
      _processResult();
    } else {
      _showSnackBar('No result data provided'); // Deferred to post-frame
    }
  }

  Future<void> _initDatabase() async {
    try {
      _database = await _getDatabase();
    } catch (e) {
      _showSnackBar('Failed to initialize database: $e'); // Deferred to post-frame
    }
  }

  Future<void> _processResult() async {
    try {
      resultData = jsonDecode(widget.result!);
      if (!resultData.containsKey('is_authentic') || !resultData.containsKey('brand')) {
        throw Exception('Invalid result format: missing required fields');
      }
      await _saveResult(resultData);
      if (resultData['vibrate'] == true || resultData['is_authentic'] == false) {
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 500);
        }
        _animationController.repeat(reverse: true, period: const Duration(seconds: 1));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _animationController.stop();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1C),
                title: const Text('Counterfeit Warning', style: TextStyle(color: Colors.red)),
                content: const Text(
                  'This bottle may be counterfeit. Check the label, seal, and packaging. Report to authorities if suspicious.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: Color(0xFF42A5F5))),
                  ),
                ],
              ),
            );
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to process result: $e'); // Deferred to post-frame
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Database> _getDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/results.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            brand TEXT,
            batch_no TEXT,
            date TEXT,
            confidence TEXT,
            is_authentic INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> _saveResult(Map<String, dynamic> result) async {
    try {
      await _database.insert('results', {
        'brand': result['brand']?.toString() ?? 'Unknown',
        'batch_no': result['batch_no']?.toString() ?? 'N/A',
        'date': result['date']?.toString() ?? 'N/A',
        'confidence': result['confidence']?.toString() ?? 'N/A',
        'is_authentic': (result['is_authentic'] == true) ? 1 : 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _showSnackBar('Failed to save result: $e'); // Deferred to post-frame
    }
  }

  // Helper method to safely show snackbar
  void _showSnackBar(String message) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _colorAnimation,
              builder: (context, child) => Container(
                color: _colorAnimation.value,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        const BrandDropdown(),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: resultData['is_authentic'] ? Colors.green : Colors.red,
                              width: 1.3,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                resultData['is_authentic'] ? Icons.verified : Icons.warning,
                                color: resultData['is_authentic']
                                    ? const Color(0xFF66BB6A)
                                    : Colors.red,
                                size: 48,
                                semanticLabel: resultData['is_authentic']
                                    ? 'Authentic'
                                    : 'Counterfeit',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                resultData['is_authentic']
                                    ? '✅ Authentic Alcohol'
                                    : '❌ Counterfeit Detected',
                                style: TextStyle(
                                  color: resultData['is_authentic']
                                      ? const Color(0xFF66BB6A)
                                      : Colors.red,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Brand: ${resultData['brand']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Batch No: ${resultData['batch_no']}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${resultData['date']}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Confidence: ${resultData['confidence']}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: const Color(0xFF42A5F5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => Navigator.pushNamed(context, '/scan'),
                            child: const Text('Back to Scan', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1B1B1B),
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: widget.currentIndex,
        onTap: (index) {
          widget.onTabTapped(index);
          if (index != widget.currentIndex) {
            String route;
            switch (index) {
              case 0:
                route = '/help';
                break;
              case 1:
                route = '/scan';
                break;
              case 2:
                route = '/upload';
                break;
              case 3:
                route = '/history';
                break;
              default:
                return;
            }
            Navigator.pushNamed(context, route);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.help, size: 28),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 28),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload, size: 28),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 28),
            label: 'History',
          ),
        ],
      ),
    );
  }
}