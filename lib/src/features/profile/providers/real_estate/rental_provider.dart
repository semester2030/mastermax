import 'package:flutter/material.dart';
import '../../models/real_estate/rental_model.dart';
import '../../services/real_estate/rental_service.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة عقود الإيجار
///
/// يدير قائمة عقود الإيجار والعمليات CRUD
class RentalProvider extends ChangeNotifier {
  final RentalService _rentalService;
  final AuthState _authState;
  
  RentalProvider(this._rentalService, this._authState) {
    logDebug('RentalProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<RentalModel> _rentals = [];
  RentalModel? _selectedRental;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RentalModel> get rentals => List.unmodifiable(_rentals);
  RentalModel? get selectedRental => _selectedRental;

  // ✅ إحصائيات سريعة
  List<RentalModel> get activeRentals => _rentals.where((r) => r.status == RentalStatus.active).toList();
  List<RentalModel> get expiringRentals => _rentals.where((r) => r.isNearExpiry).toList();
  double get totalMonthlyRevenue => activeRentals.fold<double>(0, (sum, rental) => sum + rental.monthlyRent);
  double get totalDeposits => _rentals.fold<double>(0, (sum, rental) => sum + rental.deposit);
  int get rentalsCount => _rentals.length;
  int get activeRentalsCount => activeRentals.length;

  @override
  void dispose() {
    _isDisposed = true;
    _rentals.clear();
    _selectedRental = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  /// تحميل قائمة عقود الإيجار
  Future<void> loadRentals() async {
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

      logInfo('Loading rentals for owner: ${user.id}');
      final rentals = await _rentalService.getRentals(user.id);
      
      _safeSetState(() {
        _rentals = rentals;
      });
      
      logInfo('Loaded ${rentals.length} rentals successfully');

    } catch (e, stackTrace) {
      logError('Error loading rentals', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_rentals.isEmpty) {
          _rentals = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تحميل العقود النشطة فقط
  Future<void> loadActiveRentals() async {
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

      final rentals = await _rentalService.getActiveRentals(user.id);
      
      _safeSetState(() {
        _rentals = rentals;
      });

    } catch (e, stackTrace) {
      logError('Error loading active rentals', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تحميل العقود القريبة من الانتهاء
  Future<void> loadExpiringRentals({int daysThreshold = 30}) async {
    try {
      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول';
      }

      final rentals = await _rentalService.getExpiringRentals(user.id, daysThreshold: daysThreshold);
      
      _safeSetState(() {
        _rentals = rentals;
      });

    } catch (e, stackTrace) {
      logError('Error loading expiring rentals', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    }
  }

  /// إضافة عقد إيجار جديد
  Future<void> addRental(RentalModel rental) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول لإضافة عقد إيجار';
      }

      logInfo('Adding new rental for owner: ${user.id}');

      final rentalWithOwner = rental.copyWith(
        ownerId: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _rentalService.addRental(rentalWithOwner);
      final newRental = await _rentalService.getRental(id);
      
      if (newRental != null) {
        _safeSetState(() {
          _rentals.insert(0, newRental);
        });
        logInfo('Rental added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding rental', e, stackTrace);
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

  /// تحديث بيانات عقد إيجار
  Future<void> updateRental(RentalModel rental) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating rental: ${rental.id}');
      final updatedRental = rental.copyWith(updatedAt: DateTime.now());
      await _rentalService.updateRental(updatedRental);
      
      _safeSetState(() {
        final index = _rentals.indexWhere((r) => r.id == rental.id);
        if (index != -1) {
          _rentals[index] = updatedRental;
        }
        
        if (_selectedRental?.id == rental.id) {
          _selectedRental = updatedRental;
        }
      });

      logInfo('Rental updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating rental', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// حذف عقد إيجار
  Future<void> deleteRental(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final rental = getRentalById(id);
      if (rental == null) {
        throw 'عقد الإيجار غير موجود';
      }

      logInfo('Deleting rental: $id');
      await _rentalService.deleteRental(id, rental.propertyId);
      
      _safeSetState(() {
        _rentals.removeWhere((rental) => rental.id == id);
        if (_selectedRental?.id == id) {
          _selectedRental = null;
        }
      });

      logInfo('Rental deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting rental', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// تجديد عقد إيجار
  Future<void> renewRental(RentalModel rental, DateTime newEndDate) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Renewing rental: ${rental.id}');
      final newRentalId = await _rentalService.renewRental(rental, newEndDate);
      final newRental = await _rentalService.getRental(newRentalId);
      
      if (newRental != null) {
        _safeSetState(() {
          // تحديث العقد القديم
          final index = _rentals.indexWhere((r) => r.id == rental.id);
          if (index != -1) {
            _rentals[index] = rental.copyWith(
              status: RentalStatus.renewed,
              updatedAt: DateTime.now(),
            );
          }
          // إضافة العقد الجديد
          _rentals.insert(0, newRental);
        });
        logInfo('Rental renewed successfully');
      }

    } catch (e, stackTrace) {
      logError('Error renewing rental', e, stackTrace);
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

  /// إلغاء عقد إيجار
  Future<void> cancelRental(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final rental = getRentalById(id);
      if (rental == null) {
        throw 'عقد الإيجار غير موجود';
      }

      logInfo('Cancelling rental: $id');
      await _rentalService.cancelRental(id, rental.propertyId);
      
      _safeSetState(() {
        final index = _rentals.indexWhere((r) => r.id == id);
        if (index != -1) {
          _rentals[index] = _rentals[index].copyWith(
            status: RentalStatus.cancelled,
            updatedAt: DateTime.now(),
          );
        }
        
        if (_selectedRental?.id == id) {
          _selectedRental = _selectedRental!.copyWith(
            status: RentalStatus.cancelled,
            updatedAt: DateTime.now(),
          );
        }
      });

      logInfo('Rental cancelled successfully');

    } catch (e, stackTrace) {
      logError('Error cancelling rental', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// اختيار عقد إيجار
  void selectRental(RentalModel? rental) {
    _safeSetState(() {
      _selectedRental = rental;
    });
    logDebug('Selected rental: ${rental?.id ?? 'None'}');
  }

  /// الحصول على عقد إيجار بواسطة المعرف
  RentalModel? getRentalById(String id) {
    try {
      return _rentals.firstWhere((rental) => rental.id == id);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على عقود إيجار لعقار معين
  List<RentalModel> getRentalsByProperty(String propertyId) {
    return _rentals.where((rental) => rental.propertyId == propertyId).toList();
  }
}
