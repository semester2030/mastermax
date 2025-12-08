import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/property_model.dart';
import '../models/property_type.dart';
import '../providers/property_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class AddPropertyScreen extends StatefulWidget {
  final PropertyModel? property;

  const AddPropertyScreen({super.key, this.property});

  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _pageController = PageController();

  late Point _currentPosition;
  late PropertyType _selectedPropertyType;
  late OfferType _selectedOfferType;
  List<String> _images = [];
  int _currentImageIndex = 0;
  bool _hasGarage = false;
  bool _hasGarden = false;
  bool _hasPool = false;
  bool _hasSecurity = false;
  bool _isLoading = false;
  String? _selectedKitchenType;
  String? _selectedFinishingType;
  String? _selectedView;
  int _selectedFloor = 0;
  bool _hasElevator = false;
  bool _hasAC = false;
  bool _hasCentralAC = false;
  bool _hasInternetService = false;
  bool _has360View = false;
  String? _panoramaUrl;
  String? _virtualTourUrl;

  final List<String> _kitchenTypes = ['مطبخ مفتوح', 'مطبخ أمريكي', 'مطبخ عادي'];
  final List<String> _finishingTypes = ['سوبر لوكس', 'لوكس', 'نصف تشطيب', 'على العظم'];
  final List<String> _viewTypes = ['إطلالة على البحر', 'إطلالة على الحديقة', 'إطلالة على المدينة', 'إطلالة على الشارع'];

  @override
  void initState() {
    super.initState();
    _currentPosition = Point(
      coordinates: Position(46.6753, 24.7136), // الرياض
    );
    _selectedPropertyType = PropertyType.apartment;
    _selectedOfferType = OfferType.sale;

    if (widget.property != null) {
      _loadPropertyData();
    }
  }

  void _loadPropertyData() {
    final property = widget.property!;
    _titleController.text = property.title;
    _descriptionController.text = property.description;
    _priceController.text = property.price.toString();
    _roomsController.text = property.rooms.toString();
    _bathroomsController.text = property.bathrooms.toString();
    _areaController.text = property.area.toString();
    _addressController.text = property.address;
    _currentPosition = property.location;
    _selectedPropertyType = property.type;
    _selectedOfferType = property.offerType;
    _images = List.from(property.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _addressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (!mounted) return;
      
      if (image != null) {
        setState(() {
          _images.add(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في اختيار الصورة: $e')),
      );
    }
  }

  Future<void> _pickLocation() async {
    // TODO: Implement location picker using Mapbox
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة اختيار الموقع قريباً')),
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      filled: true,
      fillColor: ColorUtils.withOpacity(AppColors.surface, 0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          widget.property == null ? 'إضافة عقار' : 'تعديل العقار',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: _getInputDecoration('عنوان العقار'),
                style: const TextStyle(color: AppColors.textPrimary),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال عنوان العقار';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: _getInputDecoration('وصف العقار'),
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال وصف العقار';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPropertyTypeSelector(),
              const SizedBox(height: 16),
              _buildOfferTypeSelector(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: _getInputDecoration('السعر').copyWith(
                        suffixText: 'ريال',
                        suffixStyle: const TextStyle(color: AppColors.textPrimary),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال السعر';
                        }
                        if (double.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: _getInputDecoration('المساحة').copyWith(
                        suffixText: 'م²',
                        suffixStyle: const TextStyle(color: AppColors.textPrimary),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال المساحة';
                        }
                        if (double.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roomsController,
                      decoration: _getInputDecoration('عدد الغرف'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال عدد الغرف';
                        }
                        if (int.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: _getInputDecoration('عدد الحمامات'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال عدد الحمامات';
                        }
                        if (int.tryParse(value) == null) {
                          return 'الرجاء إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFeatures(),
              const SizedBox(height: 24),
              _buildLocationPicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: _getInputDecoration('العنوان التفصيلي'),
                style: const TextStyle(color: AppColors.textPrimary),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال العنوان';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _build360ViewSection(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.property == null ? 'إضافة العقار' : 'حفظ التعديلات',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صور العقار',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.surface, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent,
            ),
          ),
          child: _images.isEmpty
              ? InkWell(
                  onTap: _pickImage,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.accent,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'اضغط لإضافة صور',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _images.length + 1,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        if (index == _images.length) {
                          return InkWell(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.accent,
                                    size: 48,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'إضافة المزيد',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _images[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _images.removeAt(index);
                                    if (_currentImageIndex >= _images.length) {
                                      _currentImageIndex = _images.length - 1;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _images.length + 1,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? AppColors.accent
                                    : ColorUtils.withOpacity(AppColors.textLight, 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع العقار',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.surface, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent,
            ),
          ),
          child: Column(
            children: PropertyType.values.map((type) {
              return RadioListTile<PropertyType>(
                title: Text(
                  type.toArabic(),
                  style: const TextStyle(color: AppColors.accent),
                ),
                value: type,
                groupValue: _selectedPropertyType,
                activeColor: AppColors.accent,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPropertyType = value;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع العرض',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<OfferType>(
                title: const Text(
                  'بيع',
                  style: TextStyle(color: AppColors.accent),
                ),
                value: OfferType.sale,
                groupValue: _selectedOfferType,
                activeColor: AppColors.accent,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedOfferType = value;
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: RadioListTile<OfferType>(
                title: const Text(
                  'إيجار',
                  style: TextStyle(color: AppColors.accent),
                ),
                value: OfferType.rent,
                groupValue: _selectedOfferType,
                activeColor: AppColors.accent,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedOfferType = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المميزات',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.surface, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedKitchenType,
                decoration: _getInputDecoration('نوع المطبخ'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.accent),
                items: _kitchenTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedKitchenType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFinishingType,
                decoration: _getInputDecoration('مستوى التشطيب'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.accent),
                items: _finishingTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFinishingType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedView,
                decoration: _getInputDecoration('الإطلالة'),
                dropdownColor: AppColors.background,
                style: const TextStyle(color: AppColors.accent),
                items: _viewTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedView = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _selectedFloor.toString(),
                decoration: _getInputDecoration('الطابق'),
                style: const TextStyle(color: AppColors.accent),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _selectedFloor = int.tryParse(value) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildFeatureSwitch('مصعد', _hasElevator, (value) {
                setState(() => _hasElevator = value);
              }),
              _buildFeatureSwitch('تكييف', _hasAC, (value) {
                setState(() => _hasAC = value);
              }),
              _buildFeatureSwitch('تكييف مركزي', _hasCentralAC, (value) {
                setState(() => _hasCentralAC = value);
              }),
              _buildFeatureSwitch('خدمة إنترنت', _hasInternetService, (value) {
                setState(() => _hasInternetService = value);
              }),
              _buildFeatureSwitch('موقف سيارات', _hasGarage, (value) {
                setState(() => _hasGarage = value);
              }),
              _buildFeatureSwitch('حديقة', _hasGarden, (value) {
                setState(() => _hasGarden = value);
              }),
              _buildFeatureSwitch('مسبح', _hasPool, (value) {
                setState(() => _hasPool = value);
              }),
              _buildFeatureSwitch('حراسة أمنية', _hasSecurity, (value) {
                setState(() => _hasSecurity = value);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSwitch(String title, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppColors.accent),
        ),
        value: value,
        activeColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الموقع',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.surface, 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey('propertyMap'),
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  cameraOptions: CameraOptions(
                    center: _currentPosition,
                    zoom: 15.0,
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _pickLocation,
                    backgroundColor: AppColors.accent,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _build360ViewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'العرض 360 والجولة الافتراضية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('عرض 360 درجة'),
          subtitle: const Text('إضافة عرض 360 درجة للعقار'),
          value: _has360View,
          onChanged: (value) {
            setState(() {
              _has360View = value;
              if (!value) {
                _panoramaUrl = null;
              }
            });
          },
          activeColor: AppColors.primary,
        ),
        if (_has360View)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                );
                if (image != null) {
                  setState(() {
                    _panoramaUrl = image.path;
                  });
                }
              },
              icon: const Icon(Icons.view_in_ar),
              label: const Text('اختيار صورة 360 درجة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: _getInputDecoration('رابط الجولة الافتراضية').copyWith(
            hintText: 'أدخل رابط الجولة الافتراضية (اختياري)',
            prefixIcon: const Icon(Icons.link, color: AppColors.primary),
          ),
          initialValue: _virtualTourUrl,
          onChanged: (value) {
            setState(() {
              _virtualTourUrl = value.isEmpty ? null : value;
            });
          },
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_images.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إضافة صورة واحدة على الأقل')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final features = <String, bool>{
          'موقف سيارات': _hasGarage,
          'حديقة': _hasGarden,
          'مسبح': _hasPool,
          'حراسة أمنية': _hasSecurity,
          'مصعد': _hasElevator,
          'تكييف': _hasAC,
          'تكييف مركزي': _hasCentralAC,
          'خدمة إنترنت': _hasInternetService,
        };

        final amenities = <String>[
          if (_selectedKitchenType != null) _selectedKitchenType!,
          if (_selectedFinishingType != null) _selectedFinishingType!,
          if (_selectedView != null) _selectedView!,
        ];

        final property = PropertyModel(
          id: widget.property?.id ?? '',
          title: _titleController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          images: _images,
          address: _addressController.text,
          location: _currentPosition,
          ownerId: context.read<AuthProvider>().currentUser?.id ?? '',
          offerType: _selectedOfferType,
          status: PropertyStatus.available,
          type: _selectedPropertyType,
          rooms: int.parse(_roomsController.text),
          bathrooms: int.parse(_bathroomsController.text),
          area: double.parse(_areaController.text),
          features: features,
          amenities: amenities,
          floors: _selectedFloor,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contactPhone: context.read<AuthProvider>().currentUser?.phoneNumber ?? '+966500000000',
          has360View: _has360View,
          panoramaUrl: _panoramaUrl,
          virtualTourUrl: _virtualTourUrl,
        );

        if (widget.property == null) {
          await context.read<PropertyProvider>().addProperty(property);
        } else {
          await context.read<PropertyProvider>().updateProperty(property);
        }

        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
} 