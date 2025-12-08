import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/property_models.dart';

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

  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  String? get error => _error;
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

  Future<void> initializeData() async {
    try {
      _setLoading(true);
      _error = null;
      
      // تأخير مصطنع لمحاكاة تحميل البيانات
      await Future.delayed(const Duration(seconds: 1));
      await _loadDummyData();
      
      _setLoading(false);
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل البيانات: $e';
      _setLoading(false);
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

  Future<void> _loadDummyData() async {
    // إضافة عقارات للمخزون
    _inventory.clear(); // مسح البيانات القديمة
    _inventory.addAll([
      PropertyDetails(
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

  void addNewSale(PropertyDetails property, double amount, PaymentMethod paymentMethod) {
    final sale = Sale(
      propertyDetails: property,
      amount: amount,
      paymentMethod: paymentMethod,
      date: _selectedDate,
      daysToSell: property.daysInMarket,
    );

    _sales.add(sale);
    _inventory.remove(property);
    notifyListeners();
  }

  Future<void> exportToExcel() async {
    try {
      // تنفيذ تصدير Excel
      debugPrint('تم تصدير Excel');
    } catch (e) {
      debugPrint('خطأ في تصدير Excel: $e');
      rethrow;
    }
  }

  Future<void> exportToPDF() async {
    if (_isExporting) return;
    try {
      _setExporting(true);
      await Future.delayed(const Duration(seconds: 2)); // محاكاة عملية التصدير
      debugPrint('تم تصدير PDF');
    } catch (e) {
      debugPrint('خطأ في تصدير PDF: $e');
    } finally {
      _setExporting(false);
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