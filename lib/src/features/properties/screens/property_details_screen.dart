import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/property_model.dart';
import '../providers/property_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../../features/map/services/map_service.dart';
import '../../../features/map/widgets/commutes_widget.dart';
import '../../../features/map/widgets/property_full_screen_view.dart';
import '../../../core/constants/app_brand.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({
    required this.propertyId,
    super.key,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final MapService _mapService = MapService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ✅ التحقق من أن propertyId غير فارغ
      if (widget.propertyId.isEmpty) {
        debugPrint('❌ Property ID is empty');
        return;
      }
      
      try {
        await context.read<PropertyProvider>().fetchPropertyById(widget.propertyId);
        debugPrint('✅ Property loaded: ${widget.propertyId}');
      } catch (e) {
        debugPrint('❌ Failed to load property ${widget.propertyId}: $e');
      }
      
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    try {
      await _mapService.initialize();
    } catch (e) {
      debugPrint('خطأ في تهيئة الخريطة: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'تفاصيل العقار',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primary, size: 22),
            onPressed: () {
              final property =
                  context.read<PropertyProvider>().selectedProperty;
              if (property != null) {
                HapticFeedback.mediumImpact();
                SharePlus.instance.share(
                  ShareParams(
                    text: 'شاهد هذا العقار الرائع!\n'
                        '${property.title}\n'
                        'السعر: ${_numberFormat.format(property.price)} ريال\n'
                        'العنوان: ${property.address}\n'
                        'للتواصل: ${property.contactPhone}\n\n'
                        'تم المشاركة من تطبيق ${AppBrand.displayName}',
                    subject: property.title,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<PropertyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          final property = provider.selectedProperty;
          if (property == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 64,
                    color: AppColors.primary.withAlpha(128),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لم يتم العثور على العقار',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageGallery(property.images),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                          property.title,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_numberFormat.format(property.price)} ريال',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الوصف',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ✅ نفس أسلوب بطاقة وصف السيارة (خلفية فاتحة + إطار خفيف)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            property.description,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSpecsSection(property),
                        const SizedBox(height: 24),
                        // إضافة CommutesWidget للمسافات والأوقات
                        CommutesWidget(
                          property: property,
                        ),
                        const SizedBox(height: 24),
                        _buildContactCard(property),
                        const SizedBox(height: 24),
                        _buildPropertyLocation(property),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Consumer<PropertyProvider>(
      builder: (context, provider, child) {
        final property = provider.selectedProperty;
        if (property == null) {
          return const SizedBox.shrink();
        }

        if (images.isEmpty) {
          return SizedBox(
            height: 300,
            child: Container(
              color: AppColors.primaryLight,
              child: const Center(
                child: Icon(
                  Icons.home_work_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 300,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final image = images[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PropertyFullScreenView(
                            property: property,
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    child: image.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: AppColors.primaryLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint('Error loading image: $error');
                              return Container(
                                color: AppColors.primaryLight,
                                child: const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Error loading image: $error');
                              return Container(
                                color: AppColors.primaryLight,
                                child: const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 50,
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((entry) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == entry.key
                              ? AppColors.primary
                              : AppColors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (images.isNotEmpty)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentImageIndex + 1} / ${images.length}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecsSection(PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPropertyMainSpecsCard(property),
        if (property.roomDetails != null) ...[
          const SizedBox(height: 16),
          _buildAdditionalDetailsCard(property),
        ],
        if (_propertyHasImportantFlags(property)) ...[
          const SizedBox(height: 16),
          _buildImportantDetailsCard(property),
        ],
      ],
    );
  }

  bool _propertyHasImportantFlags(PropertyModel property) {
    return property.hasApartments ||
        property.hasInternalStairs ||
        property.hasExternalStairs ||
        property.propertyDirection != null ||
        property.streetWidth != null;
  }

  /// بطاقة مواصفات بنفس أسلوب [CarSpecsSection]: خلفية فاتحة، تسميات صغيرة، قيم واضحة.
  Widget _buildPropertyMainSpecsCard(PropertyModel property) {
    final rd = property.roomDetails;
    final beds = rd != null && rd.bedrooms > 0 ? rd.bedrooms : property.rooms;
    final baths =
        rd != null && rd.bathrooms > 0 ? rd.bathrooms : property.bathrooms;
    final areaMain = rd != null && rd.totalBuiltArea > 0
        ? rd.totalBuiltArea.toStringAsFixed(0)
        : property.area.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مواصفات العقار',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          _buildBedBathSpecsRow(
            property: property,
            beds: beds,
            baths: baths,
            hasRoomDetails: rd != null,
          ),
          const Divider(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (rd != null) {
                  _showAreaDetailsDialog(property, 'المساحات');
                } else {
                  _showSpecDetails(context, 'المساحة', [
                    'المساحة الإجمالية: ${property.area.toStringAsFixed(0)} م²',
                  ]);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _propertySpecRow(
                  'المساحة (م²)',
                  areaMain,
                  'نوع العرض',
                  property.offerType.arabicName,
                ),
              ),
            ),
          ),
          if (rd != null && rd.landArea > 0) ...[
            const Divider(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAreaDetailsDialog(property, 'المساحات');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _propertySpecRow(
                    'مساحة الأرض (م²)',
                    rd.landArea.toStringAsFixed(0),
                    '',
                    '',
                    showSecond: false,
                  ),
                ),
              ),
            ),
          ],
          const Divider(height: 24),
          _propertySpecRow(
            'نوع العقار',
            property.type.toArabic(),
            '',
            '',
            showSecond: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBedBathSpecsRow({
    required PropertyModel property,
    required int beds,
    required int baths,
    required bool hasRoomDetails,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (hasRoomDetails) {
                  _showRoomDetailsDialog(property, 'غرف النوم');
                } else {
                  _showSpecDetails(context, 'الغرف', [
                    'إجمالي الغرف: ${property.rooms}',
                  ]);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'غرف النوم',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      beds.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (hasRoomDetails) {
                  _showBathroomDetailsDialog(property, 'الحمامات');
                } else {
                  _showSpecDetails(context, 'الحمامات', [
                    'إجمالي الحمامات: ${property.bathrooms}',
                  ]);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حمامات',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      baths.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _propertySpecRow(
    String label1,
    String value1,
    String label2,
    String value2, {
    bool showSecond = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (showSecond) ...[
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdditionalDetailsCard(PropertyModel property) {
    final roomDetails = property.roomDetails!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل إضافية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (roomDetails.livingRooms > 0)
                _buildDetailChip(
                  Icons.chair_outlined,
                  '${roomDetails.livingRooms}',
                  'غرف معيشة',
                ),
              if (roomDetails.majlis > 0)
                _buildDetailChip(
                  Icons.weekend_outlined,
                  '${roomDetails.majlis}',
                  'مجالس',
                ),
              if (roomDetails.diningRooms > 0)
                _buildDetailChip(
                  Icons.restaurant_outlined,
                  '${roomDetails.diningRooms}',
                  'مقلط',
                ),
              if (roomDetails.kitchens > 0)
                _buildDetailChip(
                  Icons.kitchen_outlined,
                  '${roomDetails.kitchens}',
                  'مطابخ',
                ),
              if (roomDetails.menMajlis > 0)
                _buildDetailChip(
                  Icons.groups_outlined,
                  '${roomDetails.menMajlis}',
                  'مجلس رجال',
                ),
              if (roomDetails.womenMajlis > 0)
                _buildDetailChip(
                  Icons.groups_outlined,
                  '${roomDetails.womenMajlis}',
                  'مجلس نساء',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportantDetailsCard(PropertyModel property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل مهمة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (property.hasApartments)
            _buildInfoRow(Icons.apartment, 'الفيلا تحتوي على شقق منفصلة'),
          if (property.hasInternalStairs)
            _buildInfoRow(Icons.stairs, 'درج داخلي'),
          if (property.hasExternalStairs)
            _buildInfoRow(Icons.stairs_outlined, 'درج خارجي'),
          if (property.propertyDirection != null)
            _buildInfoRow(
              Icons.explore,
              'الاتجاه: ${property.propertyDirection}',
            ),
          if (property.streetWidth != null)
            _buildInfoRow(
              Icons.straighten,
              'عرض الشارع: ${property.streetWidth}',
            ),
        ],
      ),
    );
  }

  /// شارات فاتحة وحدود بنفسجية — أوضح من كتل بنفسجية صلبة فوق نص داكن.
  Widget _buildDetailChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoomDetailsDialog(PropertyModel property, String title) {
    final roomDetails = property.roomDetails;
    if (roomDetails == null) return;
    
    final details = <String>[];
    if (roomDetails.bedrooms > 0) {
      details.add('غرف نوم: ${roomDetails.bedrooms}');
      if (roomDetails.masterBedrooms > 0) {
        details.add('  - غرف نوم رئيسية: ${roomDetails.masterBedrooms}');
      }
    }
    if (roomDetails.livingRooms > 0) {
      details.add('غرف معيشة: ${roomDetails.livingRooms}');
    }
    if (roomDetails.majlis > 0) {
      details.add('مجالس: ${roomDetails.majlis}');
      if (roomDetails.menMajlis > 0) {
        details.add('  - مجلس رجال: ${roomDetails.menMajlis}');
      }
      if (roomDetails.womenMajlis > 0) {
        details.add('  - مجلس نساء: ${roomDetails.womenMajlis}');
      }
    }
    if (roomDetails.diningRooms > 0) {
      details.add('مقلط: ${roomDetails.diningRooms}');
    }
    if (roomDetails.kitchens > 0) {
      details.add('مطابخ: ${roomDetails.kitchens}');
    }
    if (roomDetails.storageRooms > 0) {
      details.add('غرف تخزين: ${roomDetails.storageRooms}');
    }
    if (roomDetails.maidRooms > 0) {
      details.add('غرف خادمة: ${roomDetails.maidRooms}');
    }
    if (roomDetails.driverRooms > 0) {
      details.add('غرف سائق: ${roomDetails.driverRooms}');
    }
    if (roomDetails.laundryRooms > 0) {
      details.add('غرف غسيل: ${roomDetails.laundryRooms}');
    }
    
    _showSpecDetails(context, title, details);
  }

  void _showBathroomDetailsDialog(PropertyModel property, String title) {
    final roomDetails = property.roomDetails;
    if (roomDetails == null) return;
    
    final details = <String>[];
    if (roomDetails.bathrooms > 0) {
      details.add('إجمالي الحمامات: ${roomDetails.bathrooms}');
    }
    if (roomDetails.masterBathrooms > 0) {
      details.add('حمامات رئيسية: ${roomDetails.masterBathrooms}');
    }
    if (roomDetails.guestBathrooms > 0) {
      details.add('حمامات ضيوف: ${roomDetails.guestBathrooms}');
    }
    if (roomDetails.serviceBathrooms > 0) {
      details.add('حمامات خدمة: ${roomDetails.serviceBathrooms}');
    }
    
    _showSpecDetails(context, title, details);
  }

  void _showAreaDetailsDialog(PropertyModel property, String title) {
    final roomDetails = property.roomDetails;
    if (roomDetails == null) return;
    
    final details = <String>[];
    if (roomDetails.totalBuiltArea > 0) {
      details.add('المساحة المبنية: ${roomDetails.totalBuiltArea.toStringAsFixed(1)} م²');
    }
    if (roomDetails.landArea > 0) {
      details.add('مساحة الأرض: ${roomDetails.landArea.toStringAsFixed(1)} م²');
    }
    if (roomDetails.gardenArea > 0) {
      details.add('مساحة الحديقة: ${roomDetails.gardenArea.toStringAsFixed(1)} م²');
    }
    if (roomDetails.yardArea > 0) {
      details.add('مساحة الحوش: ${roomDetails.yardArea.toStringAsFixed(1)} م²');
    }
    if (details.isEmpty) {
      details.add('المساحة الإجمالية: ${property.area.toStringAsFixed(1)} م²');
    }
    
    _showSpecDetails(context, title, details);
  }

  void _showSpecDetails(
      BuildContext context, String title, List<String> details) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل $title',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map((detail) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(PropertyModel property) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final Uri url = Uri.parse('tel:${property.contactPhone}');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن الاتصال بالرقم'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.contactPhone,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.address,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyLocation(PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الموقع',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            // ✅ زر فتح في Google Maps
            if (property.location.latitude != 0 && property.location.longitude != 0)
              ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(property.location, property.address),
                icon: const Icon(Icons.directions, size: 20),
                label: const Text('فتح في Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (property.location.latitude != 0 && property.location.longitude != 0) ...[
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: property.location,
                zoom: 15.0,
              ),
              onMapCreated: (GoogleMapController controller) async {
                debugPrint('تم إنشاء الخريطة بنجاح');
              },
              markers: {
                Marker(
                  markerId: MarkerId(property.id),
                  position: property.location,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
              },
            ),
          ),
          const SizedBox(height: 12),
          // ✅ بطاقة العنوان مع زر نسخ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withAlpha(77),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    property.address,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryLight),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_off, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'الموقع غير متوفر',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// ✅ فتح الموقع في Google Maps
  Future<void> _openInGoogleMaps(LatLng location, String address) async {
    try {
      // ✅ إنشاء رابط Google Maps مع الإحداثيات
      final lat = location.latitude;
      final lng = location.longitude;
      
      // ✅ رابط Google Maps للتنقل (directions)
      // يمكن استخدام: google.navigation أو maps.google.com
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${Uri.encodeComponent(address)}',
      );
      
      // ✅ محاولة فتح في تطبيق Google Maps
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication, // ✅ فتح في تطبيق خارجي
        );
      } else {
        // ✅ إذا فشل، جرب رابط بديل
        final alternativeUrl = Uri.parse(
          'https://maps.google.com/?q=$lat,$lng',
        );
        if (await canLaunchUrl(alternativeUrl)) {
          await launchUrl(
            alternativeUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح Google Maps. يرجى التأكد من تثبيت التطبيق'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في فتح Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح Google Maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
