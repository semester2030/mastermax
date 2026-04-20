import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// ✅ مدير الذاكرة - يضمن تنظيف الموارد وتجنب memory leaks
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  final List<Disposable> _disposables = [];
  bool _isInitialized = false;

  /// تهيئة مدير الذاكرة
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    if (kDebugMode) {
      developer.log('✅ Memory Manager initialized');
    }
  }

  /// تسجيل مورد قابل للتخلص
  void register(Disposable disposable) {
    _disposables.add(disposable);
    if (kDebugMode) {
      developer.log('📝 Registered disposable: ${disposable.runtimeType}');
    }
  }

  /// إلغاء تسجيل مورد
  void unregister(Disposable disposable) {
    _disposables.remove(disposable);
  }

  /// تنظيف جميع الموارد المسجلة
  Future<void> cleanup() async {
    if (kDebugMode) {
      developer.log('🧹 Cleaning up ${_disposables.length} resources...');
    }
    
    for (final disposable in _disposables.toList()) {
      try {
        await disposable.dispose();
        if (kDebugMode) {
          developer.log('✅ Disposed: ${disposable.runtimeType}');
        }
      } catch (e) {
        if (kDebugMode) {
          developer.log('❌ Error disposing ${disposable.runtimeType}: $e');
        }
      }
    }
    
    _disposables.clear();
    if (kDebugMode) {
      developer.log('✅ Memory cleanup completed');
    }
  }

  /// الحصول على عدد الموارد المسجلة
  int get registeredCount => _disposables.length;

  /// التحقق من وجود memory leaks محتملة
  void checkForLeaks() {
    if (_disposables.length > 100) {
      if (kDebugMode) {
        developer.log('⚠️ WARNING: ${_disposables.length} resources registered - possible memory leak!');
      }
    }
  }
}

/// واجهة للموارد القابلة للتخلص
abstract class Disposable {
  Future<void> dispose();
}
