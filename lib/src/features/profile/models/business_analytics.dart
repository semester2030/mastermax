
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
      totalRevenue: json['totalRevenue'].toDouble(),
      expenses: json['expenses'].toDouble(),
      profit: json['profit'].toDouble(),
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
      totalValue: json['totalValue'].toDouble(),
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
      value: json['value'].toDouble(),
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
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }
} 