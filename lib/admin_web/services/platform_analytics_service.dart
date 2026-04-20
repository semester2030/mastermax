import 'package:cloud_firestore/cloud_firestore.dart';

import '../../src/core/time/riyadh_calendar.dart';

/// لوحة إحصائيات المنصة: إجماليات + مشاهدات فيديو يومية (مجمّع `spotlight_daily_views`).
class PlatformAnalyticsService {
  PlatformAnalyticsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _dailyViews = 'spotlight_daily_views';

  Future<PlatformOverviewSnapshot> loadOverview() async {
    final todayKey = RiyadhCalendar.todayDateKey();
    final results = await Future.wait<Object?>([
      _db.collection('properties').count().get(),
      _db.collection('cars').count().get(),
      _db.collection(_dailyViews).doc(todayKey).get(),
    ]);
    final pCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final cCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
    final dailyDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final todayViews = dailyDoc.exists
        ? ((dailyDoc.data()?['totalViews'] as num?)?.toInt() ?? 0)
        : 0;
    return PlatformOverviewSnapshot(
      totalProperties: pCount,
      totalCars: cCount,
      todayVideoViews: todayViews,
      todayDateKey: todayKey,
    );
  }

  /// جلب مشاهدات يومية خام في المدى [fromKey]..[toKey] (مفاتيح yyyy-MM-dd).
  Future<int> fetchViewsForDateKey(String dateKey) async {
    final doc = await _db.collection(_dailyViews).doc(dateKey).get();
    if (!doc.exists) return 0;
    return ((doc.data()?['totalViews'] as num?)?.toInt()) ?? 0;
  }

  Future<Map<String, int>> fetchDailyTotalsRaw(String fromKey, String toKey) async {
    if (fromKey.compareTo(toKey) > 0) return {};
    final snap = await _db
        .collection(_dailyViews)
        .orderBy(FieldPath.documentId)
        .startAt([fromKey])
        .endAt([toKey])
        .get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      map[doc.id] = (doc.data()['totalViews'] as num?)?.toInt() ?? 0;
    }
    return map;
  }

  /// سلسلة يومية متصلة (أيام بلا بيانات = صفر).
  Future<List<DailyViewPoint>> fetchDailySeries(String fromKey, String toKey) async {
    final keys = RiyadhCalendar.enumerateKeysInclusive(fromKey, toKey);
    if (keys.isEmpty) return [];
    final raw = await fetchDailyTotalsRaw(fromKey, toKey);
    return keys.map((k) => DailyViewPoint(dateKey: k, views: raw[k] ?? 0)).toList();
  }

  /// تجميع شهري داخل سنة تقويمية (Gregorian مع مفتاح اليوم السعودي نفس التقويم).
  Future<List<MonthlyViewPoint>> aggregateByMonthForYear(int year) async {
    final fromKey = '$year-01-01';
    final toKey = '$year-12-31';
    final daily = await fetchDailySeries(fromKey, toKey);
    final byMonth = List<int>.filled(12, 0);
    for (final p in daily) {
      final parts = p.dateKey.split('-');
      if (parts.length != 3) continue;
      final m = int.tryParse(parts[1]);
      if (m == null || m < 1 || m > 12) continue;
      byMonth[m - 1] += p.views;
    }
    return List.generate(
      12,
      (i) => MonthlyViewPoint(year: year, month: i + 1, views: byMonth[i]),
    );
  }

  /// تجميع أسبوعي: كل عنصر = مجموع 7 أيام متتالية من [anchorToKey] للخلف.
  Future<List<WeeklyViewPoint>> aggregateWeeksEndingOn(
    String anchorToKey, {
    int weekCount = 12,
  }) async {
    final anchor = _parseKeyOrNull(anchorToKey);
    if (anchor == null || weekCount < 1) return [];
    final end = anchor;
    final start = end.subtract(Duration(days: weekCount * 7 - 1));
    final fromKey = RiyadhCalendar.dateKeyFromWall(start);
    final toKey = RiyadhCalendar.dateKeyFromWall(end);
    final daily = await fetchDailySeries(fromKey, toKey);
    final weeks = <WeeklyViewPoint>[];
    for (var w = 0; w < weekCount; w++) {
      final weekEnd = end.subtract(Duration(days: w * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      var sum = 0;
      for (final p in daily) {
        final d = _parseKeyOrNull(p.dateKey);
        if (d == null) continue;
        if (!d.isBefore(weekStart) && !d.isAfter(weekEnd)) {
          sum += p.views;
        }
      }
      weeks.add(
        WeeklyViewPoint(
          labelEnd: RiyadhCalendar.dateKeyFromWall(weekEnd),
          views: sum,
        ),
      );
    }
    return weeks;
  }

  static DateTime? _parseKeyOrNull(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    try {
      return DateTime.utc(y, m, d);
    } catch (_) {
      return null;
    }
  }
}

class PlatformOverviewSnapshot {
  const PlatformOverviewSnapshot({
    required this.totalProperties,
    required this.totalCars,
    required this.todayVideoViews,
    required this.todayDateKey,
  });

  final int totalProperties;
  final int totalCars;
  final int todayVideoViews;
  final String todayDateKey;
}

class DailyViewPoint {
  const DailyViewPoint({required this.dateKey, required this.views});

  final String dateKey;
  final int views;
}

class MonthlyViewPoint {
  const MonthlyViewPoint({
    required this.year,
    required this.month,
    required this.views,
  });

  final int year;
  final int month;
  final int views;
}

class WeeklyViewPoint {
  const WeeklyViewPoint({required this.labelEnd, required this.views});

  /// آخر يوم في الأسبوع (مفتاح yyyy-MM-dd).
  final String labelEnd;
  final int views;
}
