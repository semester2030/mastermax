import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BusinessAnalyticsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _analytics = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get analytics => _analytics;

  Future<void> loadAnalytics(String businessId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      if (businessId.isEmpty) {
        _analytics = _getEmptyAnalytics();
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // ✅ جلب المبيعات من Firestore
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('companyId', isEqualTo: businessId)
          .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      // ✅ حساب الإيرادات والأرباح
      double totalRevenue = 0.0;
      double totalProfit = 0.0;
      final monthlySalesMap = <String, double>{};
      final monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
                   'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      
      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final salePrice = (data['salePrice'] as num?)?.toDouble() ?? 0.0;
        final profit = (data['profit'] as num?)?.toDouble() ?? 0.0;
        
        totalRevenue += salePrice;
        totalProfit += profit;
        
        // حساب المبيعات الشهرية
        final saleDate = data['saleDate'] is Timestamp
            ? (data['saleDate'] as Timestamp).toDate()
            : DateTime.now();
        final monthIndex = saleDate.month - 1;
        if (monthIndex >= 0 && monthIndex < monthNames.length) {
          final monthName = monthNames[monthIndex];
          monthlySalesMap[monthName] = (monthlySalesMap[monthName] ?? 0.0) + salePrice;
        }
      }
      
      // ✅ جلب المخزون من Firestore
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('ownerId', isEqualTo: businessId)
          .where('status', isEqualTo: 'available')
          .get();
      
      int totalInventoryItems = inventorySnapshot.docs.length;
      double totalInventoryValue = 0.0;
      
      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        totalInventoryValue += price;
      }
      
      // ✅ تجميع البيانات
      _analytics = {
        'revenue': totalRevenue,
        'expenses': 0.0, // TODO: إضافة حساب المصروفات من collection منفصل
        'profit': totalProfit,
        'growth': {
          'revenue': 0, // TODO: حساب النمو مقارنة بالفترة السابقة
          'expenses': 0,
          'profit': 0,
        },
        'expenses_breakdown': {
          'التسويق': 0.0,
          'الرواتب': 0.0,
          'الصيانة': 0.0,
          'أخرى': 0.0,
        },
        'monthly_sales': monthlySalesMap.entries.map((e) => {
          'month': e.key,
          'amount': e.value,
        }).toList(),
        'inventory': {
          'total_items': totalInventoryItems,
          'total_value': totalInventoryValue,
        },
        'marketing': {
          'views': 0, // TODO: إضافة من collection منفصل
          'leads': 0,
          'conversions': 0,
        },
        'isEmpty': totalRevenue == 0 && totalInventoryItems == 0,
      };
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في loadAnalytics: $e');
      _error = 'حدث خطأ أثناء تحميل البيانات: $e';
      _analytics = _getEmptyAnalytics();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Map<String, dynamic> _getEmptyAnalytics() {
    return {
      'revenue': 0.0,
      'expenses': 0.0,
      'profit': 0.0,
      'growth': {
        'revenue': 0,
        'expenses': 0,
        'profit': 0,
      },
      'expenses_breakdown': {},
      'monthly_sales': [],
      'inventory': {
        'total_items': 0,
        'total_value': 0.0,
      },
      'marketing': {
        'views': 0,
        'leads': 0,
        'conversions': 0,
      },
      'isEmpty': true,
    };
  }
}
