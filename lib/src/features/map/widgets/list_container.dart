import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/map_state.dart';
import 'property_list_item.dart';
import 'car_list_item.dart';
import '../../properties/models/property_model.dart';
import '../../cars/models/car_model.dart';

/// Widget لحاوية قائمة العقارات/السيارات
///
/// يعرض قائمة من العقارات أو السيارات حسب نوع الفلتر المحدد
/// يتبع الثيم الموحد للتطبيق
class ListContainer extends StatelessWidget {
  final bool isPortrait;
  final MapFilterType selectedFilterType;
  final Function(PropertyModel) onPropertyTap;
  final Function(CarModel) onCarTap;
  final Function(String) onError;

  const ListContainer({
    super.key,
    required this.isPortrait,
    required this.selectedFilterType,
    required this.onPropertyTap,
    required this.onCarTap,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPortrait) {
      // ✅ في الوضع الأفقي، نستخدم Positioned كما هو
      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: MediaQuery.of(context).size.height * 0.45,
        child: _buildContainer(context),
      );
    }

    // ✅ في الوضع العمودي، نستخدم DraggableScrollableSheet
    return DraggableScrollableSheet(
      initialChildSize: 0.15, // ✅ يبدأ بـ 15% من الشاشة (الحد الأدنى)
      minChildSize: 0.15,     // ✅ الحد الأدنى: 15% (يمكن إنزاله إلى 15% فقط)
      maxChildSize: 0.45,      // ✅ الحد الأقصى: 45% (لا يمكن رفعه أكثر)
      snap: false,             // ✅ إلغاء Snap للسماح بالتحكم الكامل في أي ارتفاع بين 15% و 45%
      builder: (context, scrollController) {
        return _buildContainer(context, scrollController: scrollController);
      },
    );
  }

  /// ✅ بناء حاوية القائمة (مشتركة بين الوضعين)
  Widget _buildContainer(BuildContext context, {ScrollController? scrollController}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ Handle للسحب - واضح ومميز
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اسحب للتحكم',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MapState>(
              builder: (context, mapState, _) {
                if (selectedFilterType == MapFilterType.realEstate) {
                  return ListView.builder(
                    controller: scrollController, // ✅ ربط ScrollController
                    itemCount: mapState.visibleProperties.length,
                    itemBuilder: (context, index) {
                      final property = mapState.visibleProperties[index];
                      return PropertyListItem(
                        property: property,
                        onTap: () => onPropertyTap(property),
                        onError: onError,
                      );
                    },
                  );
                } else {
                  return ListView.builder(
                    controller: scrollController, // ✅ ربط ScrollController
                    itemCount: mapState.visibleCars.length,
                    itemBuilder: (context, index) {
                      final car = mapState.visibleCars[index];
                      return CarListItem(
                        car: car,
                        onTap: () => onCarTap(car),
                        onError: onError,
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
