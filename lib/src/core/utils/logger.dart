import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

void logDebug(String message) {
  logger.d(message);
}

void logInfo(String message) {
  logger.i(message);
}

void logWarning(String message) {
  logger.w(message);
}

void logError(String message, [dynamic error, StackTrace? stackTrace]) {
  logger.e(message, error: error, stackTrace: stackTrace);
} 