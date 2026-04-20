/// استخراج مدينة وحي من حقول صريحة أو من نص عنوان عربي (للتحليل الإداري وتخزين Firestore).
class SaudiRegionParser {
  SaudiRegionParser._();

  /// مدن سعودية شائعة للمطابقة داخل النص (الأطول أولاً لتفادي جزئيات خاطئة).
  static const List<String> saudiCitiesOrdered = [
    'المدينة المنورة',
    'الرياض',
    'الدمام',
    'الخبر',
    'الطائف',
    'بريدة',
    'الأحساء',
    'الهفوف',
    'مكة المكرمة',
    'مكة',
    'جدة',
    'ينبع',
    'تبوك',
    'نجران',
    'جازان',
    'أبها',
    'خميس مشيط',
    'حائل',
    'الجبيل',
    'القطيف',
    'عرعر',
    'سكاكا',
    'الباحة',
    'الظهران',
  ];

  /// يكتب `city` و `district` في [target] قبل `set`/`update` على Firestore.
  static void applyToFirestoreMap(Map<String, dynamic> target, String address) {
    final r = fromMap(target, address);
    target['city'] = r.city;
    target['district'] = r.district;
  }

  static ParsedSaudiRegion fromMap(Map<String, dynamic> data, String address) {
    final explicitCity = data['city']?.toString().trim();
    final explicitDistrict = data['district']?.toString().trim();
    if (explicitCity != null &&
        explicitCity.isNotEmpty &&
        explicitDistrict != null &&
        explicitDistrict.isNotEmpty) {
      return ParsedSaudiRegion(
        city: explicitCity,
        district: explicitDistrict,
        source: RegionParseSource.explicitFields,
      );
    }
    return fromFreeText(address);
  }

  static ParsedSaudiRegion fromFreeText(String raw) {
    final text = raw.replaceAll('\n', ' ').trim();
    if (text.isEmpty) {
      return const ParsedSaudiRegion(
        city: 'غير محدد',
        district: '—',
        source: RegionParseSource.empty,
      );
    }

    String? district;
    final districtMatch = RegExp(r'حي\s+([^،,\-\n]+)').firstMatch(text);
    if (districtMatch != null) {
      district = districtMatch.group(1)?.trim();
      if (district != null && district.length > 42) {
        district = '${district.substring(0, 40)}…';
      }
    }
    district ??= 'غير محدد الحي';

    String city = 'غير محدد';
    for (final c in saudiCitiesOrdered) {
      if (text.contains(c)) {
        city = c == 'مكة' ? 'مكة المكرمة' : c;
        break;
      }
    }

    return ParsedSaudiRegion(
      city: city,
      district: district,
      source: city == 'غير محدد' && district == 'غير محدد الحي'
          ? RegionParseSource.heuristicWeak
          : RegionParseSource.heuristic,
    );
  }
}

enum RegionParseSource {
  explicitFields,
  heuristic,
  heuristicWeak,
  empty,
}

class ParsedSaudiRegion {
  const ParsedSaudiRegion({
    required this.city,
    required this.district,
    required this.source,
  });

  final String city;
  final String district;
  final RegionParseSource source;
}
