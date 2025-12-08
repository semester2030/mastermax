import '../models/property_model.dart';
import '../models/property_type.dart';
import '../../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// خدمة إدارة العقارات
class PropertyService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PropertyService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // قائمة تجريبية للعقارات
  final List<PropertyModel> _properties = [
    PropertyModel(
      id: '1',
      ownerId: 'owner1',
      title: 'فيلا مودرن مع مسبح',
      description: 'فيلا حديثة مع مسبح خاص وحديقة واسعة، تصميم عصري مع إطلالات بانورامية. تشطيب فاخر مع أنظمة ذكية متكاملة.',
      price: 2500000,
      images: [
        'assets/images/real_estate/listings/property1_main.jpg',
        'assets/images/real_estate/listings/property1_1.jpg',
        'assets/images/real_estate/listings/property1_2.jpg',
        'assets/images/real_estate/listings/property1_3.jpg',
        'assets/images/real_estate/listings/property1_4.jpg',
      ],
      address: 'حي النرجس، الرياض',
      location: Point(
        coordinates: Position(46.6753, 24.7136),
      ),
      type: PropertyType.villa,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 6,
      bathrooms: 7,
      area: 750,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '+966500000001',
    ),
    PropertyModel(
      id: '2',
      ownerId: 'owner1',
      title: 'فيلا فاخرة بإطلالة بحرية',
      description: 'فيلا مطلة على البحر مباشرة، تصميم معماري فريد مع حديقة منسقة ومسبح لا نهائي. فخامة في كل التفاصيل.',
      price: 4200000,
      images: [
        'assets/images/real_estate/listings/property2_main.jpg',
        'assets/images/real_estate/listings/property2_1.jpg',
        'assets/images/real_estate/listings/property2_2.jpg',
        'assets/images/real_estate/listings/property2_3.jpg',
        'assets/images/real_estate/listings/property2_4.jpg',
        'assets/images/real_estate/listings/property2_5.jpg',
        'assets/images/real_estate/listings/property2_6.jpg',
      ],
      address: 'حي الشاطئ، جدة',
      location: Point(
        coordinates: Position(39.1728, 21.5433),
      ),
      type: PropertyType.villa,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 8,
      bathrooms: 9,
      area: 1200,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '+966500000002',
    ),
    PropertyModel(
      id: '3',
      ownerId: 'owner2',
      title: 'فيلا كلاسيك مع حدائق',
      description: 'فيلا بتصميم كلاسيكي فخم، حدائق واسعة مع نوافير ومسبح كبير. تشطيبات راقية وديكورات داخلية فاخرة.',
      price: 3800000,
      images: [
        'assets/images/real_estate/listings/property3_main.jpg',
        'assets/images/real_estate/listings/property3_1.jpg',
        'assets/images/real_estate/listings/property3_2.jpg',
        'assets/images/real_estate/listings/property3_3.jpg',
        'assets/images/real_estate/listings/property3_4.jpg',
        'assets/images/real_estate/listings/property3_5.jpg',
      ],
      address: 'حي الياسمين، الرياض',
      location: Point(
        coordinates: Position(46.6853, 24.8136),
      ),
      type: PropertyType.villa,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 7,
      bathrooms: 8,
      area: 900,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '+966500000003',
    ),
    PropertyModel(
      id: '4',
      ownerId: 'owner2',
      title: 'فيلا مع مسبح داخلي',
      description: 'فيلا عصرية مع مسبح داخلي مدفأ، صالة رياضية متكاملة، سينما منزلية، وتقنيات ذكية متطورة.',
      price: 5500000,
      images: [
        'assets/images/real_estate/listings/property4_main.jpg',
        'assets/images/real_estate/listings/property4_1.jpg',
        'assets/images/real_estate/listings/property4_2.jpg',
        'assets/images/real_estate/listings/property4_3.jpg',
        'assets/images/real_estate/listings/property4_4.jpg',
      ],
      address: 'حي الملقا، الرياض',
      location: Point(
        coordinates: Position(46.6353, 24.7936),
      ),
      type: PropertyType.villa,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 9,
      bathrooms: 10,
      area: 1500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '+966500000004',
    ),
    PropertyModel(
      id: '5',
      ownerId: 'owner3',
      title: 'فيلا دوبلكس حديثة',
      description: 'فيلا دوبلكس بتصميم معاصر، مصعد خاص، حديقة على السطح مع جلسات خارجية، ومطبخ مفتوح حديث.',
      price: 3200000,
      images: [
        'assets/images/real_estate/listings/property5_1.jpg',
        'assets/images/real_estate/listings/property5_2.jpg',
        'assets/images/real_estate/listings/property5_3.jpg',
        'assets/images/real_estate/listings/property5_4.jpg',
        'assets/images/real_estate/listings/property5_5.jpg',
      ],
      address: 'حي الورود، الرياض',
      location: Point(
        coordinates: Position(46.7453, 24.7736),
      ),
      type: PropertyType.villa,
      status: PropertyStatus.available,
      offerType: OfferType.sale,
      rooms: 7,
      bathrooms: 8,
      area: 800,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      contactPhone: '+966500000005',
    ),
  ];

  /// إضافة عقار جديد
  Future<PropertyModel> addProperty(PropertyModel property) async {
    try {
      // إضافة معرف فريد للعقار الجديد
      final newProperty = property.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _properties.add(newProperty);
      return newProperty;
    } catch (e) {
      logError('Error adding property', e);
      rethrow;
    }
  }

  /// تحديث بيانات عقار
  Future<PropertyModel> updateProperty(PropertyModel property) async {
    try {
      final index = _properties.indexWhere((p) => p.id == property.id);
      if (index != -1) {
        _properties[index] = property.copyWith(updatedAt: DateTime.now());
        return _properties[index];
      }
      throw Exception('العقار غير موجود');
    } catch (e) {
      logError('Error updating property', e);
      rethrow;
    }
  }

  /// حذف عقار
  Future<bool> deleteProperty(String propertyId) async {
    try {
      final initialLength = _properties.length;
      _properties.removeWhere((p) => p.id == propertyId);
      return _properties.length < initialLength;
    } catch (e) {
      logError('Error deleting property', e);
      return false;
    }
  }

  /// جلب عقار بواسطة المعرف
  Future<PropertyModel?> getPropertyById(String propertyId) async {
    try {
      return _properties.firstWhere((p) => p.id == propertyId);
    } catch (e) {
      logError('Error getting property', e);
      return null;
    }
  }

  /// جلب قائمة العقارات
  Future<List<PropertyModel>> getProperties({
    PropertyType? type,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? location,
    bool? isAvailable,
  }) async {
    try {
      // محاكاة جلب البيانات من الخادم
      await Future.delayed(const Duration(seconds: 1));
      
      var properties = _properties;

      // تطبيق الفلترة
      if (type != null) {
        properties = properties.where((p) => p.type == type).toList();
      }

      if (minPrice != null) {
        properties = properties.where((p) => p.price >= minPrice).toList();
      }

      if (maxPrice != null) {
        properties = properties.where((p) => p.price <= maxPrice).toList();
      }

      if (minRooms != null) {
        properties = properties.where((p) => p.rooms >= minRooms).toList();
      }

      if (location != null) {
        properties = properties
            .where((p) => p.address.toLowerCase().contains(location.toLowerCase()))
            .toList();
      }

      if (isAvailable != null) {
        properties = properties
            .where((p) => isAvailable ? p.status == PropertyStatus.available : p.status != PropertyStatus.available)
            .toList();
      }

      return properties;
    } catch (e) {
      logError('Error getting properties', e);
      return [];
    }
  }

  /// البحث عن عقارات
  Future<List<PropertyModel>> searchProperties(String query) async {
    try {
      if (query.isEmpty) return _properties;

      return _properties.where((property) {
        final searchQuery = query.toLowerCase();
        return property.title.toLowerCase().contains(searchQuery) ||
            property.description.toLowerCase().contains(searchQuery) ||
            property.address.toLowerCase().contains(searchQuery);
      }).toList();
    } catch (e) {
      logError('Error searching properties', e);
      return [];
    }
  }

  /// إضافة تقييم لعقار
  Future<bool> addPropertyReview(String propertyId, PropertyReview review) async {
    try {
      final property = await getPropertyById(propertyId);
      if (property == null) return false;

      final updatedProperty = property.copyWith(
        reviews: [...property.reviews, review],
      );
      await updateProperty(updatedProperty);
      return true;
    } catch (e) {
      logError('Error adding property review', e);
      return false;
    }
  }

  /// تحديث حالة العقار
  Future<bool> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    try {
      final property = await getPropertyById(propertyId);
      if (property == null) return false;

      final updatedProperty = property.copyWith(status: status);
      await updateProperty(updatedProperty);
      return true;
    } catch (e) {
      logError('Error updating property status', e);
      return false;
    }
  }

  /// حساب متوسط التقييم
  double calculateAverageRating(List<PropertyReview> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold(0.0, (sum, review) => sum + review.rating);
    return total / reviews.length;
  }

  Future<List<PropertyModel>> getDummyProperties() async {
    await Future.delayed(const Duration(seconds: 1)); // محاكاة تأخير الشبكة

    return [
      PropertyModel(
        id: '1',
        ownerId: 'owner1',
        title: 'شقة فاخرة في الرياض',
        description: 'شقة حديثة مع إطلالة رائعة على المدينة',
        price: 1200000,
        images: [
          'assets/images/properties/apartment1.jpg',
          'assets/images/properties/apartment2.jpg',
        ],
        address: 'حي النرجس، الرياض',
        location: Point(
          coordinates: Position(46.6753, 24.7136),
        ),
        type: PropertyType.apartment,
        status: PropertyStatus.available,
        offerType: OfferType.sale,
        rooms: 3,
        bathrooms: 2,
        area: 150,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contactPhone: '+966500000000',
      ),
      PropertyModel(
        id: '2',
        ownerId: 'owner2',
        title: 'فيلا مع مسبح في جدة',
        description: 'فيلا فاخرة مع حديقة ومسبح خاص',
        price: 3500000,
        images: [
          'assets/images/properties/villa1.jpg',
          'assets/images/properties/villa2.jpg',
        ],
        address: 'حي الشاطئ، جدة',
        location: Point(
          coordinates: Position(39.1219, 21.5433),
        ),
        type: PropertyType.villa,
        status: PropertyStatus.available,
        offerType: OfferType.sale,
        rooms: 5,
        bathrooms: 4,
        area: 400,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contactPhone: '+966500000001',
      ),
      PropertyModel(
        id: '3',
        ownerId: 'owner3',
        title: 'شقة للإيجار في الخبر',
        description: 'شقة مؤثثة بالكامل مع إطلالة على البحر',
        price: 80000,
        images: [
          'assets/images/properties/apartment3.jpg',
          'assets/images/properties/apartment4.jpg',
        ],
        address: 'حي الكورنيش، الخبر',
        location: Point(
          coordinates: Position(50.2148, 26.2172),
        ),
        type: PropertyType.apartment,
        status: PropertyStatus.available,
        offerType: OfferType.rent,
        rooms: 2,
        bathrooms: 2,
        area: 120,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contactPhone: '+966500000002',
      ),
      PropertyModel(
        id: '4',
        ownerId: 'owner4',
        title: 'أرض تجارية في الدمام',
        description: 'أرض تجارية على شارع رئيسي',
        price: 2000000,
        images: [
          'assets/images/properties/land1.jpg',
          'assets/images/properties/land2.jpg',
        ],
        address: 'شارع الملك فهد، الدمام',
        location: Point(
          coordinates: Position(49.9777, 26.4207),
        ),
        type: PropertyType.land,
        status: PropertyStatus.available,
        offerType: OfferType.sale,
        rooms: 0,
        bathrooms: 0,
        area: 1000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contactPhone: '+966500000003',
      ),
      PropertyModel(
        id: '5',
        ownerId: 'owner5',
        title: 'مكتب تجاري في الرياض',
        description: 'مكتب حديث في برج تجاري',
        price: 120000,
        images: [
          'assets/images/properties/office1.jpg',
          'assets/images/properties/office2.jpg',
        ],
        address: 'طريق الملك فهد، الرياض',
        location: Point(
          coordinates: Position(46.6753, 24.7136),
        ),
        type: PropertyType.commercial,
        status: PropertyStatus.available,
        offerType: OfferType.rent,
        rooms: 4,
        bathrooms: 2,
        area: 200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        contactPhone: '+966500000004',
      ),
    ];
  }
} 