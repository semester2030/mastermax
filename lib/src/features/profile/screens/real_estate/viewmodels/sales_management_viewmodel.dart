import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../auth/providers/auth_state.dart';
import '../../../../properties/models/property_model.dart';
import '../models/property_models.dart' show PropertyType, PropertyDetails, PaymentMethod, Sale;
import '../../../services/real_estate/export_service.dart';

class SalesManagementViewModel extends ChangeNotifier {
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  final List<Sale> _sales = [];
  final List<PropertyDetails> _inventory = [];
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  bool _isExporting = false;
  final List<SaleData> _salesData = [];
  Map<String, double> _monthlySales = {};
  List<Transaction> _recentTransactions = [];
  final RealEstateExportService _exportService = RealEstateExportService();
  String? _exportError;

  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  String? get error => _error;
  String? get exportError => _exportError;
  DateTime get selectedDate => _selectedDate;
  List<Sale> get sales => _sales;
  List<PropertyDetails> get inventory => _inventory;
  NumberFormat get numberFormat => _numberFormat;
  List<SaleData> get salesData => _salesData;
  Map<String, double> get monthlySales => _monthlySales;
  List<Transaction> get recentTransactions => _recentTransactions;

  SalesManagementViewModel() {
    initializeData();
  }

  Future<void> initializeData({BuildContext? context}) async {
    try {
      _setLoading(true);
      _error = null;
      
      // ✅ جلب companyId من AuthState
      String? companyId;
      if (context != null) {
        final authState = Provider.of<AuthState>(context, listen: false);
        companyId = authState.user?.id;
      }
      
      if (companyId == null || companyId.isEmpty) {
        _error = 'لم يتم العثور على معرف الشركة';
        _setLoading(false);
        notifyListeners();
        return;
      }
      
      // ✅ مسح جميع البيانات القديمة
      _sales.clear();
      _inventory.clear();
      _salesData.clear();
      _monthlySales.clear();
      _recentTransactions.clear();
      
      // ✅ جلب العقارات المتاحة من Firestore (Automation)
      List<QueryDocumentSnapshot> propertyDocs = [];
      try {
        final propertiesSnapshot = await FirebaseFirestore.instance
            .collection('properties')
            .where('ownerId', isEqualTo: companyId)
            .where('status', isEqualTo: 'available') // فقط العقارات المتاحة
            .where('offerType', isEqualTo: 'sale') // فقط العقارات المعروضة للبيع
            .get();
        propertyDocs = propertiesSnapshot.docs;
      } catch (e) {
        // ✅ معالجة خطأ composite index - محاولة بدون offerType
        debugPrint('⚠️ خطأ في جلب العقارات (قد يكون بسبب composite index): $e');
        try {
          final propertiesSnapshot = await FirebaseFirestore.instance
              .collection('properties')
              .where('ownerId', isEqualTo: companyId)
              .where('status', isEqualTo: 'available')
              .get();
          // فلترة يدوية للعقارات المعروضة للبيع
          propertyDocs = propertiesSnapshot.docs.where((doc) {
            final data = doc.data();
            if (data is! Map<String, dynamic>) return false;
            return data['offerType'] == 'sale';
          }).toList();
        } catch (e2) {
          debugPrint('⚠️ خطأ في جلب العقارات (محاولة ثانية): $e2');
          final propertiesSnapshot = await FirebaseFirestore.instance
              .collection('properties')
              .where('ownerId', isEqualTo: companyId)
              .get();
          // فلترة يدوية
          propertyDocs = propertiesSnapshot.docs.where((doc) {
            final data = doc.data();
            if (data is! Map<String, dynamic>) return false;
            return (data['status'] == 'available' || data['status'] == null) &&
                   (data['offerType'] == 'sale' || data['offerType'] == null);
          }).toList();
        }
      }
      
      _inventory.clear();
      for (var doc in propertyDocs) {
        final data = doc.data();
        if (data is! Map<String, dynamic>) {
          debugPrint('⚠️ بيانات العقار ${doc.id} ليست من نوع Map<String, dynamic>');
          continue;
        }
        try {
          final property = _convertPropertyModelToPropertyDetails(
            doc.id,
            data,
          );
          if (property != null) {
            _inventory.add(property);
          }
        } catch (e) {
          debugPrint('خطأ في تحويل العقار ${doc.id}: $e');
        }
      }
      
      // ✅ جلب المبيعات من Firestore
      List<QueryDocumentSnapshot> salesDocs = [];
      try {
        final salesSnapshot = await FirebaseFirestore.instance
            .collection('sales')
            .where('companyId', isEqualTo: companyId)
            .orderBy('saleDate', descending: true)
            .get();
        salesDocs = salesSnapshot.docs;
      } catch (e) {
        // ✅ معالجة خطأ composite index - جلب بدون orderBy
        debugPrint('⚠️ خطأ في جلب المبيعات (قد يكون بسبب composite index): $e');
        final salesSnapshot = await FirebaseFirestore.instance
            .collection('sales')
            .where('companyId', isEqualTo: companyId)
            .get();
        // ترتيب يدوي
        salesDocs = salesSnapshot.docs.toList()
          ..sort((a, b) {
            final aDate = a.data()['saleDate'] is Timestamp
                ? (a.data()['saleDate'] as Timestamp).toDate()
                : DateTime.now();
            final bDate = b.data()['saleDate'] is Timestamp
                ? (b.data()['saleDate'] as Timestamp).toDate()
                : DateTime.now();
            return bDate.compareTo(aDate); // ترتيب تنازلي
          });
      }
      
      _sales.clear();
      for (var doc in salesDocs) {
        final data = doc.data();
        if (data is! Map<String, dynamic>) {
          debugPrint('⚠️ بيانات عملية البيع ${doc.id} ليست من نوع Map<String, dynamic>');
          continue;
        }
        try {
          final sale = _convertFirestoreToSale(doc.id, data);
          if (sale != null) {
            _sales.add(sale);
          }
        } catch (e) {
          debugPrint('خطأ في تحويل عملية البيع ${doc.id}: $e');
        }
      }
      
      // ✅ حساب المبيعات الشهرية تلقائياً
      _calculateMonthlySales();
      
      // ✅ تحديث المعاملات الأخيرة
      _updateRecentTransactions();
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل البيانات: $e';
      debugPrint('خطأ في initializeData: $e');
      _setLoading(false);
      notifyListeners();
    }
  }
  
