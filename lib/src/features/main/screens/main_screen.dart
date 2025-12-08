import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../map/screens/main_map_screen.dart';
import '../../spotlight/screens/spotlight_category_screen.dart';
import '../../real_estate_cars/screens/real_estate_cars_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/models/user_type.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../real_estate_cars/providers/real_estate_cars_provider.dart';
import '../../cars/providers/car_provider.dart';
import '../../../navigation/bottom_navigation/bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  final UserType? userType;
  
  const MainScreen({
    super.key,
    this.userType,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.userType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authState = Provider.of<AuthState>(context, listen: false);
        authState.updateUserType(widget.userType!);
      });
    }

    // فتح شاشة نقل البيانات مباشرة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/admin/data-transfer');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AuthState>(
      builder: (context, authState, _) {
        final userId = authState.user?.id ?? 'guest';
        final screens = [
          MainMapScreen(key: ValueKey('map_$userId')),          // الخريطة
          SpotlightCategoryScreen(key: ValueKey('spotlight_$userId')), // أضواء ماكس
          RealEstateCarsScreen(key: ValueKey('listings_$userId')), // العروض
          FavoritesScreen(key: ValueKey('favorites_$userId')),  // المفضلة
          ProfileScreen(key: ValueKey('profile_$userId')),      // حسابي
        ];

        return Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withAlpha(26), // 0.1 * 255 ≈ 26
                      colorScheme.primary.withAlpha(26),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              // الشاشة الحالية
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: screens[_currentIndex],
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 2 ? custom_animations.AnimatedScale(
            onTap: () async {
              final provider = Provider.of<RealEstateAndCarsProvider>(context, listen: false);
              final carProvider = Provider.of<CarProvider>(context, listen: false);
              
              if (!carProvider.isLoading) {
                final route = provider.isCarTab ? '/cars/add' : '/properties/add';
                await Navigator.pushNamed(context, route);
                
                // تحديث القائمة بعد الإضافة
                if (provider.isCarTab) {
                  await carProvider.loadCars();
                }
              }
            },
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withAlpha(204), // 0.8 * 255 ≈ 204
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(77), // 0.3 * 255 ≈ 77
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                color: colorScheme.onPrimary,
                size: 30,
              ),
            ),
          ) : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withAlpha(230), // 0.9 * 255 ≈ 230
                  colorScheme.secondary.withAlpha(230),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(77), // 0.3 * 255 ≈ 77
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        );
      },
    );
  }
} 