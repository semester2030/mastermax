import 'package:intl/intl.dart';

final _numberFormat = NumberFormat('#,##0', 'ar');
final _currencyFormat = NumberFormat('#,##0 ريال', 'ar');

String formatNumber(num number) {
  return _numberFormat.format(number);
}

String formatCurrency(num amount) {
  return _currencyFormat.format(amount);
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'ar').format(date);
}

String formatTime(DateTime time) {
  return DateFormat('HH:mm', 'ar').format(time);
}

String formatDateTime(DateTime dateTime) {
  return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(dateTime);
}

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

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