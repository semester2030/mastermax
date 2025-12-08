import 'package:flutter/material.dart';
import '../models/car_model.dart';
import '../services/car_service.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/utils/logger.dart';

class CarProvider extends ChangeNotifier {
  final CarService _carService;
  final AuthState _authState;
  
  CarProvider(this._carService, this._authState) {
    // تجنب التحميل التلقائي عند التهيئة
    logDebug('CarProvider initialized');
  }

  bool _isLoading = false;
  String? _error;
  List<CarModel> _cars = [];
  CarModel? _selectedCar;
  bool _isDisposed = false; // للتحقق من حالة الـ Provider

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CarModel> get cars => List.unmodifiable(_cars); // منع التعديل المباشر
  CarModel? get selectedCar => _selectedCar;

  @override
  void dispose() {
    _isDisposed = true;
    _cars.clear(); // تنظيف الذاكرة
    _selectedCar = null;
    super.dispose();
  }

  // تحديث الحالة بأمان
  void _safeSetState(VoidCallback update) {
    if (!_isDisposed) {
      update();
      notifyListeners();
    }
  }

  // إضافة سيارة جديدة
  Future<void> addCar(CarModel car) async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _authState.user;
      if (user == null) {
        throw 'يجب تسجيل الدخول لإضافة سيارة';
      }

      logInfo('Adding new car for user: ${user.id}');

      final carWithSeller = car.copyWith(
        sellerId: user.id,
        sellerName: user.name,
        sellerPhone: user.extraData?['phoneNumber'] ?? 'لا يوجد',
      );

      final id = await _carService.addCar(carWithSeller);
      final newCar = await _carService.getCar(id);
      
      if (newCar != null) {
        _safeSetState(() {
          _cars.insert(0, newCar);
        });
        logInfo('Car added successfully with ID: $id');
      }

    } catch (e, stackTrace) {
      logError('Error adding car', e, stackTrace);
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

  // تحميل قائمة السيارات
  Future<void> loadCars() async {
    if (_isLoading) return;
    
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Loading cars list');
      final cars = await _carService.getCars();
      
      _safeSetState(() {
        _cars = cars;
      });
      
      logInfo('Loaded ${cars.length} cars successfully');

    } catch (e, stackTrace) {
      logError('Error loading cars', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        if (_cars.isEmpty) {
          _cars = [];
        }
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  // اختيار سيارة
  void selectCar(CarModel? car) {
    _safeSetState(() {
      _selectedCar = car;
    });
    logDebug('Selected car: ${car?.id ?? 'None'}');
  }

  // تحديث بيانات سيارة
  Future<void> updateCar(CarModel car) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Updating car: ${car.id}');
      await _carService.updateCar(car);
      
      _safeSetState(() {
        final index = _cars.indexWhere((c) => c.id == car.id);
        if (index != -1) {
          _cars[index] = car;
        }
        
        if (_selectedCar?.id == car.id) {
          _selectedCar = car;
        }
      });

      logInfo('Car updated successfully');

    } catch (e, stackTrace) {
      logError('Error updating car', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  // حذف سيارة
  Future<void> deleteCar(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Deleting car: $id');
      await _carService.deleteCar(id);
      
      _safeSetState(() {
        _cars.removeWhere((car) => car.id == id);
        if (_selectedCar?.id == id) {
          _selectedCar = null;
        }
      });

      logInfo('Car deleted successfully');

    } catch (e, stackTrace) {
      logError('Error deleting car', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  // تحميل سيارة بواسطة المعرف
  Future<void> fetchCarById(String id) async {
    if (_isLoading) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      logInfo('Fetching car by ID: $id');
      final car = await _carService.getCarById(id);
      
      if (car == null) {
        throw 'لم يتم العثور على السيارة';
      }
      
      _safeSetState(() {
        _selectedCar = car;
      });

      logInfo('Car fetched successfully');

    } catch (e, stackTrace) {
      logError('Error fetching car', e, stackTrace);
      _safeSetState(() {
        _error = e.toString();
        _selectedCar = null; // تأكد من إزالة السيارة المحددة في حالة الخطأ
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> addTestCar() async {
    try {
      final testCar = CarModel(
        id: '',
        title: 'تويوتا كامري 2023',
        description: 'سيارة تويوتا كامري 2023 بحالة ممتازة',
        brand: 'تويوتا',
        model: 'كامري',
        year: 2023,
        price: 120000,
        sellerId: 'test_seller',
        sellerName: 'البائع التجريبي',
        sellerPhone: '0500000000',
        images: [],
        mainImage: '',
        hasVideo: false,
        address: 'الرياض - حي النخيل',
        condition: 'جديد',
        kilometers: 0,
        transmission: 'أوتوماتيك',
        fuelType: 'بنزين',
        features: ['كاميرا خلفية', 'مثبت سرعة', 'شاشة لمس'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        isFeatured: false,
        isVerified: true,
      );

      await addCar(testCar);
    } catch (e) {
      debugPrint('Error adding test car: $e');
    }
  }

  // دالة للحصول على سيارة بواسطة المعرف
  Future<CarModel?> getCar(String id) async {
    try {
      // في الحالة الحقيقية، قم بالبحث في قاعدة البيانات
      return _cars.firstWhere((car) => car.id == id);
    } catch (e) {
      return null;
    }
  }

  // دالة للبحث عن السيارات
  Future<List<CarModel>> searchCarsByQuery(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      return _cars.where((car) {
        return car.title.toLowerCase().contains(normalizedQuery) ||
               car.address.toLowerCase().contains(normalizedQuery) ||
               car.fuelType.toLowerCase().contains(normalizedQuery) ||
               car.transmission.toLowerCase().contains(normalizedQuery);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}