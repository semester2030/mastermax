import 'package:flutter/material.dart';
import '../../models/real_estate/rental_payment_model.dart';
import '../../services/real_estate/rental_payment_service.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة دفعات الإيجار
///
/// يدير قائمة دفعات الإيجار والعمليات CRUD
class RentalPaymentProvider extends ChangeNotifier {
  final RentalPaymentService _paymentService;
  
  RentalPaymentProvider(this._paymentService) {
    logDebug('RentalPaymentProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<RentalPaymentModel> _payments = [];
  RentalPaymentModel? _selectedPayment;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RentalPaymentModel> get payments => List.unmodifiable(_payments);
  RentalPaymentModel? get selectedPayment => _selectedPayment;

  // ✅ إحصائيات سريعة
  List<RentalPaymentModel> get paidPayments => _payments.where((p) => p.status == PaymentStatus.paid).toList();
  List<RentalPaymentModel> get overduePayments => _payments.where((p) => p.isOverdue).toList();
  List<RentalPaymentModel> get duePayments => _payments.where((p) => p.isDueSoon).toList();
  double get totalPaid => paidPayments.fold<double>(0, (sum, payment) => sum + payment.amount);
  double get totalDue => _payments.where((p) => p.status != PaymentStatus.paid).fold<double>(0, (sum, payment) => sum + payment.amount);
  double get totalOverdue => overduePayments.fold<double>(0, (sum, payment) => sum + payment.amount);

  @override
  void dispose() {
    _isDisposed = true;
    _payments.clear();
    _selectedPayment = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  /// تحميل قائمة دفعات عقد إيجار معين
  Future<void> loadPayments(String rentalId) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Loading payments for rental: $rentalId');
      final payments = await _paymentService.getPaymentsByRental(rentalId);
      
      _safeSetState(() {
        _payments = payments;
      });
      
      logInfo('Loaded ${payments.length} payments successfully');

    } catch (e, stackTrace) {
      logError('Error loading payments', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_payments.isEmpty) {
          _payments = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// إنشاء جدول دفعات لعقد إيجار
  Future<void> createPaymentSchedule({
    required String rentalId,
    required double monthlyRent,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Creating payment schedule for rental: $rentalId');
      final paymentIds = await _paymentService.createPaymentSchedule(
        rentalId: rentalId,
        monthlyRent: monthlyRent,
        startDate: startDate,
        endDate: endDate,
      );
      
      // ✅ تحميل الدفعات الجديدة
      await loadPayments(rentalId);
      
      logInfo('Payment schedule created successfully with ${paymentIds.length} payments');

    } catch (e, stackTrace) {
      logError('Error creating payment schedule', e, stackTrace);
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

  /// تسجيل دفع دفعة
  Future<void> recordPayment(
    String paymentId, {
    required DateTime paidDate,
    String? receiptNumber,
    String? notes,
  }) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Recording payment: $paymentId');
      await _paymentService.recordPayment(
        paymentId,
        paidDate: paidDate,
        receiptNumber: receiptNumber,
        notes: notes,
      );
      
      // ✅ تحديث الدفعة في القائمة
      final payment = await _paymentService.getPayment(paymentId);
      if (payment != null) {
        _safeSetState(() {
          final index = _payments.indexWhere((p) => p.id == paymentId);
          if (index != -1) {
            _payments[index] = payment;
          }
          
          if (_selectedPayment?.id == paymentId) {
            _selectedPayment = payment;
          }
        });
      }

      logInfo('Payment recorded successfully');

    } catch (e, stackTrace) {
      logError('Error recording payment', e, stackTrace);
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

  /// إضافة دفعة جديدة
  Future<void> addPayment(RentalPaymentModel payment) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Adding new payment');
      final id = await _paymentService.addPayment(payment);
      final newPayment = await _paymentService.getPayment(id);
      
      if (newPayment != null) {
        _safeSetState(() {
          _payments.add(newPayment);
          _payments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        });
        logInfo('Payment added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding payment', e, stackTrace);
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

  /// تحديث بيانات دفعة
  Future<void> updatePayment(RentalPaymentModel payment) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating payment: ${payment.id}');
      final updatedPayment = payment.copyWith(updatedAt: DateTime.now());
      await _paymentService.updatePayment(updatedPayment);
      
      _safeSetState(() {
        final index = _payments.indexWhere((p) => p.id == payment.id);
        if (index != -1) {
          _payments[index] = updatedPayment;
        }
        
        if (_selectedPayment?.id == payment.id) {
          _selectedPayment = updatedPayment;
        }
      });

      logInfo('Payment updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating payment', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// حذف دفعة
  Future<void> deletePayment(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Deleting payment: $id');
      await _paymentService.deletePayment(id);
      
      _safeSetState(() {
        _payments.removeWhere((payment) => payment.id == id);
        if (_selectedPayment?.id == id) {
          _selectedPayment = null;
        }
      });

      logInfo('Payment deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting payment', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تحميل الدفعات المستحقة
  Future<void> loadDuePayments(String ownerId) async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final payments = await _paymentService.getDuePayments(ownerId);
      
      _safeSetState(() {
        _payments = payments;
      });

    } catch (e, stackTrace) {
      logError('Error loading due payments', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تحميل الدفعات المتأخرة
  Future<void> loadOverduePayments(String ownerId) async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final payments = await _paymentService.getOverduePayments(ownerId);
      
      _safeSetState(() {
        _payments = payments;
      });

    } catch (e, stackTrace) {
      logError('Error loading overdue payments', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// اختيار دفعة
  void selectPayment(RentalPaymentModel? payment) {
    _safeSetState(() {
      _selectedPayment = payment;
    });
    logDebug('Selected payment: ${payment?.id ?? 'None'}');
  }

  /// الحصول على دفعة بواسطة المعرف
  RentalPaymentModel? getPaymentById(String id) {
    try {
      return _payments.firstWhere((payment) => payment.id == id);
    } catch (e) {
      return null;
    }
  }
}
