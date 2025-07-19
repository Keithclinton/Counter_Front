import 'package:flutter/material.dart';
import 'package:counterfeit_detector/services/api_service.dart';
import 'package:counterfeit_detector/screens/scan_screen.dart';

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
  late Future<List<dynamic>> _futureResults;

  @override
  void initState() {
    super.initState();
    _futureResults = ApiService.fetchLocations(); // Or ApiService.fetchHistory() if you have a history endpoint
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('History'),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _futureResults,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No history available', style: TextStyle(color: Colors.white70)));
            }
            final results = snapshot.data!;
            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  title: Text(result['brand'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Date: ${result['date'] ?? ''} | Authentic: ${result['is_authentic'] == true || result['is_authentic'] == 1 ? 'Yes' : 'No'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  leading: result['image_url'] != null
                      ? Image.network(result['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported, color: Colors.white70),
                );
              },
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