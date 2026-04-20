import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/models/user_type.dart';
import '../../auth/models/user.dart';
import '../../properties/screens/property_management_screen.dart';
import '../../premium_ads/screens/premium_ads_screen.dart';
import '../../customer_service/screens/customer_service_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import 'business_analytics_screen.dart';
import 'car_showroom/vehicles_and_sales_management_screen.dart';
import '../widgets/coming_soon_feature.dart';
import 'real_estate/rentals/rentals_management_screen.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';
import '../../../core/constants/app_brand.dart';
import '../../chat/chat_screen_route_args.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, child) {
        final isTrialMode = authState.isTrialMode;
        // استخدام نوع المستخدم من بيانات المستخدم الفعلية
        final userType = authState.user?.type ?? authState.userType;
        final isAdmin = authState.isAdmin;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
              ),
            ),
            title: custom_animations.ShimmerLoading(
              baseColor: ColorUtils.withOpacity(AppColors.accent, 0.5),
              highlightColor: AppColors.accent,
              child: Text(
                isTrialMode ? 'الوضع التجريبي' : 'الملف الشخصي',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          body: Container(
            color: AppColors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isTrialMode, userType),
                  if (!isTrialMode) ...[
                    const SizedBox(height: 16),
                    _buildEditProfileButton(),
                  ],
                  if (!isTrialMode && authState.user != null) ...[
                    const SizedBox(height: 16),
                    _buildSpotlightAdChatsTile(context),
                  ],
                  if (isTrialMode) ...[
                    const SizedBox(height: 24),
                    _buildUserTypeSelector(authState),
                  ],
                  const SizedBox(height: 24),
                  _buildFeaturesList(userType),
                  if (_isBusinessUser(userType)) ...[
                    const SizedBox(height: 24),
                    _buildBusinessFeatures(userType),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildAdminFeatures(),
                  ],
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.policy_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                    title: const Text(
                      'السياسات والشروط',
                      style: TextStyle(
                        color: AppColors.textLight,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    onTap: () => Navigator.pushNamed(context, '/legal'),
                  ),
                  if (!isTrialMode && authState.user != null) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ColorUtils.withOpacity(AppColors.error, 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.error,
                        ),
                      ),
                      title: const Text(
                        'حذف الحساب',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'حذف نهائي لحسابك وبياناتك',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.withOpacity(AppColors.textSecondary, 0.9),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.error,
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, Routes.deleteAccount),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildLogoutButton(authState),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTrialMode, UserType userType) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final user = authState.user;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.3),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: ColorUtils.withOpacity(AppColors.accent, 0.1),
            backgroundImage: user?.extraData?['profileImage'] != null
                ? NetworkImage(user!.extraData!['profileImage'] as String)
                : null,
            child: user?.extraData?['profileImage'] == null
                ? const Icon(
                    Icons.person,
                    size: 50,
                    color: AppColors.accent,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _getDisplayName(user, userType) ?? 'مرحباً بك في ${AppBrand.displayName}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTrialMode
                ? 'أنت الآن في الوضع التجريبي'
                : 'نوع الحساب: ${userType.arabicName}',
            style: TextStyle(
              fontSize: 16,
              color: ColorUtils.withOpacity(AppColors.textLight, 0.8),
            ),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email,
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.withOpacity(AppColors.textLight, 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: custom_animations.AnimatedScale(
        onTap: () {
          Navigator.pushNamed(context, '/profile/edit');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.edit,
                color: AppColors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'تعديل الملف الشخصي',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightAdChatsTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.35),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.primary, 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.forum_outlined,
            color: AppColors.primary,
          ),
        ),
        title: const Text(
          'محادثات على إعلاناتي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textLight,
          ),
        ),
        subtitle: Text(
          'رسائل المهتمين بمقاطع دار كار — عرض والرد',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.withOpacity(AppColors.textSecondary, 0.95),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.accent,
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            Routes.chat,
            arguments: {
              ChatScreenRouteArgs.sellerInboxAllListings: true,
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTypeSelector(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر نوع الحساب',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserType.values.map((type) {
              final isSelected = type == authState.userType;
              return ChoiceChip(
                label: Text(
                  type.arabicName,
                  style: TextStyle(
                    color: isSelected ? AppColors.text : AppColors.textLight,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface,
                onSelected: (selected) {
                  if (selected) {
                    authState.setUserType(type);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(UserType userType) {
    final features = _getFeaturesForUserType(userType);
    
    // ✅ إخفاء القسم إذا كان فارغاً للحسابات التجارية
    if (features.isEmpty && _isBusinessUser(userType)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'المميزات المتاحة لـ ${userType.arabicName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return custom_animations.AnimatedScale(
                onTap: () {
                  _showFeatureDemo(context, features[index]);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const custom_animations.AnimatedGlow(
                      glowColor: AppColors.success,
                      child: Icon(Icons.check_circle, color: AppColors.success),
                    ),
                    title: Text(
                      features[index],
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFeatureDemo(BuildContext context, String feature) {
    if (feature == 'إدارة العقارات') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PropertyManagementScreen(),
        ),
      );
      return;
    }

    if (feature == 'إدارة المبيعات') {
      // ✅ التحقق من نوع الحساب
      final authState = Provider.of<AuthState>(context, listen: false);
      final userType = authState.user?.type ?? authState.userType;
      
      if (userType == UserType.realEstateCompany || userType == UserType.realEstateAgent) {
        Navigator.pushNamed(context, '/sales-management');
      } else if (userType == UserType.carDealer || userType == UserType.carTrader) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VehiclesAndSalesManagementScreen(
              initialTabIndex: 1,
            ),
          ),
        );
      }
      return;
    }
    
    if (feature == 'إدارة الإيجارات') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RentalsManagementScreen(),
        ),
      );
      return;
    }

    if (feature == 'إدارة الفريق') {
      Navigator.pushNamed(context, '/team-management');
      return;
    }

    if (feature == 'التقارير والإحصائيات') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusinessAnalyticsScreen(
            businessId: Provider.of<AuthState>(context, listen: false).user?.id ?? '',
          ),
        ),
      );
      return;
    }

    if (feature == 'الإعلانات المميزة') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PremiumAdsScreen(),
        ),
      );
      return;
    }

    if (feature == 'خدمة العملاء') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomerServiceScreen(),
        ),
      );
      return;
    }

    // ربط المفضلة
    if (feature == 'المفضلة') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FavoritesScreen(),
        ),
      );
      return;
    }

    // ربط المحادثات
    if (feature == 'المحادثات') {
      Navigator.pushNamed(context, Routes.chat);
      return;
    }

    // ربط الإشعارات (إذا كانت موجودة)
    if (feature == 'الإشعارات') {
      // TODO: إضافة شاشة الإشعارات
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(feature),
          content: const Text('شاشة الإشعارات قيد التطوير'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    // ربط العروض
    if (feature == 'العروض') {
      // الانتقال إلى شاشة العروض في MainScreen
      // يمكن استخدام Navigator.pushNamed أو الانتقال مباشرة
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(feature),
          content: const Text('يمكنك الوصول إلى العروض من الشاشة الرئيسية'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    // ربط التقييمات
    if (feature == 'التقييمات') {
      // TODO: إضافة شاشة التقييمات
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(feature),
          content: const Text('شاشة التقييمات قيد التطوير'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    // للميزات الأخرى، عرض dialog تجريبي
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 64,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            Text('تجربة ميزة: $feature'),
            const SizedBox(height: 8),
            const Text(
              'هذه تجربة للميزة في الوضع التجريبي',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  List<String> _getFeaturesForUserType(UserType type) {
    if (Provider.of<AuthState>(context, listen: false).isTrialMode) {
      return [
        // المميزات الأساسية
        'إدارة العقارات',
        'إدارة المبيعات',
        'إدارة الفريق',
        'التقارير والإحصائيات',
        'الإعلانات المميزة',
        'خدمة العملاء',
        'التسويق الرقمي',
        
        // مميزات السيارات
        'إدارة المركبات',
        'خدمة ما بعد البيع',
        'الضمان والصيانة',
        'العروض الخاصة',
        'التمويل والتقسيط',
        
        // مميزات العقارات
        'جدولة المعاينات',
        'التقييم العقاري',
        'إدارة الوحدات',
        'إدارة العقود',
        
        // مميزات عامة
        'المحادثات',
        'الإشعارات',
        'المفضلة',
        'التقييمات',
      ];
    }

    switch (type) {
      case UserType.individual:
        return [
          'المفضلة',
          'الإشعارات',
          'المحادثات',
          'العروض',
          'التقييمات',
        ];
      case UserType.realEstateCompany:
        // ✅ جميع المميزات في CRM فقط
        return [];
      case UserType.carDealer:
        // ✅ جميع المميزات في CRM فقط
        return [];
      case UserType.realEstateAgent:
        // ✅ جميع المميزات في CRM فقط
        return [];
      case UserType.carTrader:
        // ✅ جميع المميزات في CRM فقط
        return [];
    }
  }

  Widget _buildBusinessFeatures(UserType userType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ColorUtils.withOpacity(AppColors.accent, 0.3),
            ),
          ),
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'نظام إدارة الأعمال (CRM)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                leading: Icon(Icons.business_center, color: AppColors.primary),
              ),
              if (userType == UserType.realEstateCompany) ...[
                // ✅ إدارة العقارات (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة العقارات',
                  Icons.home,
                  'إدارة وإضافة العقارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PropertyManagementScreen(),
                      ),
                    );
                  },
                ),
                // ✅ إدارة المبيعات
                _buildBusinessFeatureItem(
                  'إدارة المبيعات',
                  Icons.point_of_sale,
                  'تتبع المبيعات والعقود',
                  () {
                    Navigator.pushNamed(context, '/sales-management');
                  },
                ),
                // ✅ إدارة الإيجارات
                _buildBusinessFeatureItem(
                  'إدارة الإيجارات',
                  Icons.home_work,
                  'إدارة عقود الإيجار والدفعات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RentalsManagementScreen(),
                      ),
                    );
                  },
                ),
                // ✅ إدارة العملاء
                _buildBusinessFeatureItem(
                  'إدارة العملاء',
                  Icons.people_outline,
                  'متابعة وإدارة العملاء',
                  () {
                    Navigator.pushNamed(context, '/customers-management');
                  },
                ),
                // ✅ إدارة الفروع
                _buildBusinessFeatureItem(
                  'إدارة الفروع',
                  Icons.store,
                  'إدارة فروع الشركة',
                  () {
                    Navigator.pushNamed(context, '/branches-management');
                  },
                ),
                // ✅ إدارة الفريق (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة الفريق',
                  Icons.people,
                  'إدارة أعضاء الفريق والصلاحيات',
                  () {
                    Navigator.pushNamed(context, '/team-management');
                  },
                ),
                // ✅ التحليلات والتقارير (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'التحليلات والتقارير',
                  Icons.analytics,
                  'إحصائيات وتقارير تفصيلية',
                  () {
                    final authState = Provider.of<AuthState>(context, listen: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessAnalyticsScreen(
                          businessId: authState.user?.id ?? '',
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة المخزون
                _buildBusinessFeatureItem(
                  'إدارة المخزون',
                  Icons.inventory,
                  'تتبع المخزون والوحدات',
                  () {
                    Navigator.pushNamed(context, '/inventory-management');
                  },
                ),
              ],
              if (userType == UserType.carDealer) ...[
                // ✅ إدارة المركبات (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة المركبات',
                  Icons.directions_car,
                  'إدارة وإضافة المركبات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 0,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة المبيعات
                _buildBusinessFeatureItem(
                  'إدارة المبيعات',
                  Icons.point_of_sale,
                  'تتبع مبيعات السيارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 1,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة العملاء
                _buildBusinessFeatureItem(
                  'إدارة العملاء',
                  Icons.people_outline,
                  'متابعة وإدارة عملاء السيارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 2,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة الفريق (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة الفريق',
                  Icons.people,
                  'إدارة أعضاء الفريق والصلاحيات',
                  () {
                    Navigator.pushNamed(context, '/team-management');
                  },
                ),
                // ✅ التحليلات والتقارير (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'التحليلات والتقارير',
                  Icons.analytics,
                  'إحصائيات وتقارير تفصيلية',
                  () {
                    final authState = Provider.of<AuthState>(context, listen: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessAnalyticsScreen(
                          businessId: authState.user?.id ?? '',
                        ),
                      ),
                    );
                  },
                ),
                // ✅ خدمة ما بعد البيع (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'خدمة ما بعد البيع',
                  Icons.build,
                  'خدمات الصيانة والدعم',
                  () {
                    showComingSoonFeatureDialog(context, 'خدمة ما بعد البيع');
                  },
                ),
                // ✅ الضمان والصيانة (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'الضمان والصيانة',
                  Icons.security,
                  'إدارة الضمانات وخدمات الصيانة',
                  () {
                    showComingSoonFeatureDialog(context, 'الضمان والصيانة');
                  },
                ),
                // ✅ العروض الخاصة (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'العروض الخاصة',
                  Icons.local_offer,
                  'إنشاء وإدارة العروض الترويجية',
                  () {
                    showComingSoonFeatureDialog(context, 'العروض الخاصة');
                  },
                ),
                // ✅ التمويل والتقسيط (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'التمويل والتقسيط',
                  Icons.account_balance,
                  'إدارة خطط التمويل والتقسيط',
                  () {
                    showComingSoonFeatureDialog(context, 'التمويل والتقسيط');
                  },
                ),
              ],
              if (userType == UserType.realEstateAgent) ...[
                // ✅ إدارة العقارات (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة العقارات',
                  Icons.home,
                  'إدارة وإضافة العقارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PropertyManagementScreen(),
                      ),
                    );
                  },
                ),
                // ✅ إدارة المبيعات
                _buildBusinessFeatureItem(
                  'إدارة المبيعات',
                  Icons.point_of_sale,
                  'تتبع المبيعات والعمولات',
                  () {
                    Navigator.pushNamed(context, '/sales-management');
                  },
                ),
                // ✅ إدارة العملاء
                _buildBusinessFeatureItem(
                  'إدارة العملاء',
                  Icons.people_outline,
                  'متابعة وإدارة العملاء',
                  () {
                    Navigator.pushNamed(context, '/customers-management');
                  },
                ),
                // ✅ إدارة الفريق (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة الفريق',
                  Icons.people,
                  'إدارة أعضاء الفريق والصلاحيات',
                  () {
                    Navigator.pushNamed(context, '/team-management');
                  },
                ),
                // ✅ التحليلات والتقارير (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'التحليلات والتقارير',
                  Icons.analytics,
                  'إحصائيات وتقارير تفصيلية',
                  () {
                    final authState = Provider.of<AuthState>(context, listen: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessAnalyticsScreen(
                          businessId: authState.user?.id ?? '',
                        ),
                      ),
                    );
                  },
                ),
                // ✅ جدولة المواعيد
                _buildBusinessFeatureItem(
                  'جدولة المواعيد',
                  Icons.calendar_today,
                  'تنظيم المواعيد والمعاينات',
                  () {
                    Navigator.pushNamed(context, '/appointments');
                  },
                ),
              ],
              if (userType == UserType.carTrader) ...[
                // ✅ إدارة المخزون (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'إدارة المخزون',
                  Icons.inventory,
                  'تتبع وإدارة مخزون السيارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 0,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة المبيعات
                _buildBusinessFeatureItem(
                  'إدارة المبيعات',
                  Icons.point_of_sale,
                  'تتبع مبيعات السيارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 1,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ إدارة العملاء
                _buildBusinessFeatureItem(
                  'إدارة العملاء',
                  Icons.people_outline,
                  'متابعة وإدارة عملاء السيارات',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehiclesAndSalesManagementScreen(
                          initialTabIndex: 2,
                        ),
                      ),
                    );
                  },
                ),
                // ✅ طلبات الشراء (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'طلبات الشراء',
                  Icons.shopping_cart,
                  'إدارة طلبات شراء السيارات',
                  () {
                    showComingSoonFeatureDialog(context, 'طلبات الشراء');
                  },
                ),
                // ✅ المزادات (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'المزادات',
                  Icons.gavel,
                  'إدارة المزادات والعطاءات',
                  () {
                    showComingSoonFeatureDialog(context, 'المزادات');
                  },
                ),
                // ✅ الشحن والتوصيل (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'الشحن والتوصيل',
                  Icons.local_shipping,
                  'تتبع الشحنات والتوصيل',
                  () {
                    showComingSoonFeatureDialog(context, 'الشحن والتوصيل');
                  },
                ),
                // ✅ خدمات الفحص (من "المميزات المتاحة")
                _buildBusinessFeatureItem(
                  'خدمات الفحص',
                  Icons.search,
                  'إدارة خدمات فحص السيارات',
                  () {
                    showComingSoonFeatureDialog(context, 'خدمات الفحص');
                  },
                ),
                // ✅ جدولة المواعيد
                _buildBusinessFeatureItem(
                  'جدولة المواعيد',
                  Icons.calendar_today,
                  'تنظيم المواعيد والمعاينات',
                  () {
                    Navigator.pushNamed(context, '/appointments');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessFeatureItem(String title, IconData icon, String subtitle, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: AppColors.accent,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  bool _isBusinessUser(UserType type) {
    return type == UserType.realEstateCompany ||
           type == UserType.carDealer ||
           type == UserType.realEstateAgent ||
           type == UserType.carTrader;
  }

  String? _getDisplayName(User? user, UserType userType) {
    if (user == null) return null;
    
    // للشركات العقارية: عرض اسم الشركة
    if (userType == UserType.realEstateCompany) {
      final companyName = user.extraData?['companyName'] as String?;
      if (companyName != null && companyName.isNotEmpty) {
        return companyName;
      }
    }
    
    // لمعارض السيارات: عرض اسم المعرض
    if (userType == UserType.carDealer) {
      final dealershipName = user.extraData?['dealershipName'] as String?;
      if (dealershipName != null && dealershipName.isNotEmpty) {
        return dealershipName;
      }
    }
    
    // للأنواع الأخرى أو إذا لم يكن هناك اسم شركة/معرض، عرض الاسم الشخصي
    return user.name;
  }

  Widget _buildAdminFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أدوات المسؤول',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // ✅ مراجعة طلبات التحقق
          _buildBusinessFeatureItem(
            'مراجعة طلبات التحقق',
            Icons.verified_user,
            'مراجعة وثائق التحقق للمستخدمين الجدد',
            () {
              Navigator.pushNamed(context, '/admin/verification');
            },
          ),
          // ✅ أدوات إدارة الفيديوهات (موجودة مسبقاً)
          _buildBusinessFeatureItem(
            'حذف الفيديوهات (أدمن)',
            Icons.delete_outline,
            'حذف الفيديوهات من قاعدة البيانات',
            () {
              Navigator.pushNamed(context, '/spotlight/admin/delete-videos');
            },
          ),
          _buildBusinessFeatureItem(
            'البحث عن الفيديوهات المفقودة',
            Icons.search,
            'البحث عن الفيديوهات التي لا توجد في التخزين',
            () {
              Navigator.pushNamed(context, '/spotlight/admin/find-orphaned');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AuthState authState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: custom_animations.AnimatedScale(
        onTap: () => _showLogoutDialog(context, authState),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.withOpacity(AppColors.error, 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.logout,
                color: AppColors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthState authState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            style: TextStyle(
              color: AppColors.textLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await authState.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في تسجيل الخروج: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 