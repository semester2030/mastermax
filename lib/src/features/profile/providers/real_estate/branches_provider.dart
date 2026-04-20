import 'package:flutter/material.dart';
import '../../models/real_estate/branch_model.dart';
import '../../services/real_estate/branches_service.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../../core/utils/logger.dart';

/// Provider لإدارة حالة الفروع
///
/// يدير قائمة الفروع والعمليات CRUD
class BranchesProvider extends ChangeNotifier {
  final BranchesService _branchesService;
  final AuthState _authState;
  
  BranchesProvider(this._branchesService, this._authState) {
    logDebug('BranchesProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  bool _isDisposed = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BranchModel> get branches => List.unmodifiable(_branches);
  BranchModel? get selectedBranch => _selectedBranch;

  @override
  void dispose() {
    _isDisposed = true;
    _branches.clear();
    _selectedBranch = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  /// تحميل قائمة الفروع
  Future<void> loadBranches() async {
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

      logInfo('Loading branches for company: ${user.id}');
      final branches = await _branchesService.getBranches(user.id);
      
      _safeSetState(() {
        _branches = branches;
      });
      
      logInfo('Loaded ${branches.length} branches successfully');

    } catch (e, stackTrace) {
      logError('Error loading branches', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_branches.isEmpty) {
          _branches = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// إضافة فرع جديد
  Future<void> addBranch(BranchModel branch) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول لإضافة فرع';
      }

      logInfo('Adding new branch for company: ${user.id}');

      final branchWithCompany = branch.copyWith(
        companyId: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _branchesService.addBranch(branchWithCompany);
      final newBranch = await _branchesService.getBranch(id);
      
      if (newBranch != null) {
        _safeSetState(() {
          _branches.insert(0, newBranch);
        });
        logInfo('Branch added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding branch', e, stackTrace);
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

  /// تحديث بيانات فرع
  Future<void> updateBranch(BranchModel branch) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating branch: ${branch.id}');
      final updatedBranch = branch.copyWith(updatedAt: DateTime.now());
      await _branchesService.updateBranch(updatedBranch);
      
      _safeSetState(() {
        final index = _branches.indexWhere((b) => b.id == branch.id);
        if (index != -1) {
          _branches[index] = updatedBranch;
        }
        
        if (_selectedBranch?.id == branch.id) {
          _selectedBranch = updatedBranch;
        }
      });

      logInfo('Branch updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating branch', e, stackTrace);
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

  /// حذف فرع
  Future<void> deleteBranch(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Deleting branch: $id');
      await _branchesService.deleteBranch(id);
      
      _safeSetState(() {
        _branches.removeWhere((branch) => branch.id == id);
        if (_selectedBranch?.id == id) {
          _selectedBranch = null;
        }
      });

      logInfo('Branch deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting branch', e, stackTrace);
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

  /// اختيار فرع
  void selectBranch(BranchModel? branch) {
    _safeSetState(() {
      _selectedBranch = branch;
    });
    logDebug('Selected branch: ${branch?.id ?? 'None'}');
  }

  /// الحصول على فرع بواسطة المعرف
  BranchModel? getBranchById(String id) {
    try {
      return _branches.firstWhere((branch) => branch.id == id);
    } catch (e) {
      return null;
    }
  }
}
