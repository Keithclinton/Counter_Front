import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:counterfeit_detector/services/result_processor.dart';
import 'package:counterfeit_detector/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:counterfeit_detector/screens/scan_screen.dart';

class ResultsScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const ResultsScreen({super.key, required this.currentIndex, required this.onTabTapped});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final ResultProcessor _resultProcessor;
  Map<String, dynamic>? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resultProcessor = ResultProcessor();
    _loadResult();
  }

  Future<void> _loadResult() async {
    setState(() => _isLoading = true);
    try {
      final response = ModalRoute.of(context)?.settings.arguments as String?;
      if (response != null) {
        _result = _resultProcessor.processResult(response);
      }
    } catch (e) {
      _showSnackBar(_getUserFriendlyError(e));
      await FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is ResultException) {
      return 'Failed to process result. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
    AppLogger().i('SnackBar: $message');
  }

  @override
  void dispose() {
    super.dispose();
    AppLogger().i('ResultsScreen disposed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Result', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : _result == null
              ? const Center(
                  child: Text(
                    'No result available',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!['is_authentic'] ? 'Authentic' : 'Counterfeit',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _result!['is_authentic'] ? const Color(0xFF66BB6A) : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Brand: ${_result!['brand'] ?? 'Unknown'}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      Text('Batch: ${_result!['batch_no'] ?? 'N/A'}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      Text('Confidence: ${_result!['confidence'] ?? 'N/A'}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ],
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
            final routes = ['/help', '/scan', '/upload', '/history'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.help, size: 28), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt, size: 28), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.upload, size: 28), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.history, size: 28), label: 'History'),
        ],
      ),
    );
  }
}