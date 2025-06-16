import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart'; // Separate file for DB operations

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
  bool _isLoading = false;

  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Shows a SnackBar with the given message and optional undo action.
  void _showSnackBar(String message, {VoidCallback? undoAction, String undoLabel = 'Undo'}) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: undoAction != null
            ? SnackBarAction(
                label: undoLabel,
                onPressed: undoAction,
              )
            : null,
      ),
    );
  }

  /// Loads history from the database with pagination.
  Future<void> _loadHistory() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final results = await DatabaseHelper.instance.queryResults(
        limit: 20,
        offset: _allHistory.length,
      );
      if (mounted) {
        setState(() {
          _allHistory.addAll(results);
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading history: $e');
      }
    }
  }

  /// Applies search and date filters to the history.
  void _applyFilters() {
    setState(() {
      _filteredHistory = _allHistory.where((item) {
        final brand = item['brand']?.toString().toLowerCase() ?? '';
        final batch = item['batch_no']?.toString().toLowerCase() ?? '';
        final timestamp = DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime(2000);

        final searchMatch = brand.contains(_searchQuery.toLowerCase()) ||
            batch.contains(_searchQuery.toLowerCase());

        final fromMatch = _fromDate == null ||
            timestamp.isAtSameMomentAs(_fromDate!) ||
            timestamp.isAfter(_fromDate!);
        final toMatch = _toDate == null ||
            timestamp.isAtSameMomentAs(_toDate!) ||
            timestamp.isBefore(_toDate!);

        return searchMatch && fromMatch && toMatch;
      }).toList();
    });
  }

  /// Deletes a single entry with confirmation and undo option.
  Future<void> _deleteEntry(int id) async {
    final deletedRow = _allHistory.firstWhere((row) => row['id'] == id);
    try {
      await DatabaseHelper.instance.deleteResult(id);
      _loadHistory();
      _showSnackBar(
        'Entry deleted',
        undoAction: () async {
          await DatabaseHelper.instance.insertResult(deletedRow);
          _loadHistory();
        },
      );
    } catch (e) {
      _showSnackBar('Error deleting entry: $e');
    }
  }

  /// Deletes all history with confirmation.
  Future<void> _deleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All History?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteAllResults();
        _loadHistory();
        _showSnackBar('All history deleted');
      } catch (e) {
        _showSnackBar('Error deleting history: $e');
      }
    }
  }

  /// Exports history as CSV and shares it.
  Future<void> _exportHistory() async {
    try {
      final results = await DatabaseHelper.instance.queryAllResults();
      List<List<dynamic>> csvData = [
        [
          'ID',
          'Brand',
          'Batch',
          'Date',
          'Confidence',
          'Timestamp',
          'Is Authentic',
          // 'Latitude', // Optional: Add if location is stored
          // 'Longitude',
        ],
        ...results.map((row) => [
              row['id'],
              row['brand'],
              row['batch_no'],
              row['date'],
              row['confidence'],
              row['timestamp'],
              row['is_authentic'] == 1 ? 'Authentic' : 'Counterfeit',
              // row['latitude'] ?? 'Unknown', // Optional
              // row['longitude'] ?? 'Unknown',
            ]),
      ];

      String csv = const ListToCsvConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
      ).convert(csvData);
      final dir = await DatabaseHelper.instance.getDocumentsDirectory();
      final filename =
          'prediction_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'Prediction history exported');
      if (mounted) {
        _showSnackBar('History exported successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error exporting history: $e');
      }
    }
  }

  /// Picks a date for filtering.
  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
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

  /// Clears all filters.
  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  /// Loads more history items.
  void _loadMore() {
    if (_isLoading) return;
    _loadHistory();
  }

  /// Formats a timestamp for display.
  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);
    return dateTime != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(dateTime)
        : 'Invalid date';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
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
              onPressed: _deleteAllHistory,
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
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _fromDate == null ? 'From' : DateFormat('dd/MM/yyyy').format(_fromDate!),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: false),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _toDate == null ? 'To' : DateFormat('dd/MM/yyyy').format(_toDate!),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.clear_all, color: Colors.white70),
                      onPressed: _clearFilters,
                      tooltip: 'Clear Filters',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _isLoading && _filteredHistory.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        )
                      : _filteredHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching predictions.',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (scrollInfo) {
                                if (!_isLoading &&
                                    scrollInfo.metrics.pixels >=
                                        scrollInfo.metrics.maxScrollExtent - 200) {
                                  _loadMore();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _filteredHistory.length + (_isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _filteredHistory.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                                      ),
                                    );
                                  }
                                  final result = _filteredHistory[index];
                                  final isAuthentic = result['is_authentic'] == 1;
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) => FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                    child: Dismissible(
                                      key: Key(result['id'].toString()),
                                      background: Container(
                                        color: Colors.red,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: const Icon(Icons.delete, color: Colors.white),
                                      ),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (direction) async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete Entry?'),
                                            content: const Text('This cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await _deleteEntry(result['id']);
                                          return true;
                                        }
                                        return false;
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
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Brand: ${result['brand']}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Batch: ${result['batch_no']}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Date: ${result['date']}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Confidence: ${result['confidence']}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              Text(
                                                'Timestamp: ${_formatTimestamp(result['timestamp'])}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              
                                            ],
                                          ),
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
                  Navigator.pushNamed(context, '/help');
                  break;
                case 1:
                  Navigator.pushNamed(context, '/scan');
                  break;
                case 2:
                  Navigator.pushNamed(context, '/upload');
                  break;
                case 3:
                  Navigator.pushNamed(context, '/history');
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
      ),
    );
  }
}