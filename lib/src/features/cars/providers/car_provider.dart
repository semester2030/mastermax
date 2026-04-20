import 'dart:io';
import 'package:flutter/material.dart';
import '../models/car_model.dart';
import '../services/car_service.dart';
import '../services/car_image_service.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/utils/logger.dart';

class CarProvider extends ChangeNotifier {
  final CarService _carService;
  final AuthState _authState;
  final CarImageService _carImageService;
  
  CarProvider(this._carService, this._authState) 
      : _carImageService = CarImageService() {
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

      // ✅ رفع الصور المحلية إلى Cloudflare Images فقط (NOT Firebase Storage)
      List<String> uploadedImages = [];
      List<String> localImagePaths = [];
      
      // فصل الصور المحلية عن URLs (URLs من Cloudflare Images)
      for (final image in car.images) {
        if (image.startsWith('http')) {
          // صورة موجودة مسبقاً (URL من Cloudflare Images)
          uploadedImages.add(image);
        } else {
          // صورة محلية (مسار ملف) - سيتم رفعها إلى Cloudflare Images
          localImagePaths.add(image);
        }
      }

      // إنشاء معرف مؤقت للسيارة (سيتم استبداله بالمعرف الفعلي بعد الحفظ)
      final tempCarId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // ✅ رفع الصور المحلية إلى Cloudflare Images
      if (localImagePaths.isNotEmpty) {
        logInfo('🚀 Uploading ${localImagePaths.length} local images to Cloudflare Images...');
        for (final imagePath in localImagePaths) {
          try {
            final imageFile = File(imagePath);
            if (await imageFile.exists()) {
              // ✅ رفع إلى Cloudflare Images فقط (NOT Firebase Storage)
              final url = await _carImageService.uploadImage(imageFile, tempCarId);
              uploadedImages.add(url);
              logInfo('✅ Image uploaded to Cloudflare Images: $url');
            }
          } catch (e) {
            logError('❌ Failed to upload image to Cloudflare Images: $imagePath', e);
            // نتابع رفع باقي الصور حتى لو فشلت واحدة
          }
        }
      }

      // التحقق من وجود صورة واحدة على الأقل
      if (uploadedImages.isEmpty) {
        throw 'الرجاء إضافة صورة واحدة على الأقل';
      }

      final carWithSeller = car.copyWith(
        sellerId: user.id,
        sellerName: user.name,
        sellerPhone: user.extraData?['phoneNumber'] ?? 'لا يوجد',
        images: uploadedImages,
        mainImage: uploadedImages.isNotEmpty ? uploadedImages.first : '',
      );

      final id = await _carService.addCar(carWithSeller);
      
      // إذا كان هناك صور تم رفعها بمعرف مؤقت، يمكن تحديثها بالمعرف الفعلي
      // (اختياري - يمكن تركه كما هو لأن الصور مرتبطة بالمعرف المؤقت)
      
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

      final resolvedImages = <String>[];
      for (final image in car.images) {
        if (image.startsWith('http')) {
          resolvedImages.add(image);
        } else {
          final file = File(image);
          if (await file.exists()) {
            final url = await _carImageService.uploadImage(file, car.id);
            resolvedImages.add(url);
          }
        }
      }
      if (resolvedImages.isEmpty) {
        throw 'الرجاء إضافة صورة واحدة على الأقل';
      }

      var mainImage = car.mainImage;
      if (!mainImage.startsWith('http')) {
        final idx = car.images.indexOf(mainImage);
        if (idx >= 0 && idx < resolvedImages.length) {
          mainImage = resolvedImages[idx];
        } else {
          mainImage = resolvedImages.first;
        }
      } else if (!resolvedImages.contains(mainImage)) {
        mainImage = resolvedImages.first;
      }

      final carToSave = car.copyWith(
        images: resolvedImages,
        mainImage: mainImage,
        updatedAt: DateTime.now(),
      );

      await _carService.updateCar(carToSave);

      _safeSetState(() {
        final index = _cars.indexWhere((c) => c.id == carToSave.id);
        if (index != -1) {
          _cars[index] = carToSave;
        }

        if (_selectedCar?.id == carToSave.id) {
          _selectedCar = carToSave;
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

  /// حذف صورة واحدة من سيارة محددة وتحديث بياناتها
  Future<void> removeCarImage({
    required CarModel car,
    required String imageUrl,
  }) async {
    if (_isLoading) return;

    final uid = (_authState.user?.id ?? '').trim();
    final sid = car.sellerId.trim();
    if (!_authState.isAdmin && (uid.isEmpty || uid != sid)) {
      throw Exception('غير مصرح لك بتعديل صور هذه السيارة');
    }

    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      // لا نسمح بحذف آخر صورة حتى لا تبقى السيارة بدون صور
      if (car.images.length <= 1) {
        throw 'لا يمكن حذف آخر صورة، يجب أن تبقى صورة واحدة على الأقل للسيارة';
      }

      logInfo('Removing car image for car: ${car.id}');

      // حذف الصورة من Firebase Storage
      await _carImageService.deleteImage(imageUrl);

      // إنشاء نسخة محدثة من قائمة الصور بدون الصورة المحذوفة
      final updatedImages = List<String>.from(car.images)..remove(imageUrl);

      final updatedCar = car.copyWith(
        images: updatedImages,
        mainImage: updatedImages.isNotEmpty ? updatedImages.first : car.mainImage,
      );

      // تحديث السيارة في قاعدة البيانات
      await _carService.updateCar(updatedCar);

      // تحديث الحالة المحلية
      _safeSetState(() {
        final index = _cars.indexWhere((c) => c.id == updatedCar.id);
        if (index != -1) {
          _cars[index] = updatedCar;
        }
        if (_selectedCar?.id == updatedCar.id) {
          _selectedCar = updatedCar;
        }
      });

      logInfo('Car image removed successfully');
    } catch (e, stackTrace) {
      logError('Error removing car image', e, stackTrace);
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