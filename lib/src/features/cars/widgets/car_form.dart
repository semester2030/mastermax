import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/car_model.dart';
import '../../../shared/widgets/inputs/image_picker_field.dart';
import '../../../shared/widgets/inputs/location_picker_field.dart';
import '../../../core/theme/app_colors.dart';
import 'car_features_selector.dart';
import '../../../core/utils/color_utils.dart';

class CarForm extends StatefulWidget {
  final Function(CarModel) onSubmit;

  const CarForm({
    required this.onSubmit, super.key,
  });

  @override
  State<CarForm> createState() => _CarFormState();
}

class _CarFormState extends State<CarForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {
    'title': '',
    'description': '',
    'price': 0.0,
    'brand': '',
    'model': '',
    'year': DateTime.now().year,
    'condition': 'new',
    'kilometers': 0,
    'transmission': 'automatic',
    'fuelType': 'petrol',
    'features': <String>[],
    'images': <String>[],
    'mainImage': '',
    'location': const GeoPoint(0, 0),
    'address': '',
    'hasVideo': false,
    'videoUrl': null,
    'has360View': false,
    'panoramaUrl': null,
    'hasInteriorView': false,
    'interiorPanoramaUrl': null,
    'virtualTourUrl': null,
  };

  final Map<String, List<String>> _carModels = {
    // اليابانية
    'toyota': [
      'كامري',
      'كورولا',
      'لاندكروزر',
      'برادو',
      'راف فور',
      'هايلكس',
      'افالون',
      'يارس',
      'فورتشنر',
      'انوفا',
      'راش',
      'سيكويا',
      'سوبرا',
      'كوستر',
      'جي آر سوبرا',
    ],
    'lexus': [
      'ES',
      'LS',
      'IS',
      'GS',
      'RX',
      'NX',
      'UX',
      'GX',
      'LX',
      'RC',
      'LC',
      'IS F',
      'RC F',
      'LFA',
    ],
    'honda': [
      'اكورد',
      'سيفيك',
      'سيتي',
      'CR-V',
      'HR-V',
      'بايلوت',
      'اوديسي',
      'MR-V',
      'BR-V',
      'جاز',
      'انسايت',
      'ريدجلاين',
      'NSX',
    ],
    'nissan': [
      'التيما',
      'مكسيما',
      'باترول',
      'اكس-تريل',
      'باثفايندر',
      'صني',
      'سنترا',
      'اكستيرا',
      'نافارا',
      'GT-R',
      'ارمادا',
      'كيكس',
      'ميكرا',
      'روج',
      'مورانو',
    ],
    'infiniti': [
      'Q50',
      'Q60',
      'Q70',
      'QX50',
      'QX60',
      'QX70',
      'QX80',
      'QX55',
      'QX30',
    ],
    'mitsubishi': [
      'باجيرو',
      'لانسر',
      'اوتلاندر',
      'ASX',
      'مونتيرو',
      'اكليبس',
      'اكليبس كروس',
      'L200',
      'اتراج',
      'سبيس ستار',
      'مونتيرو سبورت',
    ],
    'mazda': [
      'مازدا3',
      'مازدا6',
      'CX-3',
      'CX-30',
      'CX-5',
      'CX-9',
      'BT-50',
      'MX-5',
      'CX-8',
      'CX-60',
    ],
    'subaru': [
      'امبريزا',
      'فورستر',
      'اوتباك',
      'ليجاسي',
      'XV',
      'اسنت',
      'BRZ',
      'WRX',
      'WRX STI',
    ],
    'suzuki': [
      'سويفت',
      'فيتارا',
      'جيمني',
      'ارتيجا',
      'سياز',
      'اس-كروس',
      'اس-بريسو',
      'XL7',
      'بالينو',
    ],

    // الكورية
    'hyundai': [
      'اكسنت',
      'النترا',
      'سوناتا',
      'ازيرا',
      'توسان',
      'سنتافي',
      'كونا',
      'باليسيد',
      'كريتا',
      'جينيسيس',
      'فيلوستر',
      'H1',
      'ستاريا',
      'كاليستا',
      'i10',
      'i20',
      'i30',
    ],
    'kia': [
      'سيراتو',
      'K5',
      'K8',
      'K9',
      'سبورتاج',
      'سورينتو',
      'تيلورايد',
      'سيلتوس',
      'بيجاس',
      'ريو',
      'سول',
      'كارنز',
      'كرنفال',
      'موهافي',
      'نيرو',
      'EV6',
    ],
    'genesis': [
      'G70',
      'G80',
      'G90',
      'GV70',
      'GV80',
      'GV60',
    ],

    // الأمريكية
    'chevrolet': [
      'كابتيفا',
      'ماليبو',
      'كروز',
      'سبارك',
      'تاهو',
      'سوبربان',
      'سلفرادو',
      'بليزر',
      'ترافيرس',
      'اكوينوكس',
      'كمارو',
      'كورفيت',
      'امبالا',
      'تريل بليزر',
    ],
    'gmc': [
      'يوكن',
      'سييرا',
      'اكاديا',
      'تيرين',
      'سافانا',
      'كانيون',
      'هامر EV',
    ],
    'cadillac': [
      'CT4',
      'CT5',
      'XT4',
      'XT5',
      'XT6',
      'اسكاليد',
      'CT6',
      'CTS',
      'ATS',
    ],
    'ford': [
      'توروس',
      'فيوجن',
      'اكسبلورر',
      'ايدج',
      'اكسبيدشن',
      'F-150',
      'رينجر',
      'برونكو',
      'موستنج',
      'ايكوسبورت',
      'مافريك',
    ],
    'dodge': [
      'تشارجر',
      'تشالنجر',
      'دورانجو',
      'نيون',
      'رام',
      'جورني',
    ],
    'jeep': [
      'جراند شيروكي',
      'رانجلر',
      'كومباس',
      'شيروكي',
      'جلاديتور',
      'رينيجيد',
    ],
    'chrysler': [
      '300C',
      'باسيفيكا',
      'فوياجر',
    ],
    'lincoln': [
      'نافيجيتور',
      'افياتور',
      'كورسير',
      'نوتيلوس',
    ],

    // الألمانية
    'mercedes': [
      'C-Class',
      'E-Class',
      'S-Class',
      'A-Class',
      'GLA',
      'GLB',
      'GLC',
      'GLE',
      'GLS',
      'G-Class',
      'CLA',
      'CLS',
      'AMG GT',
      'EQS',
      'EQE',
      'V-Class',
      'مايباخ',
    ],
    'bmw': [
      'الفئة 3',
      'الفئة 4',
      'الفئة 5',
      'الفئة 6',
      'الفئة 7',
      'الفئة 8',
      'X1',
      'X2',
      'X3',
      'X4',
      'X5',
      'X6',
      'X7',
      'M3',
      'M4',
      'M5',
      'M8',
      'iX',
      'i4',
      'i7',
    ],
    'audi': [
      'A3',
      'A4',
      'A5',
      'A6',
      'A7',
      'A8',
      'Q3',
      'Q5',
      'Q7',
      'Q8',
      'e-tron',
      'RS e-tron GT',
      'RS3',
      'RS4',
      'RS5',
      'RS6',
      'RS7',
      'RS Q8',
    ],
    'porsche': [
      'كايين',
      'ماكان',
      'بانميرا',
      '911',
      'تايكان',
      '718 كايمن',
      '718 بوكستر',
    ],
    'volkswagen': [
      'باسات',
      'جيتا',
      'تيجوان',
      'طوارق',
      'ارتيون',
      'ID.4',
      'T-Roc',
      'جولف',
      'بولو',
    ],

    // البريطانية
    'land_rover': [
      'ديفندر',
      'ديسكفري',
      'ديسكفري سبورت',
    ],
    'range_rover': [
      'رنج روفر',
      'رنج روفر سبورت',
      'رنج روفر فيلار',
      'رنج روفر ايفوك',
    ],
    'jaguar': [
      'XE',
      'XF',
      'F-TYPE',
      'F-PACE',
      'E-PACE',
      'I-PACE',
    ],
    'bentley': [
      'بينتايجا',
      'فلاينج سبير',
      'كونتيننتال GT',
    ],
    'rolls_royce': [
      'فانتوم',
      'جوست',
      'كولينان',
      'رايث',
      'داون',
    ],

    // الإيطالية
    'maserati': [
      'جيبلي',
      'كواتروبورتي',
      'ليفانتي',
      'MC20',
      'جران توريزمو',
    ],
    'alfa_romeo': [
      'جوليا',
      'ستلفيو',
      'تونالي',
    ],
    'ferrari': [
      'F8 تريبوتو',
      'SF90 ستراديل',
      '296 GTB',
      'روما',
      'بورتوفينو M',
    ],
    'lamborghini': [
      'اوروس',
      'هوراكان',
      'افينتادور',
    ],

    // السويدية
    'volvo': [
      'XC40',
      'XC60',
      'XC90',
      'S60',
      'S90',
      'V60',
      'V90',
      'C40',
    ],

    // الفرنسية
    'peugeot': [
      '208',
      '2008',
      '3008',
      '5008',
      '301',
      '308',
      '508',
      'ريفتر',
      'تريفلر',
    ],
    'renault': [
      'ميجان',
      'كوليوس',
      'داستر',
      'كابتور',
      'سيمبول',
      'لوجان',
      'تاليسمان',
    ],

    // الصينية
    'mg': [
      'MG4',
      'MG5',
      'MG6',
      'ZS',
      'HS',
      'RX5',
      'RX8',
      'GT',
      'ONE',
    ],
    'changan': [
      'CS35 بلس',
      'CS55 بلس',
      'CS75 بلس',
      'CS85',
      'CS95',
      'الصياد',
      'ايدو بلس',
    ],
    'haval': [
      'H6',
      'جوليان',
      'H9',
      'F7',
      'F7x',
      'جريت وول',
    ],
    'geely': [
      'توجيلا',
      'كولراي',
      'ازكارا',
      'امجراند',
    ],
    'byd': [
      'هان',
      'تانج',
      'يوان بلس',
      'سيل',
      'اتو',
      'دولفين',
    ],
    'gac': [
      'GS3',
      'GS4',
      'GS8',
      'GA4',
      'GA8',
      'GN8',
    ],
  };

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.primary),
      prefixIcon: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ColorUtils.withOpacity(AppColors.primary, 0.1),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.primary, 0.3),
          ),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      border: _buildBorder(0.3),
      enabledBorder: _buildBorder(0.3),
      focusedBorder: _buildBorder(1.0),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.error.withOpacity(0.5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      filled: true,
      fillColor: AppColors.surface,
    );
  }

  OutlineInputBorder _buildBorder(double opacity) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, opacity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildCarInfoSection(),
            const SizedBox(height: 24),
            _buildFeaturesSection(),
            const SizedBox(height: 24),
            _buildMediaSection(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _build360ViewSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.primary, 0.2),
        ),
      ),
      child: const Text(
        'معلومات السيارة',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCarInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          decoration: _buildInputDecoration(
            labelText: 'عنوان السيارة',
            icon: Icons.title,
          ),
          style: const TextStyle(color: AppColors.text),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال عنوان السيارة';
            }
            return null;
          },
          onSaved: (value) => _formData['title'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: _buildInputDecoration(
            labelText: 'الوصف',
            icon: Icons.description,
          ),
          style: const TextStyle(color: AppColors.text),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال وصف السيارة';
            }
            return null;
          },
          onSaved: (value) => _formData['description'] = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: _buildInputDecoration(
            labelText: 'السعر',
            icon: Icons.attach_money,
          ),
          style: const TextStyle(color: AppColors.text),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال السعر';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'الرجاء إدخال سعر صحيح';
            }
            return null;
          },
          onSaved: (value) {
            if (value != null && value.isNotEmpty) {
              _formData['price'] = double.tryParse(value) ?? 0.0;
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  labelText: 'الماركة',
                  icon: Icons.car_repair,
                ),
                style: const TextStyle(color: AppColors.text),
                dropdownColor: AppColors.surface,
                items: _carModels.keys.map((brand) {
                  return DropdownMenuItem(
                    value: brand,
                    child: Text(
                      brand,
                      style: const TextStyle(color: AppColors.text),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _formData['brand'] = value;
                    _formData['model'] = '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء اختيار الماركة';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  labelText: 'الموديل',
                  icon: Icons.model_training,
                ),
                style: const TextStyle(color: AppColors.text),
                dropdownColor: AppColors.surface,
                items: _formData['brand'] != null && _carModels.containsKey(_formData['brand'])
                    ? _carModels[_formData['brand']]!.map((model) {
                        return DropdownMenuItem(
                          value: model,
                          child: Text(
                            model,
                            style: const TextStyle(color: AppColors.text),
                          ),
                        );
                      }).toList()
                    : [],
                onChanged: (value) {
                  setState(() {
                    _formData['model'] = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء اختيار الموديل';
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
                decoration: _buildInputDecoration(
                  labelText: 'سنة الصنع',
                  icon: Icons.calendar_today,
                ),
                style: const TextStyle(color: AppColors.text),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال سنة الصنع';
                  }
                  final year = int.tryParse(value);
                  if (year == null ||
                      year < 1900 ||
                      year > DateTime.now().year + 1) {
                    return 'سنة غير صحيحة';
                  }
                  return null;
                },
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _formData['year'] = int.tryParse(value) ?? DateTime.now().year;
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: _buildInputDecoration(
                  labelText: 'عدد الكيلومترات',
                  icon: Icons.speed,
                ),
                style: const TextStyle(color: AppColors.text),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال عدد الكيلومترات';
                  }
                  final km = int.tryParse(value);
                  if (km == null || km < 0) {
                    return 'عدد غير صحيح';
                  }
                  return null;
                },
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _formData['kilometers'] = int.tryParse(value) ?? 0;
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  labelText: 'الحالة',
                  icon: Icons.car_crash,
                ),
                style: const TextStyle(color: AppColors.text),
                dropdownColor: AppColors.surface,
                items: ['جديدة', 'مستعملة'].map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(
                      condition,
                      style: const TextStyle(color: AppColors.text),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _formData['condition'] = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء اختيار الحالة';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  labelText: 'ناقل الحركة',
                  icon: Icons.settings,
                ),
                style: const TextStyle(color: AppColors.text),
                dropdownColor: AppColors.surface,
                items: ['أوتوماتيك', 'عادي'].map((transmission) {
                  return DropdownMenuItem(
                    value: transmission,
                    child: Text(
                      transmission,
                      style: const TextStyle(color: AppColors.text),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _formData['transmission'] = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء اختيار ناقل الحركة';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: _buildInputDecoration(
            labelText: 'نوع الوقود',
            icon: Icons.local_gas_station,
          ),
          style: const TextStyle(color: AppColors.text),
          dropdownColor: AppColors.surface,
          items: ['بنزين', 'ديزل', 'كهرباء', 'هجين'].map((fuelType) {
            return DropdownMenuItem(
              value: fuelType,
              child: Text(
                fuelType,
                style: const TextStyle(color: AppColors.text),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _formData['fuelType'] = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار نوع الوقود';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'مميزات السيارة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        CarFeaturesSelector(
          selectedFeatures: _formData['features'] ?? [],
          onFeaturesChanged: (features) {
            setState(() {
              _formData['features'] = features;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الصور والفيديو',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        ImagePickerField(
          images: _formData['images'] as List<String>? ?? [],
          onImagesChanged: (images) {
            setState(() {
              _formData['images'] = images;
              if (images.isNotEmpty && (_formData['mainImage'] == null || (_formData['mainImage'] as String).isEmpty)) {
                _formData['mainImage'] = images.first;
              }
            });
          },
          onImageSelected: (image) {
            setState(() {
              final images = _formData['images'] as List<String>? ?? [];
              images.add(image);
              _formData['images'] = images;
              if (_formData['mainImage'] == null || (_formData['mainImage'] as String).isEmpty) {
                _formData['mainImage'] = image;
              }
            });
          },
          label: 'صور السيارة',
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الموقع',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        LocationPickerField(
          initialAddress: '',
          initialLocation: const GeoPoint(0, 0),
          label: 'موقع السيارة',
          onLocationSelected: (location, address) {
            setState(() {
              _formData['location'] = location;
              _formData['address'] = address;
            });
          },
        ),
      ],
    );
  }

  Widget _build360ViewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'العرض 360 والجولة الداخلية',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('عرض 360 درجة'),
          subtitle: const Text('إضافة عرض 360 درجة للسيارة من الخارج'),
          value: _formData['has360View'] ?? false,
          onChanged: (value) {
            setState(() {
              _formData['has360View'] = value;
              if (!value) {
                _formData['panoramaUrl'] = null;
              }
            });
          },
          activeColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('عرض المقصورة الداخلية'),
          subtitle: const Text('إضافة عرض 360 درجة للمقصورة الداخلية'),
          value: _formData['hasInteriorView'] ?? false,
          onChanged: (value) {
            setState(() {
              _formData['hasInteriorView'] = value;
              if (!value) {
                _formData['interiorPanoramaUrl'] = null;
              }
            });
          },
          activeColor: AppColors.primary,
        ),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'رابط الجولة الافتراضية (اختياري)',
            hintText: 'أدخل رابط الجولة الافتراضية',
            prefixIcon: Icon(Icons.link),
          ),
          initialValue: _formData['virtualTourUrl'],
          onChanged: (value) {
            setState(() {
              _formData['virtualTourUrl'] = value.isEmpty ? null : value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState != null && _formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            final now = DateTime.now();
            final carData = {
              ..._formData,
              'createdAt': now,
              'updatedAt': now,
              'isActive': true,
              'isFeatured': false,
              'isVerified': false,
            };
            widget.onSubmit(CarModel.fromMap(carData, ''));
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'إضافة السيارة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 