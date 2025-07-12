import 'package:flutter/material.dart';
import 'package:counterfeit_detector/services/history_service.dart';
import 'package:counterfeit_detector/services/export_service.dart';
import 'package:logger/logger.dart';
import 'dart:io';

final logger = Logger();

class HistoryScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabTapped;

  const HistoryScreen({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  final ExportService _exportService = ExportService();
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final results = await _historyService.loadResults(limit: 10, offset: 0);
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _deleteResult(int id) async {
    try {
      await _historyService.deleteResult(id);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting result: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllResults() async {
    try {
      await _historyService.deleteAllResults();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All results deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting all results: $e')),
        );
      }
    }
  }

  Future<void> _exportHistory() async {
    try {
      final file = await _exportService.exportHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('History exported to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllResults,
            tooltip: 'Delete all results',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportHistory,
            tooltip: 'Export history',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _results.isEmpty
            ? const Center(child: Text('No history available', style: TextStyle(color: Colors.white70)))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    title: Text(result['brand'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Date: ${result['date']} | Authentic: ${result['is_authentic'] == 1 ? 'Yes' : 'No'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteResult(result['id']),
                    ),
                    leading: result['image_path'] != null && File(result['image_path']).existsSync()
                        ? Image.file(File(result['image_path']), width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported, color: Colors.white70),
                  );
                },
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1B1B1B),
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: widget.currentIndex,
        onTap: widget.onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}