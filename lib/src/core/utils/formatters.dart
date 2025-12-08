import 'package:intl/intl.dart';

/// تنسيق الأرقام بالعربية
String formatNumber(num number) {
  final formatter = NumberFormat('#,##0', 'ar');
  return formatter.format(number);
}

/// تنسيق العملة
String formatCurrency(num amount) {
  final formatter = NumberFormat('#,##0 ريال', 'ar');
  return formatter.format(amount);
}

/// تنسيق التاريخ
String formatDate(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy', 'ar');
  return formatter.format(date);
}

/// تنسيق الوقت
String formatTime(DateTime time) {
  final formatter = DateFormat('HH:mm', 'ar');
  return formatter.format(time);
}

/// تنسيق التاريخ والوقت
String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm', 'ar');
  return formatter.format(dateTime);
}

/// تنسيق المساحة
String formatArea(num area) {
  final formatter = NumberFormat('#,##0', 'ar');
  return '${formatter.format(area)} م²';
} 