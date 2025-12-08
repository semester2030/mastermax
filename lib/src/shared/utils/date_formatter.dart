import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'ar').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'ar').format(date);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} سنة';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} شهر';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  static String formatDayName(DateTime date) {
    return DateFormat('EEEE', 'ar').format(date);
  }

  static String formatMonthName(DateTime date) {
    return DateFormat('MMMM', 'ar').format(date);
  }

  static String formatYear(DateTime date) {
    return DateFormat('yyyy', 'ar').format(date);
  }

  static String formatDateRange(DateTime start, DateTime end) {
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    return '$startStr - $endStr';
  }

  static String formatTimeRange(DateTime start, DateTime end) {
    final startStr = formatTime(start);
    final endStr = formatTime(end);
    return '$startStr - $endStr';
  }

  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} يوم';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ساعة';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} دقيقة';
    } else {
      return '${duration.inSeconds} ثانية';
    }
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  static bool isInFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  static bool isInPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }
} 