  // ✅ تحويل PropertyModel من Firestore إلى PropertyDetails
  PropertyDetails? _convertPropertyModelToPropertyDetails(String id, Map<String, dynamic> data) {
    try {
      // حساب عدد الأيام في السوق
      final createdAt = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now();
      final daysInMarket = DateTime.now().difference(createdAt).inDays;
      
      // تحويل نوع العقار
      PropertyType propertyType;
      final typeStr = data['type']?.toString().toLowerCase() ?? '';
      switch (typeStr) {
        case 'apartment':
        case 'شقة':
          propertyType = PropertyType.apartment;
          break;
        case 'villa':
        case 'فيلا':
          propertyType = PropertyType.villa;
          break;
        case 'land':
        case 'أرض':
          propertyType = PropertyType.land;
          break;
        case 'commercial':
        case 'تجاري':
          propertyType = PropertyType.commercial;
          break;
        default:
          propertyType = PropertyType.apartment;
      }
      
      // ✅ سعر الشراء/التكلفة من Firestore (إذا لم يكن موجوداً، استخدم 80% من السعر الحالي كافتراض)
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final purchasePrice = data['purchasePrice'] != null
          ? (data['purchasePrice'] as num).toDouble()
          : price * 0.8; // افتراض أن سعر الشراء/التكلفة 80% من سعر البيع (إذا لم يتم إدخاله)
      
      return PropertyDetails(
        id: id,
        title: data['title'] ?? 'عقار بدون عنوان',
        type: propertyType,
        location: data['address'] ?? 'موقع غير محدد',
        area: (data['area'] as num?)?.toDouble() ?? 0.0,
        rooms: (data['rooms'] as num?)?.toInt() ?? 0,
        bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
        isFurnished: data['features']?['furnished'] == true || false,
        purchasePrice: purchasePrice,
        targetPrice: price,
        daysInMarket: daysInMarket,
      );
    } catch (e) {
      debugPrint('خطأ في _convertPropertyModelToPropertyDetails: $e');
      return null;
    }
  }
  
