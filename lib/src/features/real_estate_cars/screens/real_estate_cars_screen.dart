import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/real_estate_cars_provider.dart';
import '../../../core/utils/color_utils.dart';
import '../../properties/screens/property_list_screen.dart';
import '../../cars/screens/car_list_screen.dart';
import '../../map/providers/map_state.dart';

/// قائمة العروض الموحّدة: **الجميع** يطلع على تبويبي السيارات والعقارات.
/// تقييد النشر (زر +) يُطبَّق في [MainScreen] وشاشات القوائم وليس هنا.
class RealEstateCarsScreen extends StatelessWidget {
  const RealEstateCarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RealEstateCarsBody();
  }
}

class _RealEstateCarsBody extends StatefulWidget {
  const _RealEstateCarsBody();

  @override
  State<_RealEstateCarsBody> createState() => _RealEstateCarsBodyState();
}

class _RealEstateCarsBodyState extends State<_RealEstateCarsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RealEstateAndCarsProvider>();
      provider.setCarTab(_tabController.index == 0);
    });

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    context.read<RealEstateAndCarsProvider>().setCarTab(_tabController.index == 0);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  MapFilterType _mapFilterForAction() {
    return _tabController.index == 0
        ? MapFilterType.cars
        : MapFilterType.realEstate;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.transparent,
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
              'العروض',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.textPrimary,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor:
                  ColorUtils.withOpacity(AppColors.textPrimary, 0.5),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
              ),
              tabs: const [
                Tab(child: Text('سيارات')),
                Tab(child: Text('عقارات')),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.map_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/map',
                    arguments: {
                      'initialFilterType': _mapFilterForAction(),
                    },
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
                CarListScreen(),
                PropertyListScreen(),
              ],
            ),
          ),
        );
      },
    );
  }
}
