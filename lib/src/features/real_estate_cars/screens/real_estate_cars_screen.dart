import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/real_estate_cars_provider.dart';
import '../../../core/utils/color_utils.dart';
import '../../properties/screens/property_list_screen.dart';
import '../../cars/screens/car_list_screen.dart';
import '../../map/providers/map_state.dart';

class RealEstateCarsScreen extends StatefulWidget {
  const RealEstateCarsScreen({super.key});

  @override
  State<RealEstateCarsScreen> createState() => _RealEstateCarsScreenState();
}

class _RealEstateCarsScreenState extends State<RealEstateCarsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // تحديث حالة التبويب الأولية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<RealEstateAndCarsProvider>();
        provider.setCarTab(_tabController.index == 0);
      }
    });
    
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging && mounted) {
      final provider = context.read<RealEstateAndCarsProvider>();
      final isCarTab = _tabController.index == 0;
      provider.setCarTab(isCarTab);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ColorUtils.withOpacity(AppColors.primaryDark, 0.3),
                ColorUtils.withOpacity(AppColors.secondaryDark, 0.3),
              ],
            ),
          ),
        ),
        title: const Text(
          'السيارات والعقارات',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: ColorUtils.withOpacity(AppColors.accent, 0.7),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
          ),
          tabs: [
            Tab(
              child: const Text('سيارات'),
            ),
            Tab(
              child: const Text('عقارات'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.map_outlined,
              color: AppColors.accent,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/map',
                arguments: {'initialFilterType': MapFilterType.cars},
              );
            },
            tooltip: 'البحث في الخريطة',
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: TabBarView(
          controller: _tabController,
          children: const [
            // قسم السيارات
            CarListScreen(),
            // قسم العقارات
            PropertyListScreen(),
          ],
        ),
      ),
    );
  }
} 