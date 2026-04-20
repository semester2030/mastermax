import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/map_state.dart';

/// Widget لشريط البحث في الخريطة
///
/// يحتوي على:
/// - حقل البحث
/// - زر الفلترة
/// - أزرار تبديل نوع الفلتر (عقارات/سيارات)
/// يتبع الثيم الموحد للتطبيق
class MapSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final MapFilterType selectedFilterType;
  final Function(String) onSearch;
  final VoidCallback onShowPropertyFilters;
  final VoidCallback onShowCarFilters;
  final Function(MapFilterType) onFilterTypeChanged;

  const MapSearchBar({
    super.key,
    required this.searchController,
    required this.selectedFilterType,
    required this.onSearch,
    required this.onShowPropertyFilters,
    required this.onShowCarFilters,
    required this.onFilterTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن موقع...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    onSubmitted: onSearch,
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                GestureDetector(
                  onTap: () {
                    if (selectedFilterType == MapFilterType.realEstate) {
                      onShowPropertyFilters();
                    } else {
                      onShowCarFilters();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 30,
                  width: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TypeButton(
                        isSelected: selectedFilterType == MapFilterType.realEstate,
                        icon: Icons.home_work_outlined,
                        onTap: () => onFilterTypeChanged(MapFilterType.realEstate),
                      ),
                      const SizedBox(width: 8),
                      _TypeButton(
                        isSelected: selectedFilterType == MapFilterType.cars,
                        icon: Icons.directions_car_outlined,
                        onTap: () => onFilterTypeChanged(MapFilterType.cars),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget لزر نوع الفلتر
class _TypeButton extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeButton({
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.white : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
