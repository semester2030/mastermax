/// نموذج تفاصيل الغرف والمساحات للعقار
class PropertyRoomDetails {
  // ✅ غرف النوم
  final int bedrooms; // عدد غرف النوم
  final int masterBedrooms; // عدد غرف النوم الرئيسية
  final Map<String, double> bedroomAreas; // مساحات غرف النوم (مثال: {'غرفة نوم 1': 25.5, 'غرفة نوم 2': 20.0})
  
  // ✅ غرف المعيشة
  final int livingRooms; // عدد غرف المعيشة
  final Map<String, double> livingRoomAreas; // مساحات غرف المعيشة
  
  // ✅ المجالس
  final int majlis; // عدد المجالس
  final int menMajlis; // مجلس رجال
  final int womenMajlis; // مجلس نساء
  final Map<String, double> majlisAreas; // مساحات المجالس
  
  // ✅ المقلط (غرفة الطعام)
  final int diningRooms; // عدد المقلط
  final Map<String, double> diningRoomAreas; // مساحات المقلط
  
  // ✅ المطابخ
  final int kitchens; // عدد المطابخ
  final Map<String, double> kitchenAreas; // مساحات المطابخ
  
  // ✅ الحمامات
  final int bathrooms; // إجمالي الحمامات
  final int masterBathrooms; // حمامات رئيسية
  final int guestBathrooms; // حمامات ضيوف
  final int serviceBathrooms; // حمامات خدمة
  final Map<String, double> bathroomAreas; // مساحات الحمامات
  
  // ✅ غرف أخرى
  final int storageRooms; // غرف تخزين
  final int maidRooms; // غرف خادمة
  final int driverRooms; // غرف سائق
  final int laundryRooms; // غرف غسيل
  final Map<String, double> otherRoomAreas; // مساحات الغرف الأخرى
  
  // ✅ المساحات الإجمالية
  final double totalBuiltArea; // المساحة المبنية الإجمالية
  final double landArea; // مساحة الأرض
  final double gardenArea; // مساحة الحديقة
  final double yardArea; // مساحة الحوش
  
  const PropertyRoomDetails({
    this.bedrooms = 0,
    this.masterBedrooms = 0,
    this.bedroomAreas = const {},
    this.livingRooms = 0,
    this.livingRoomAreas = const {},
    this.majlis = 0,
    this.menMajlis = 0,
    this.womenMajlis = 0,
    this.majlisAreas = const {},
    this.diningRooms = 0,
    this.diningRoomAreas = const {},
    this.kitchens = 0,
    this.kitchenAreas = const {},
    this.bathrooms = 0,
    this.masterBathrooms = 0,
    this.guestBathrooms = 0,
    this.serviceBathrooms = 0,
    this.bathroomAreas = const {},
    this.storageRooms = 0,
    this.maidRooms = 0,
    this.driverRooms = 0,
    this.laundryRooms = 0,
    this.otherRoomAreas = const {},
    this.totalBuiltArea = 0.0,
    this.landArea = 0.0,
    this.gardenArea = 0.0,
    this.yardArea = 0.0,
  });

