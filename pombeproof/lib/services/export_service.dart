import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:counterfeit_detector/services/history_service.dart';
import 'dart:io';
import 'dart:convert';

final logger = Logger();

class ExportService {
  Future<File> exportHistory() async {
    try {
      final historyService = HistoryService();
      final results = await historyService.loadAllResults();
      final jsonData = jsonEncode(results);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/history_export.json');
      await file.writeAsString(jsonData);
      logger.i('History exported to ${file.path}');
      return file;
    } catch (e) {
      logger.e('Error exporting history: $e');
      throw Exception('Error exporting history: $e');
    }
  }
}