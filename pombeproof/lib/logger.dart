import 'package:logger/logger.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  final Logger _logger;

  factory AppLogger() => _instance;

  AppLogger._internal()
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
            printTime: true,
          ),
        );

  void i(String message) => _logger.i(message);
  void e(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
  void w(String message) => _logger.w(message);
  void d(String message) => _logger.d(message);
}