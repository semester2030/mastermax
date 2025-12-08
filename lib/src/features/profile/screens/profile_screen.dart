import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/models/user_type.dart';
import '../../properties/screens/property_management_screen.dart';
import '../../premium_ads/screens/premium_ads_screen.dart';
import '../../customer_service/screens/customer_service_screen.dart';
import 'business_analytics_screen.dart';
import 'car_showroom/vehicles_and_sales_management_screen.dart';
import '../../auth/providers/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

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
        final userType = authState.userType;
        final isAdmin = authState.isAdmin;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
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
                  color: AppColors.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          body: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isTrialMode, userType),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isTrialMode, UserType userType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: const Icon(
              Icons.person,
              size: 50,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'مرحباً بك في أضواء ماكس',
            style: TextStyle(
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
        ],
      ),
    );
  }

  Widget _buildUserTypeSelector(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: AppColors.accent,
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
    if (userType == UserType.carDealer) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'المميزات المتاحة لمعرض سيارات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: AppColors.brightGold),
              title: const Text(
                'إدارة المركبات والمبيعات',
                style: TextStyle(color: AppColors.textLight),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VehiclesAndSalesManagementScreen(),
                  ),
                );
              },
            ),
            _buildFeatureItem(
              'خدمة ما بعد البيع',
              Icons.build,
              () {
                // TODO: Implement after-sales service
              },
            ),
            _buildFeatureItem(
              'الضمان والصيانة',
              Icons.security,
              () {
                // TODO: Implement warranty and maintenance
              },
            ),
            _buildFeatureItem(
              'العروض الخاصة',
              Icons.local_offer,
              () {
                // TODO: Implement special offers
              },
            ),
            _buildFeatureItem(
              'التمويل والتقسيط',
              Icons.account_balance,
              () {
                // TODO: Implement financing
              },
            ),
          ],
        ),
      );
    }

    final features = _getFeaturesForUserType(userType);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                color: AppColors.accent,
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
                    color: Colors.white,
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

  Widget _buildFeatureItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textLight),
      ),
      onTap: onTap,
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
      Navigator.pushNamed(context, '/profile/real-estate/features/sales');
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
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text('تجربة ميزة: $feature'),
            const SizedBox(height: 8),
            const Text(
              'هذه تجربة للميزة في الوضع التجريبي',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
        return [
          // المميزات الأساسية
          'إدارة العقارات',
          'إدارة المبيعات',
          'إدارة الفريق',
          'التقارير والإحصائيات',
          'الإعلانات المميزة',
          'خدمة العملاء',
          'التسويق الرقمي',
          // مميزات متخصصة
          'إدارة العقود',
          'التقييم العقاري',
          'جدولة المعاينات',
        ];
      case UserType.carDealer:
        return [
          'إدارة المركبات',
          'إدارة المبيعات',
          'خدمة ما بعد البيع',
          'الضمان والصيانة',
          'العروض الخاصة',
          'التمويل والتقسيط',
        ];
      case UserType.realEstateAgent:
        return [
          'إدارة العقارات',
          'جدولة المعاينات',
          'متابعة العملاء',
          'العمولات والمدفوعات',
          'التقييم العقاري',
        ];
      case UserType.carTrader:
        return [
          'إدارة المخزون',
          'طلبات الشراء',
          'المزادات',
          'الشحن والتوصيل',
          'خدمات الفحص',
        ];
    }
  }

  Widget _buildBusinessFeatures(UserType userType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'مميزات إضافية للأعمال',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: Icon(Icons.business, color: Colors.blue),
              ),
              if (userType == UserType.realEstateCompany || 
                  userType == UserType.carDealer) ...[
                _buildBusinessFeatureItem(
                  'إدارة الفريق',
                  Icons.people,
                  'إدارة أعضاء الفريق والصلاحيات',
                ),
                _buildBusinessFeatureItem(
                  'التحليلات والتقارير',
                  Icons.analytics,
                  'إحصائيات وتقارير تفصيلية',
                ),
                _buildBusinessFeatureItem(
                  'إدارة الفروع',
                  Icons.store,
                  'إدارة فروع الشركة',
                ),
              ],
              if (userType == UserType.realEstateAgent || 
                  userType == UserType.carTrader) ...[
                _buildBusinessFeatureItem(
                  'إدارة العملاء',
                  Icons.people_outline,
                  'متابعة وإدارة العملاء',
                ),
                _buildBusinessFeatureItem(
                  'جدولة المواعيد',
                  Icons.calendar_today,
                  'تنظيم المواعيد والمعاينات',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessFeatureItem(String title, IconData icon, String subtitle) {
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
    );
  }

  bool _isBusinessUser(UserType type) {
    return type == UserType.realEstateCompany ||
           type == UserType.carDealer ||
           type == UserType.realEstateAgent ||
           type == UserType.carTrader;
  }

  Widget _buildAdminFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sync,
                color: AppColors.accent,
              ),
            ),
            title: const Text(
              'نقل البيانات',
              style: TextStyle(
                color: AppColors.textLight,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.accent,
            ),
            onTap: () => Navigator.pushNamed(context, '/admin/data-transfer'),
          ),
        ],
      ),
    );
  }
} 