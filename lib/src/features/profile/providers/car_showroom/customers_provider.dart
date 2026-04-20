import 'package:flutter/material.dart';
import '../../models/car_showroom/customer_model.dart';
import '../../services/car_showroom/customers_service.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة العملاء
///
/// يدير قائمة العملاء والعمليات CRUD
class CustomersProvider extends ChangeNotifier {
  final CustomersService _customersService;
  final AuthState _authState;
  
  CustomersProvider(this._customersService, this._authState) {
    logDebug('CustomersProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CustomerModel> get customers => List.unmodifiable(_customers);
  CustomerModel? get selectedCustomer => _selectedCustomer;

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

      logInfo('Loading customers for seller: ${user.id}');
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
  Future<void> addCustomer(CustomerModel customer) async {
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

      logInfo('Adding new customer for seller: ${user.id}');

      final customerWithSeller = customer.copyWith(
        sellerId: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _customersService.addCustomer(customerWithSeller);
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
  Future<void> updateCustomer(CustomerModel customer) async {
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
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// اختيار عميل
  void selectCustomer(CustomerModel? customer) {
    _safeSetState(() {
      _selectedCustomer = customer;
    });
    logDebug('Selected customer: ${customer?.id ?? 'None'}');
  }

  /// الحصول على عميل بواسطة المعرف
  CustomerModel? getCustomerById(String id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }
}
