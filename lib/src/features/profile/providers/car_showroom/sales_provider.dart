import 'package:flutter/material.dart';
import '../../models/car_showroom/sale_model.dart';
import '../../services/car_showroom/sales_service.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة المبيعات
///
/// يدير قائمة المبيعات والعمليات CRUD
class SalesProvider extends ChangeNotifier {
  final SalesService _salesService;
  final AuthState _authState;
  
  SalesProvider(this._salesService, this._authState) {
    logDebug('SalesProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<SaleModel> _sales = [];
  SaleModel? _selectedSale;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SaleModel> get sales => List.unmodifiable(_sales);
  SaleModel? get selectedSale => _selectedSale;

  // إحصائيات سريعة
  double get totalSales => _sales.fold<double>(0, (sum, sale) => sum + sale.salePrice);
  double get totalProfit => _sales.fold<double>(0, (sum, sale) => sum + (sale.profit ?? 0));
  double get averageSalePrice => _sales.isEmpty ? 0 : totalSales / _sales.length;
  int get salesCount => _sales.length;

  @override
  void dispose() {
    _isDisposed = true;
    _sales.clear();
    _selectedSale = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  /// تحميل قائمة المبيعات
  Future<void> loadSales() async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول';
      }

      logInfo('Loading sales for seller: ${user.id}');
      final sales = await _salesService.getSales(user.id);
      
      _safeSetState(() {
        _sales = sales;
      });
      
      logInfo('Loaded ${sales.length} sales successfully');

    } catch (e, stackTrace) {
      logError('Error loading sales', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_sales.isEmpty) {
          _sales = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// جلب المبيعات ضمن فترة زمنية
  Future<List<SaleModel>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول';
      }

      return await _salesService.getSalesByDateRange(user.id, startDate, endDate);
    } catch (e, stackTrace) {
      logError('Error getting sales by date range', e, stackTrace);
      rethrow;
    }
  }

  /// إضافة عملية بيع جديدة
  Future<void> addSale(SaleModel sale) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول لتسجيل عملية بيع';
      }

      logInfo('Adding new sale for seller: ${user.id}');

      final saleWithSeller = sale.copyWith(
        sellerId: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _salesService.addSale(saleWithSeller);
      final newSale = await _salesService.getSale(id);
      
      if (newSale != null) {
        _safeSetState(() {
          _sales.insert(0, newSale);
        });
        logInfo('Sale added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding sale', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
      rethrow;
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تحديث بيانات عملية بيع
  Future<void> updateSale(SaleModel sale) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating sale: ${sale.id}');
      final updatedSale = sale.copyWith(updatedAt: DateTime.now());
      await _salesService.updateSale(updatedSale);
      
      _safeSetState(() {
        final index = _sales.indexWhere((s) => s.id == sale.id);
        if (index != -1) {
          _sales[index] = updatedSale;
        }
        
        if (_selectedSale?.id == sale.id) {
          _selectedSale = updatedSale;
        }
      });

      logInfo('Sale updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating sale', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// حذف عملية بيع
  Future<void> deleteSale(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Deleting sale: $id');
      await _salesService.deleteSale(id);
      
      _safeSetState(() {
        _sales.removeWhere((sale) => sale.id == id);
        if (_selectedSale?.id == id) {
          _selectedSale = null;
        }
      });

      logInfo('Sale deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting sale', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// اختيار عملية بيع
  void selectSale(SaleModel? sale) {
    _safeSetState(() {
      _selectedSale = sale;
    });
    logDebug('Selected sale: ${sale?.id ?? 'None'}');
  }

  /// الحصول على عملية بيع بواسطة المعرف
  SaleModel? getSaleById(String id) {
    try {
      return _sales.firstWhere((sale) => sale.id == id);
    } catch (e) {
      return null;
    }
  }
}
