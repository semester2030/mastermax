import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerInteraction {
  final String customerId;
  final String type;
  final DateTime date;
  final String notes;

  CustomerInteraction({
    required this.customerId,
    required this.type,
    required this.date,
    required this.notes,
  });

  factory CustomerInteraction.fromJson(Map<String, dynamic> json) {
    return CustomerInteraction(
      customerId: json['customerId'],
      type: json['type'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }
}

class RecentSale {
  final String propertyId;
  final double amount;
  final DateTime date;
  final String status;

  RecentSale({
    required this.propertyId,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory RecentSale.fromJson(Map<String, dynamic> json) {
    return RecentSale(
      propertyId: json['propertyId'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }
}

class BusinessAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<BusinessAnalytics> getAnalytics(
    String businessId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (businessId == 'trial_user') {
        return _getTrialData(startDate: startDate, endDate: endDate);
      }

      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('analytics')
          .doc('summary')
          .get();

      if (doc.exists) {
        return BusinessAnalytics.fromJson(doc.data()!);
      } else {
        return _getTrialData(startDate: startDate, endDate: endDate);
      }
    } catch (e) {
      return _getTrialData(startDate: startDate, endDate: endDate);
    }
  }

  BusinessAnalytics _getTrialData({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final monthlySales = <String, double>{};
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final monthName = _getArabicMonthName(currentDate.month);
      monthlySales[monthName] = 35000 + (currentDate.day * 500);
      currentDate = DateTime(currentDate.year, currentDate.month + 1);
    }

    return BusinessAnalytics(
      financialSummary: FinancialSummary(
        totalRevenue: 250000,
        expenses: 120000,
        profit: 130000,
        monthlySales: monthlySales,
      ),
      inventory: Inventory(
        totalItems: 25,
        totalValue: 750000,
        items: [
          InventoryItem(
            name: 'شقة فاخرة - الرياض',
            category: 'شقق',
            quantity: 5,
            value: 250000,
          ),
          InventoryItem(
            name: 'فيلا مع مسبح - جدة',
            category: 'فلل',
            quantity: 3,
            value: 350000,
          ),
          InventoryItem(
            name: 'أرض سكنية - الدمام',
            category: 'أراضي',
            quantity: 8,
            value: 100000,
          ),
          InventoryItem(
            name: 'مكتب تجاري - الرياض',
            category: 'مكاتب',
            quantity: 4,
            value: 150000,
          ),
        ],
      ),
      sales: Sales(
        total: 45,
        successful: 32,
      ),
      marketingMetrics: MarketingMetrics(
        views: 12500,
        leads: 280,
        conversions: 32,
      ),
      customerInteractions: _generateTrialInteractions(startDate, endDate),
      recentSales: _generateTrialSales(startDate, endDate),
      sourceStats: {
        'موقع الشركة': 45,
        'تطبيق الجوال': 30,
        'وسطاء': 15,
        'إعلانات': 10,
      },
    );
  }

  List<CustomerInteraction> _generateTrialInteractions(DateTime start, DateTime end) {
    final interactions = <CustomerInteraction>[];
    final currentDate = end;
    for (var i = 0; i < 5; i++) {
      interactions.add(
        CustomerInteraction(
          customerId: 'trial_customer_$i',
          type: i % 2 == 0 ? 'استفسار' : 'معاينة',
          date: currentDate.subtract(Duration(days: i)),
          notes: i % 2 == 0 ? 'استفسار عن عقار' : 'معاينة عقار',
        ),
      );
    }
    return interactions;
  }

  List<RecentSale> _generateTrialSales(DateTime start, DateTime end) {
    final sales = <RecentSale>[];
    final currentDate = end;
    for (var i = 0; i < 5; i++) {
      sales.add(
        RecentSale(
          propertyId: 'prop_$i',
          amount: 500000 + (i * 100000),
          date: currentDate.subtract(Duration(days: i * 2)),
          status: i % 3 == 0 ? 'مكتمل' : (i % 3 == 1 ? 'قيد التنفيذ' : 'معلق'),
        ),
      );
    }
    return sales;
  }

  String _getArabicMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }
}

class BusinessAnalytics {
  final FinancialSummary financialSummary;
  final Inventory inventory;
  final Sales sales;
  final MarketingMetrics marketingMetrics;
  final List<CustomerInteraction> customerInteractions;
  final List<RecentSale> recentSales;
  final Map<String, int> sourceStats;

  BusinessAnalytics({
    required this.financialSummary,
    required this.inventory,
    required this.sales,
    required this.marketingMetrics,
    required this.customerInteractions,
    required this.recentSales,
    required this.sourceStats,
  });

  factory BusinessAnalytics.fromJson(Map<String, dynamic> json) {
    return BusinessAnalytics(
      financialSummary: FinancialSummary.fromJson(json['financialSummary']),
      inventory: Inventory.fromJson(json['inventory']),
      sales: Sales.fromJson(json['sales']),
      marketingMetrics: MarketingMetrics.fromJson(json['marketingMetrics']),
      customerInteractions: (json['customerInteractions'] as List)
          .map((e) => CustomerInteraction.fromJson(e))
          .toList(),
      recentSales: (json['recentSales'] as List)
          .map((e) => RecentSale.fromJson(e))
          .toList(),
      sourceStats: Map<String, int>.from(json['sourceStats']),
    );
  }
}

class FinancialSummary {
  final double totalRevenue;
  final double expenses;
  final double profit;
  final Map<String, double> monthlySales;

  FinancialSummary({
    required this.totalRevenue,
    required this.expenses,
    required this.profit,
    required this.monthlySales,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalRevenue: json['totalRevenue'],
      expenses: json['expenses'],
      profit: json['profit'],
      monthlySales: Map<String, double>.from(json['monthlySales']),
    );
  }
}

class Inventory {
  final int totalItems;
  final double totalValue;
  final List<InventoryItem> items;

  Inventory({
    required this.totalItems,
    required this.totalValue,
    required this.items,
  });

  factory Inventory.fromJson(Map<String, dynamic> json) {
    return Inventory(
      totalItems: json['totalItems'],
      totalValue: json['totalValue'],
      items: (json['items'] as List)
          .map((e) => InventoryItem.fromJson(e))
          .toList(),
    );
  }
}

class InventoryItem {
  final String name;
  final String category;
  final int quantity;
  final double value;

  InventoryItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.value,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'],
      category: json['category'],
      quantity: json['quantity'],
      value: json['value'],
    );
  }
}

class Sales {
  final int total;
  final int successful;

  Sales({
    required this.total,
    required this.successful,
  });

  factory Sales.fromJson(Map<String, dynamic> json) {
    return Sales(
      total: json['total'],
      successful: json['successful'],
    );
  }
}

class MarketingMetrics {
  final int views;
  final int leads;
  final int conversions;

  MarketingMetrics({
    required this.views,
    required this.leads,
    required this.conversions,
  });

  factory MarketingMetrics.fromJson(Map<String, dynamic> json) {
    return MarketingMetrics(
      views: json['views'],
      leads: json['leads'],
      conversions: json['conversions'],
    );
  }
}
