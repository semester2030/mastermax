import 'package:flutter/material.dart';
import '../../models/real_estate/real_estate_customer_model.dart';
import '../../services/real_estate/real_estate_customers_service.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة عملاء العقارات
///
/// يدير قائمة العملاء والعمليات CRUD
class RealEstateCustomersProvider extends ChangeNotifier {
  final RealEstateCustomersService _customersService;
  final AuthState _authState;
  
  RealEstateCustomersProvider(this._customersService, this._authState) {
    logDebug('RealEstateCustomersProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<RealEstateCustomerModel> _customers = [];
  RealEstateCustomerModel? _selectedCustomer;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RealEstateCustomerModel> get customers => List.unmodifiable(_customers);
  RealEstateCustomerModel? get selectedCustomer => _selectedCustomer;

  @override
  void dispose() {
    _isDisposed = true;
    _customers.clear();
    _selectedCustomer = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  /// تحميل قائمة العملاء
  Future<void> loadCustomers() async {
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

      logInfo('Loading customers for company: ${user.id}');
      final customers = await _customersService.getCustomers(user.id);
      
      _safeSetState(() {
        _customers = customers;
      });
      
      logInfo('Loaded ${customers.length} customers successfully');

    } catch (e, stackTrace) {
      logError('Error loading customers', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_customers.isEmpty) {
          _customers = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// إضافة عميل جديد
  Future<void> addCustomer(RealEstateCustomerModel customer) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول لإضافة عميل';
      }

      logInfo('Adding new customer for company: ${user.id}');

      final customerWithCompany = customer.copyWith(
        companyId: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _customersService.addCustomer(customerWithCompany);
      final newCustomer = await _customersService.getCustomer(id);
      
      if (newCustomer != null) {
        _safeSetState(() {
          _customers.insert(0, newCustomer);
        });
        logInfo('Customer added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding customer', e, stackTrace);
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

  /// تحديث بيانات عميل
  Future<void> updateCustomer(RealEstateCustomerModel customer) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating customer: ${customer.id}');
      final updatedCustomer = customer.copyWith(updatedAt: DateTime.now());
      await _customersService.updateCustomer(updatedCustomer);
      
      _safeSetState(() {
        final index = _customers.indexWhere((c) => c.id == customer.id);
        if (index != -1) {
          _customers[index] = updatedCustomer;
        }
        
        if (_selectedCustomer?.id == customer.id) {
          _selectedCustomer = updatedCustomer;
        }
      });

      logInfo('Customer updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating customer', e, stackTrace);
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

  /// حذف عميل
  Future<void> deleteCustomer(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Deleting customer: $id');
      await _customersService.deleteCustomer(id);
      
      _safeSetState(() {
        _customers.removeWhere((customer) => customer.id == id);
        if (_selectedCustomer?.id == id) {
          _selectedCustomer = null;
        }
      });

      logInfo('Customer deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting customer', e, stackTrace);
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

  /// اختيار عميل
  void selectCustomer(RealEstateCustomerModel? customer) {
    _safeSetState(() {
      _selectedCustomer = customer;
    });
    logDebug('Selected customer: ${customer?.id ?? 'None'}');
  }

  /// الحصول على عميل بواسطة المعرف
  RealEstateCustomerModel? getCustomerById(String id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }
}
