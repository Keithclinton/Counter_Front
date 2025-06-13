import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  int _loadLimit = 20;

  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<Database> _getDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/results.db';
    return openDatabase(path);
  }

  Future<void> _loadHistory() async {
    final db = await _getDatabase();
    final results = await db.query(
      'results',
      orderBy: 'timestamp DESC',
      limit: _loadLimit,
    );
    setState(() {
      _allHistory = results;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredHistory = _allHistory.where((item) {
        final brand = item['brand']?.toString().toLowerCase() ?? '';
        final batch = item['batch_no']?.toString().toLowerCase() ?? '';
        final timestamp = DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime(2000);

        final searchMatch = brand.contains(_searchQuery.toLowerCase()) ||
            batch.contains(_searchQuery.toLowerCase());

        final fromMatch = _fromDate == null || timestamp.isAfter(_fromDate!.subtract(const Duration(days: 1)));
        final toMatch = _toDate == null || timestamp.isBefore(_toDate!.add(const Duration(days: 1)));

        return searchMatch && fromMatch && toMatch;
      }).toList();
    });
  }

  Future<void> _deleteEntry(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('Are you sure you want to delete this prediction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await _getDatabase();
      await db.delete('results', where: 'id = ?', whereArgs: [id]);
      _loadHistory();
    }
  }

  Future<void> _deleteAllHistory() async {
    final db = await _getDatabase();
    await db.delete('results');
    _loadHistory();
  }

  Future<void> _exportHistory() async {
    final db = await _getDatabase();
    final results = await db.query('results');

    List<List<dynamic>> csvData = [
      ['ID', 'Brand', 'Batch', 'Date', 'Confidence', 'Timestamp', 'Is Authentic'],
      ...results.map((row) => [
            row['id'],
            row['brand'],
            row['batch_no'],
            row['date'],
            row['confidence'],
            row['timestamp'],
            row['is_authentic'] == 1 ? 'Authentic' : 'Counterfeit'
          ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/prediction_history.csv');
    await file.writeAsString(csv);

    Share.shareXFiles([XFile(file.path)], text: 'Prediction history exported');
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromDate = selected;
        } else {
          _toDate = selected;
        }
      });
      _applyFilters();
    }
  }

  void _loadMore() {
    setState(() {
      _loadLimit += 20;
    });
    _loadHistory();
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);
    if (dateTime != null) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
    return timestamp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Prediction History', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportHistory,
            tooltip: 'Export as CSV',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete All History?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteAllHistory();
                      },
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Delete All',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by brand or batch...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_fromDate == null
                          ? 'From'
                          : DateFormat('dd/MM/yyyy').format(_fromDate!)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_toDate == null
                          ? 'To'
                          : DateFormat('dd/MM/yyyy').format(_toDate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _filteredHistory.isEmpty
                    ? const Center(
                        child: Text('No matching predictions.',
                            style: TextStyle(color: Colors.white70, fontSize: 16)),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: _filteredHistory.length,
                          itemBuilder: (context, index) {
                            final result = _filteredHistory[index];
                            final isAuthentic = result['is_authentic'] == 1;
                            return Dismissible(
                              key: Key(result['id'].toString()),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _deleteEntry(result['id']);
                                return false; // prevent automatic removal
                              },
                              child: Card(
                                color: const Color(0xFF1C1C1C),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  isThreeLine: true,
                                  leading: Icon(
                                    isAuthentic ? Icons.verified : Icons.warning,
                                    color: isAuthentic ? const Color(0xFF66BB6A) : Colors.red,
                                  ),
                                  title: Text(
                                    isAuthentic ? 'Authentic' : 'Counterfeit',
                                    style: TextStyle(
                                      color: isAuthentic ? const Color(0xFF66BB6A) : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Brand: ${result['brand']}\n'
                                    'Batch: ${result['batch_no']}\n'
                                    'Date: ${result['date']}\n'
                                    'Confidence: ${result['confidence']}\n'
                                    'Timestamp: ${_formatTimestamp(result['timestamp'])}',
                                    style: const TextStyle(color: Colors.white70, height: 1.4),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
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
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/help');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/scan');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/upload');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/history');
                break;
            }
          }
        },
        type: BottomNavigationBarType.fixed,
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
