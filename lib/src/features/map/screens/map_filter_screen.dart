import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../widgets/filters/filter_state.dart';
import '../widgets/filters/property_filter_section.dart';
import '../widgets/filters/car_filter_section.dart';

class MapFilterScreen extends StatefulWidget {
  final bool isRealEstate; // لتحديد نوع الفلتر (عقارات/سيارات)

  const MapFilterScreen({
    required this.isRealEstate,
    super.key,
  });

  // دالة مساعدة لعرض الفلتر كـ popup
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required bool isRealEstate,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => MapFilterScreen(
          isRealEstate: isRealEstate,
        ),
      ),
    );
  }

  @override
  State<MapFilterScreen> createState() => _MapFilterScreenState();
}

class _MapFilterScreenState extends State<MapFilterScreen> {
  late FilterState _filterState;
  bool _showAdvancedOptions = false;
  int _selectedCount = 0;

  @override
  void initState() {
    super.initState();
    _filterState = FilterState();
    _updateSelectedCount();
  }

  void _updateSelectedCount() {
    setState(() {
      _selectedCount = _filterState.getSelectedCount(
        isRealEstate: widget.isRealEstate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRealEstate ? 'فلترة العقارات' : 'فلترة السيارات',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_selectedCount > 0)
                      Text(
                        'الفلاتر النشطة: $_selectedCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showAdvancedOptions
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAdvancedOptions = !_showAdvancedOptions;
                        });
                      },
                      tooltip: _showAdvancedOptions
                          ? 'عرض أقل'
                          : 'خيارات متقدمة',
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
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isRealEstate) ...[
                    PropertyFilterSection(
                      state: _filterState,
                      onUpdate: _updateSelectedCount,
                    ),
                    if (_showAdvancedOptions) ...[
                      PropertyAdvancedFilterSection(
                        state: _filterState,
                        onUpdate: _updateSelectedCount,
                      ),
                    ],
                  ] else ...[
                    CarFilterSection(
                      state: _filterState,
                      onUpdate: _updateSelectedCount,
                    ),
                    if (_showAdvancedOptions) ...[
                      CarAdvancedFilterSection(
                        state: _filterState,
                        onUpdate: _updateSelectedCount,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // Footer buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_selectedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'تم تحديد $_selectedCount من الفلاتر',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _filterState.reset(
                              isRealEstate: widget.isRealEstate,
                            );
                            _updateSelectedCount();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة تعيين'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final result = _filterState.toMap(
                            isRealEstate: widget.isRealEstate,
                          );
                          Navigator.pop(context, result);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('تطبيق'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
