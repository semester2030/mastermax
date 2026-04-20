/// تقويم يومي ثابت بتوقيت السعودية (UTC+3، بدون DST) لمفاتيح التخزين yyyy-MM-dd.
abstract final class RiyadhCalendar {
  static const Duration _offset = Duration(hours: 3);

  /// «الآن» كتاريخ تقويمي في السعودية (يوم/شهر/سنة).
  static DateTime nowRiyadhWallClock() {
    return DateTime.now().toUtc().add(_offset);
  }

  static String dateKeyFromWall(DateTime wall) {
    final y = wall.year;
    final m = wall.month.toString().padLeft(2, '0');
    final d = wall.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String todayDateKey() => dateKeyFromWall(nowRiyadhWallClock());

  /// مفتاح اليوم من تاريخ منتقي (يوم/شهر/سنة كما اختار المستخدم).
  static String dateKeyFromCalendarDate(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// يولّد كل مفاتيح الأيام من [fromKey] إلى [toKey] شاملة (ترتيبًا).
  static List<String> enumerateKeysInclusive(String fromKey, String toKey) {
    final from = _parseKey(fromKey);
    final to = _parseKey(toKey);
    if (from == null || to == null || from.isAfter(to)) return [];
    final out = <String>[];
    var cur = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    while (!cur.isAfter(end)) {
      out.add(dateKeyFromWall(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  static DateTime? _parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime.utc(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  /// تسمية عربية قصيرة للعرض (يوم/شهر).
  static String shortArabicLabel(String yyyyMmDd) {
    final p = _parseKey(yyyyMmDd);
    if (p == null) return yyyyMmDd;
    return '${p.day}/${p.month}';
  }

  static String monthArabicLabel(int year, int month) {
    const names = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    if (month < 1 || month > 12) return '$year';
    return '${names[month]} $year';
  }
}
