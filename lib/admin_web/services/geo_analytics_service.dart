import 'package:cloud_firestore/cloud_firestore.dart';

import '../../src/core/geo/saudi_region_parser.dart';

/// فئة السطر للفلترة والتصدير.
enum GeoRowCategory {
  property,
  car,
  spotlightRealEstate,
  spotlightCar,
}

class GeoListingRow {
  GeoListingRow({
    required this.category,
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.rawAddress,
    required this.city,
    required this.district,
    required this.viewsCount,
    required this.parseSource,
  });

  final GeoRowCategory category;
  final String id;
  final String sellerId;
  final String sellerName;
  final String rawAddress;
  final String city;
  final String district;
  final int viewsCount;
  final RegionParseSource parseSource;

  String get kindLabel {
    switch (category) {
      case GeoRowCategory.property:
        return 'عقار';
      case GeoRowCategory.car:
        return 'سيارة';
      case GeoRowCategory.spotlightRealEstate:
        return 'فيديو عقار';
      case GeoRowCategory.spotlightCar:
        return 'فيديو سيارة';
    }
  }

  bool get isPropertyListing => category == GeoRowCategory.property;
  bool get isCarListing => category == GeoRowCategory.car;
  bool get isSpotlight => category == GeoRowCategory.spotlightRealEstate || category == GeoRowCategory.spotlightCar;
}

class DistrictRollup {
  DistrictRollup({
    required this.city,
    required this.district,
    required this.properties,
    required this.cars,
    required this.spotlightRealEstate,
    required this.spotlightCar,
  });

  final String city;
  final String district;
  final int properties;
  final int cars;
  final int spotlightRealEstate;
  final int spotlightCar;

  int get total => properties + cars + spotlightRealEstate + spotlightCar;
}

class SellerRollup {
  SellerRollup({
    required this.sellerId,
    required this.sellerName,
    required this.properties,
    required this.cars,
    required this.spotlightRealEstate,
    required this.spotlightCar,
  });

  final String sellerId;
  final String sellerName;
  final int properties;
  final int cars;
  final int spotlightRealEstate;
  final int spotlightCar;

  int get total => properties + cars + spotlightRealEstate + spotlightCar;
}

/// تحميل عيّنات من `properties` و`cars` و`spotlight_videos` وتطبيع المدينة/الحي.
class GeoAnalyticsService {
  GeoAnalyticsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _properties = 'properties';
  static const String _cars = 'cars';
  static const String _spotlight = 'spotlight_videos';

  Future<List<GeoListingRow>> loadDataset({int limitPerCollection = 450}) async {
    final out = <GeoListingRow>[];

    Future<void> addProperties() async {
      try {
        final snap = await _db
            .collection(_properties)
            .orderBy('createdAt', descending: true)
            .limit(limitPerCollection)
            .get();
        for (final d in snap.docs) {
          out.add(_fromProperty(d));
        }
      } catch (_) {
        /* قواعد أو فهرس */
      }
    }

    Future<void> addCars() async {
      try {
        final snap = await _db
            .collection(_cars)
            .orderBy('createdAt', descending: true)
            .limit(limitPerCollection)
            .get();
        for (final d in snap.docs) {
          out.add(_fromCar(d));
        }
      } catch (_) {}
    }

    Future<void> addSpotlight() async {
      try {
        final snap = await _db
            .collection(_spotlight)
            .orderBy('createdAt', descending: true)
            .limit(limitPerCollection)
            .get();
        for (final d in snap.docs) {
          out.add(_fromSpotlight(d));
        }
      } catch (_) {}
    }

    await Future.wait([addProperties(), addCars(), addSpotlight()]);
    return out;
  }

  GeoListingRow _fromProperty(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final address = (d['address'] ?? '').toString();
    final r = SaudiRegionParser.fromMap(d, address);
    return GeoListingRow(
      category: GeoRowCategory.property,
      id: doc.id,
      sellerId: (d['ownerId'] ?? '').toString(),
      sellerName: (d['ownerName'] ?? d['sellerName'] ?? d['contactName'] ?? '').toString().trim(),
      rawAddress: address,
      city: r.city,
      district: r.district,
      viewsCount: 0,
      parseSource: r.source,
    );
  }

  GeoListingRow _fromCar(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final address = (d['address'] ?? '').toString();
    final r = SaudiRegionParser.fromMap(d, address);
    return GeoListingRow(
      category: GeoRowCategory.car,
      id: doc.id,
      sellerId: (d['sellerId'] ?? '').toString(),
      sellerName: (d['sellerName'] ?? '').toString().trim(),
      rawAddress: address,
      city: r.city,
      district: r.district,
      viewsCount: 0,
      parseSource: r.source,
    );
  }

  GeoListingRow _fromSpotlight(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final address = (d['address'] ?? '').toString();
    final r = SaudiRegionParser.fromMap(d, address);
    final type = (d['type'] ?? '').toString().toLowerCase();
    final isCar = type.contains('car');
    return GeoListingRow(
      category: isCar ? GeoRowCategory.spotlightCar : GeoRowCategory.spotlightRealEstate,
      id: doc.id,
      sellerId: (d['sellerId'] ?? d['userId'] ?? '').toString(),
      sellerName: (d['sellerName'] ?? '').toString().trim(),
      rawAddress: address,
      city: r.city,
      district: r.district,
      viewsCount: (d['viewsCount'] as num?)?.toInt() ?? 0,
      parseSource: r.source,
    );
  }

  static List<DistrictRollup> rollupByDistrict(Iterable<GeoListingRow> rows) {
    final map = <String, DistrictRollup>{};
    for (final r in rows) {
      final key = '${r.city}|${r.district}';
      final e = map[key];
      var p = e?.properties ?? 0;
      var c = e?.cars ?? 0;
      var vr = e?.spotlightRealEstate ?? 0;
      var vc = e?.spotlightCar ?? 0;
      switch (r.category) {
        case GeoRowCategory.property:
          p++;
          break;
        case GeoRowCategory.car:
          c++;
          break;
        case GeoRowCategory.spotlightRealEstate:
          vr++;
          break;
        case GeoRowCategory.spotlightCar:
          vc++;
          break;
      }
      map[key] = DistrictRollup(
        city: r.city,
        district: r.district,
        properties: p,
        cars: c,
        spotlightRealEstate: vr,
        spotlightCar: vc,
      );
    }
    return map.values.toList();
  }

  static List<SellerRollup> rollupBySeller(Iterable<GeoListingRow> rows) {
    final map = <String, SellerRollup>{};
    for (final r in rows) {
      final sid = r.sellerId.isEmpty ? '_unknown' : r.sellerId;
      final e = map[sid];
      var p = e?.properties ?? 0;
      var c = e?.cars ?? 0;
      var vr = e?.spotlightRealEstate ?? 0;
      var vc = e?.spotlightCar ?? 0;
      switch (r.category) {
        case GeoRowCategory.property:
          p++;
          break;
        case GeoRowCategory.car:
          c++;
          break;
        case GeoRowCategory.spotlightRealEstate:
          vr++;
          break;
        case GeoRowCategory.spotlightCar:
          vc++;
          break;
      }
      final name = r.sellerName.isEmpty ? '(بدون اسم)' : r.sellerName;
      map[sid] = SellerRollup(
        sellerId: sid == '_unknown' ? '' : sid,
        sellerName: name,
        properties: p,
        cars: c,
        spotlightRealEstate: vr,
        spotlightCar: vc,
      );
    }
    return map.values.toList();
  }
}
