/// نموذج خطة الاشتراك في سبوتلايت
class SpotlightPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationInDays;
  final int maxVideos;
  final bool featuredListing;
  final bool prioritySupport;
  final List<String> features;

  /// إنشاء خطة اشتراك جديدة
  const SpotlightPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationInDays,
    required this.maxVideos,
    required this.features, this.featuredListing = false,
    this.prioritySupport = false,
  });

  /// إنشاء نسخة معدلة من الخطة
  SpotlightPlan copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? durationInDays,
    int? maxVideos,
    bool? featuredListing,
    bool? prioritySupport,
    List<String>? features,
  }) {
    return SpotlightPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      durationInDays: durationInDays ?? this.durationInDays,
      maxVideos: maxVideos ?? this.maxVideos,
      featuredListing: featuredListing ?? this.featuredListing,
      prioritySupport: prioritySupport ?? this.prioritySupport,
      features: features ?? this.features,
    );
  }

  /// تحويل من JSON
  factory SpotlightPlan.fromJson(Map<String, dynamic> json) {
    return SpotlightPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      durationInDays: json['durationInDays'] as int,
      maxVideos: json['maxVideos'] as int,
      featuredListing: json['featuredListing'] as bool? ?? false,
      prioritySupport: json['prioritySupport'] as bool? ?? false,
      features: List<String>.from(json['features'] as List),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'durationInDays': durationInDays,
      'maxVideos': maxVideos,
      'featuredListing': featuredListing,
      'prioritySupport': prioritySupport,
      'features': features,
    };
  }

  static const List<SpotlightPlan> plans = [
    SpotlightPlan(
      id: 'basic',
      name: 'الباقة الأساسية للأفراد',
      description: 'مناسبة للمبتدئين',
      price: 49.0,
      durationInDays: 30,
      maxVideos: 5,
      features: [
        'رفع 5 فيديوهات شهرياً',
        'مدة الفيديو حتى دقيقة واحدة',
        'جودة HD للفيديو',
        '50 مشاهدة مجانية يومياً',
        '1000 مشاهدة مجانية شهرياً',
        '0.5 ريال لكل 100 مشاهدة إضافية',
        'دعم فني أساسي',
        'إحصائيات بسيطة',
      ],
    ),
    SpotlightPlan(
      id: 'pro',
      name: 'باقة الشركات الأساسية',
      description: 'مناسبة للشركات',
      price: 499.0,
      durationInDays: 30,
      maxVideos: 50,
      featuredListing: true,
      features: [
        'رفع 50 فيديو شهرياً',
        'مدة الفيديو حتى 5 دقائق',
        'جودة 4K للفيديو',
        '200 مشاهدة مجانية يومياً',
        '5000 مشاهدة مجانية شهرياً',
        '0.3 ريال لكل 100 مشاهدة إضافية',
        'دعم فني متقدم',
        'إحصائيات متقدمة',
        'عرض مميز في نتائج البحث',
      ],
    ),
    SpotlightPlan(
      id: 'premium',
      name: 'الباقة المميزة',
      description: 'أفضل قيمة',
      price: 999.0,
      durationInDays: 30,
      maxVideos: 100,
      featuredListing: true,
      prioritySupport: true,
      features: [
        'رفع 100 فيديو شهرياً',
        'مدة الفيديو غير محدودة',
        'جودة 8K للفيديو',
        'مشاهدات غير محدودة',
        'عرض مميز في نتائج البحث',
        'دعم فني متميز على مدار الساعة',
        'إحصائيات متقدمة مع تحليلات',
        'أدوات تسويقية متقدمة',
      ],
    ),
  ];
} 