  // ✅ تحويل بيانات Firestore إلى Sale
  Sale? _convertFirestoreToSale(String id, Map<String, dynamic> data) {
    try {
      final propertyDetails = _convertPropertyModelToPropertyDetails(
        data['propertyId'] ?? '',
        {
          'title': data['propertyTitle'] ?? '',
          'type': data['propertyType'] ?? 'apartment',
          'address': data['propertyLocation'] ?? '',
          'area': data['propertyArea'] ?? 0,
          'rooms': data['propertyRooms'] ?? 0,
          'bathrooms': data['propertyBathrooms'] ?? 0,
          'price': data['salePrice'] ?? 0,
          'purchasePrice': data['purchasePrice'] ?? 0,
          'createdAt': data['createdAt'],
        },
      );
      
      if (propertyDetails == null) return null;
      
      // تحويل طريقة الدفع
      PaymentMethod paymentMethod;
      final paymentStr = data['paymentMethod']?.toString().toLowerCase() ?? 'cash';
      switch (paymentStr) {
        case 'cash':
        case 'نقداً':
          paymentMethod = PaymentMethod.cash;
          break;
        case 'installment':
        case 'تقسيط':
          paymentMethod = PaymentMethod.installment;
          break;
        case 'mortgage':
        case 'رهن عقاري':
          paymentMethod = PaymentMethod.mortgage;
          break;
        default:
          paymentMethod = PaymentMethod.cash;
      }
      
      final saleDate = data['saleDate'] is Timestamp
          ? (data['saleDate'] as Timestamp).toDate()
          : DateTime.now();
      
      return Sale(
        propertyDetails: propertyDetails,
        amount: (data['salePrice'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: paymentMethod,
        date: saleDate,
        daysToSell: (data['daysToSell'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('خطأ في _convertFirestoreToSale: $e');
      return null;
    }
  }
  
  // ✅ حساب المبيعات الشهرية تلقائياً
  void _calculateMonthlySales() {
    _monthlySales.clear();
    
    final monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
                   'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    
    for (var sale in _sales) {
      final monthIndex = sale.date.month - 1;
      if (monthIndex >= 0 && monthIndex < monthNames.length) {
        final monthName = monthNames[monthIndex];
        _monthlySales[monthName] = (_monthlySales[monthName] ?? 0.0) + sale.amount;
      }
    }
  }
  
  // ✅ تحديث المعاملات الأخيرة
  void _updateRecentTransactions() {
    _recentTransactions.clear();
    
    // أخذ آخر 5 عمليات بيع
    final recentSales = _sales.take(5).toList();
    for (var i = 0; i < recentSales.length; i++) {
      final sale = recentSales[i];
      _recentTransactions.add(
        Transaction(
          id: '$i',
          title: sale.propertyDetails.title,
          amount: sale.amount,
          date: sale.date,
          type: TransactionType.sale,
        ),
      );
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setExporting(bool value) {
    _isExporting = value;
    notifyListeners();
  }

  // TODO: يمكن استخدام هذه الدالة للاختبار - غير مستخدمة حالياً
  // ignore: unused_element
  Future<void> _loadDummyData() async {
    // إضافة عقارات للمخزون
    _inventory.clear(); // مسح البيانات القديمة
    _inventory.addAll([
      PropertyDetails(
        id: 'dummy_1', // ✅ إضافة id
        title: 'شقة فاخرة في الرياض',
        type: PropertyType.apartment,
        location: 'الرياض - حي النرجس',
        area: 200,
        rooms: 4,
        bathrooms: 3,
        isFurnished: true,
        purchasePrice: 800000,
        targetPrice: 950000,
        daysInMarket: 30,
      ),
      PropertyDetails(
        id: 'dummy_2', // ✅ إضافة id
        title: 'فيلا مع مسبح',
        type: PropertyType.villa,
        location: 'جدة - حي الشاطئ',
        area: 400,
        rooms: 6,
        bathrooms: 5,
        isFurnished: false,
        purchasePrice: 2000000,
        targetPrice: 2500000,
        daysInMarket: 45,
      ),
      PropertyDetails(
        id: 'dummy_3', // ✅ إضافة id
        title: 'أرض تجارية',
        type: PropertyType.land,
        location: 'الدمام - الشارع الأول',
        area: 1000,
        rooms: 0,
        bathrooms: 0,
        isFurnished: false,
        purchasePrice: 3000000,
        targetPrice: 3500000,
        daysInMarket: 60,
      ),
      PropertyDetails(
        id: 'dummy_4', // ✅ إضافة id
        title: 'معرض تجاري',
        type: PropertyType.commercial,
        location: 'الرياض - طريق الملك فهد',
        area: 300,
        rooms: 2,
        bathrooms: 2,
        isFurnished: false,
        purchasePrice: 1500000,
        targetPrice: 1800000,
        daysInMarket: 15,
      ),
      PropertyDetails(
        id: 'dummy_5', // ✅ إضافة id
        title: 'شقة سكنية',
        type: PropertyType.apartment,
        location: 'جدة - حي السلامة',
        area: 180,
        rooms: 3,
        bathrooms: 2,
        isFurnished: true,
        purchasePrice: 600000,
        targetPrice: 750000,
        daysInMarket: 25,
      ),
    ]);

    // إضافة عمليات بيع سابقة
    _sales.clear(); // مسح البيانات القديمة
    _sales.addAll([
      Sale(
        propertyDetails: PropertyDetails(
          id: 'dummy_sale_1', // ✅ إضافة id
          title: 'شقة في الرياض',
          type: PropertyType.apartment,
          location: 'الرياض - حي الورود',
          area: 180,
          rooms: 3,
          bathrooms: 2,
          isFurnished: true,
          purchasePrice: 700000,
          targetPrice: 850000,
          daysInMarket: 40,
        ),
        amount: 830000,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now().subtract(const Duration(days: 5)),
        daysToSell: 40,
      ),
      Sale(
        propertyDetails: PropertyDetails(
          id: 'dummy_sale_2', // ✅ إضافة id
          title: 'فيلا في جدة',
          type: PropertyType.villa,
          location: 'جدة - حي الروضة',
          area: 350,
          rooms: 5,
          bathrooms: 4,
          isFurnished: false,
          purchasePrice: 1800000,
          targetPrice: 2200000,
          daysInMarket: 55,
        ),
        amount: 2150000,
        paymentMethod: PaymentMethod.mortgage,
        date: DateTime.now().subtract(const Duration(days: 15)),
        daysToSell: 55,
      ),
    ]);

    // إضافة بيانات المبيعات الشهرية
    _monthlySales = {
      'يناير': 250000,
      'فبراير': 300000,
      'مارس': 280000,
      'أبريل': 320000,
      'مايو': 350000,
      'يونيو': 400000,
    };

    // إضافة المعاملات الأخيرة
    _recentTransactions = [
      Transaction(
        id: '1',
        title: 'بيع شقة',
        amount: 500000,
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: TransactionType.sale,
      ),
      Transaction(
        id: '2',
        title: 'بيع فيلا',
        amount: 1200000,
        date: DateTime.now().subtract(const Duration(days: 5)),
        type: TransactionType.sale,
      ),
    ];

    notifyListeners();
  }

  void updateSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> addNewSale(
    PropertyDetails property,
    double amount,
    PaymentMethod paymentMethod, {
    BuildContext? context,
  }) async {
    try {
      // ✅ جلب companyId من AuthState
      String? companyId;
      if (context != null) {
        final authState = Provider.of<AuthState>(context, listen: false);
        companyId = authState.user?.id;
      }
      
      if (companyId == null || companyId.isEmpty) {
        throw Exception('لم يتم العثور على معرف الشركة');
      }
      
      // ✅ حساب الربح تلقائياً
      final profit = amount - property.purchasePrice;
      
      // ✅ إضافة عملية البيع إلى Firestore
      await FirebaseFirestore.instance.collection('sales').add({
        'companyId': companyId,
        'propertyId': property.id,
        'propertyTitle': property.title,
        'propertyType': property.type.name,
        'propertyLocation': property.location,
        'propertyArea': property.area,
        'propertyRooms': property.rooms,
        'propertyBathrooms': property.bathrooms,
        'salePrice': amount,
        'purchasePrice': property.purchasePrice,
        'profit': profit, // ✅ حساب تلقائي
        'paymentMethod': paymentMethod.name,
        'saleDate': Timestamp.fromDate(_selectedDate),
        'daysToSell': property.daysInMarket,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ✅ تحديث حالة العقار في Firestore من "available" إلى "sold"
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .update({
        'status': 'sold',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // ✅ تحديث القائمة المحلية
      final sale = Sale(
        propertyDetails: property,
        amount: amount,
        paymentMethod: paymentMethod,
        date: _selectedDate,
        daysToSell: property.daysInMarket,
      );
      
      _sales.insert(0, sale); // إضافة في البداية (الأحدث أولاً)
      _inventory.removeWhere((p) => p.id == property.id);
      
      // ✅ تحديث المبيعات الشهرية والمعاملات الأخيرة
      _calculateMonthlySales();
      _updateRecentTransactions();
      
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة عملية البيع: $e';
      debugPrint('خطأ في addNewSale: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> exportToExcel({BuildContext? context, String? companyName}) async {
    if (_isExporting) return null;
    
    try {
      _setExporting(true);
      _exportError = null;
      notifyListeners();

      // ✅ جلب اسم الشركة
      String finalCompanyName = companyName ?? 'غير معروف';
      if (context != null && companyName == null) {
        final authState = Provider.of<AuthState>(context, listen: false);
        finalCompanyName = authState.user?.name ?? 'غير معروف';
      }

      // ✅ تصدير الملف
      final filePath = await _exportService.exportSalesToExcel(
        sales: _sales,
        companyName: finalCompanyName,
        startDate: null,
        endDate: null,
      );

      // ✅ مشاركة الملف
      await _exportService.shareFile(filePath, text: 'تقرير مبيعات العقارات', context: context);

      _setExporting(false);
      notifyListeners();
      return filePath;
    } catch (e) {
      _exportError = 'حدث خطأ في تصدير Excel: ${e.toString()}';
      debugPrint('خطأ في تصدير Excel: $e');
      _setExporting(false);
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> exportToPDF({BuildContext? context, String? companyName}) async {
    if (_isExporting) return null;
    
    try {
      _setExporting(true);
      _exportError = null;
      notifyListeners();

      // ✅ جلب اسم الشركة
      String finalCompanyName = companyName ?? 'غير معروف';
      if (context != null && companyName == null) {
        final authState = Provider.of<AuthState>(context, listen: false);
        finalCompanyName = authState.user?.name ?? 'غير معروف';
      }

      // ✅ تصدير الملف
      final filePath = await _exportService.exportSalesToPDF(
        sales: _sales,
        companyName: finalCompanyName,
        startDate: null,
        endDate: null,
      );

      // ✅ مشاركة الملف
      await _exportService.shareFile(filePath, text: 'تقرير مبيعات العقارات', context: context);

      _setExporting(false);
      notifyListeners();
      return filePath;
    } catch (e) {
      _exportError = 'حدث خطأ في تصدير PDF: ${e.toString()}';
      debugPrint('خطأ في تصدير PDF: $e');
      _setExporting(false);
      notifyListeners();
      rethrow;
    }
  }

  // إضافة دالة حساب متوسط وقت البيع
  double calculateAverageSaleTime() {
    if (_sales.isEmpty) return 0;
    final totalDays = _sales.fold<int>(0, (sum, sale) => sum + sale.daysToSell);
    return totalDays / _sales.length;
  }

  // إضافة دوال إحصائية مفيدة
  double get totalSales => _sales.fold<double>(0, (sum, sale) => sum + sale.amount);
  double get totalProfit => _sales.fold<double>(0, (sum, sale) => sum + sale.profit);
  double get averageSalePrice => _sales.isEmpty ? 0 : totalSales / _sales.length;
  double get averageProfit => _sales.isEmpty ? 0 : totalProfit / _sales.length;

  List<SaleData> get salesDataList => _sales.map((sale) => SaleData(
    id: sale.propertyDetails.title,
    title: sale.propertyDetails.title,
    description: '${sale.propertyDetails.location} - ${sale.paymentMethod.arabicName}',
    amount: sale.amount,
    date: sale.date,
  )).toList();
}

class SaleData {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime date;

  SaleData({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
  });
}

class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
  });
}

enum TransactionType {
  sale,
  purchase,
  expense,
} 