  /// إنشاء من JSON
  factory PropertyRoomDetails.fromJson(Map<String, dynamic> json) {
    return PropertyRoomDetails(
      bedrooms: json['bedrooms'] as int? ?? 0,
      masterBedrooms: json['masterBedrooms'] as int? ?? 0,
      bedroomAreas: Map<String, double>.from(
        (json['bedroomAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      livingRooms: json['livingRooms'] as int? ?? 0,
      livingRoomAreas: Map<String, double>.from(
        (json['livingRoomAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      majlis: json['majlis'] as int? ?? 0,
      menMajlis: json['menMajlis'] as int? ?? 0,
      womenMajlis: json['womenMajlis'] as int? ?? 0,
      majlisAreas: Map<String, double>.from(
        (json['majlisAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      diningRooms: json['diningRooms'] as int? ?? 0,
      diningRoomAreas: Map<String, double>.from(
        (json['diningRoomAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      kitchens: json['kitchens'] as int? ?? 0,
      kitchenAreas: Map<String, double>.from(
        (json['kitchenAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      bathrooms: json['bathrooms'] as int? ?? 0,
      masterBathrooms: json['masterBathrooms'] as int? ?? 0,
      guestBathrooms: json['guestBathrooms'] as int? ?? 0,
      serviceBathrooms: json['serviceBathrooms'] as int? ?? 0,
      bathroomAreas: Map<String, double>.from(
        (json['bathroomAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      storageRooms: json['storageRooms'] as int? ?? 0,
      maidRooms: json['maidRooms'] as int? ?? 0,
      driverRooms: json['driverRooms'] as int? ?? 0,
      laundryRooms: json['laundryRooms'] as int? ?? 0,
      otherRoomAreas: Map<String, double>.from(
        (json['otherRoomAreas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
      ),
      totalBuiltArea: (json['totalBuiltArea'] as num?)?.toDouble() ?? 0.0,
      landArea: (json['landArea'] as num?)?.toDouble() ?? 0.0,
      gardenArea: (json['gardenArea'] as num?)?.toDouble() ?? 0.0,
      yardArea: (json['yardArea'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'bedrooms': bedrooms,
      'masterBedrooms': masterBedrooms,
      'bedroomAreas': bedroomAreas,
      'livingRooms': livingRooms,
      'livingRoomAreas': livingRoomAreas,
      'majlis': majlis,
      'menMajlis': menMajlis,
      'womenMajlis': womenMajlis,
      'majlisAreas': majlisAreas,
      'diningRooms': diningRooms,
      'diningRoomAreas': diningRoomAreas,
      'kitchens': kitchens,
      'kitchenAreas': kitchenAreas,
      'bathrooms': bathrooms,
      'masterBathrooms': masterBathrooms,
      'guestBathrooms': guestBathrooms,
      'serviceBathrooms': serviceBathrooms,
      'bathroomAreas': bathroomAreas,
      'storageRooms': storageRooms,
      'maidRooms': maidRooms,
      'driverRooms': driverRooms,
      'laundryRooms': laundryRooms,
      'otherRoomAreas': otherRoomAreas,
      'totalBuiltArea': totalBuiltArea,
      'landArea': landArea,
      'gardenArea': gardenArea,
      'yardArea': yardArea,
    };
  }

  /// إنشاء نسخة معدلة
  PropertyRoomDetails copyWith({
    int? bedrooms,
    int? masterBedrooms,
    Map<String, double>? bedroomAreas,
    int? livingRooms,
    Map<String, double>? livingRoomAreas,
    int? majlis,
    int? menMajlis,
    int? womenMajlis,
    Map<String, double>? majlisAreas,
    int? diningRooms,
    Map<String, double>? diningRoomAreas,
    int? kitchens,
    Map<String, double>? kitchenAreas,
    int? bathrooms,
    int? masterBathrooms,
    int? guestBathrooms,
    int? serviceBathrooms,
    Map<String, double>? bathroomAreas,
    int? storageRooms,
    int? maidRooms,
    int? driverRooms,
    int? laundryRooms,
    Map<String, double>? otherRoomAreas,
    double? totalBuiltArea,
    double? landArea,
    double? gardenArea,
    double? yardArea,
  }) {
    return PropertyRoomDetails(
      bedrooms: bedrooms ?? this.bedrooms,
      masterBedrooms: masterBedrooms ?? this.masterBedrooms,
      bedroomAreas: bedroomAreas ?? this.bedroomAreas,
      livingRooms: livingRooms ?? this.livingRooms,
      livingRoomAreas: livingRoomAreas ?? this.livingRoomAreas,
      majlis: majlis ?? this.majlis,
      menMajlis: menMajlis ?? this.menMajlis,
      womenMajlis: womenMajlis ?? this.womenMajlis,
      majlisAreas: majlisAreas ?? this.majlisAreas,
      diningRooms: diningRooms ?? this.diningRooms,
      diningRoomAreas: diningRoomAreas ?? this.diningRoomAreas,
      kitchens: kitchens ?? this.kitchens,
      kitchenAreas: kitchenAreas ?? this.kitchenAreas,
      bathrooms: bathrooms ?? this.bathrooms,
      masterBathrooms: masterBathrooms ?? this.masterBathrooms,
      guestBathrooms: guestBathrooms ?? this.guestBathrooms,
      serviceBathrooms: serviceBathrooms ?? this.serviceBathrooms,
      bathroomAreas: bathroomAreas ?? this.bathroomAreas,
      storageRooms: storageRooms ?? this.storageRooms,
      maidRooms: maidRooms ?? this.maidRooms,
      driverRooms: driverRooms ?? this.driverRooms,
      laundryRooms: laundryRooms ?? this.laundryRooms,
      otherRoomAreas: otherRoomAreas ?? this.otherRoomAreas,
      totalBuiltArea: totalBuiltArea ?? this.totalBuiltArea,
      landArea: landArea ?? this.landArea,
      gardenArea: gardenArea ?? this.gardenArea,
      yardArea: yardArea ?? this.yardArea,
    );
  }
}
