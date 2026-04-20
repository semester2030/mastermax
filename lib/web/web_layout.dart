import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/auth/services/auth_service.dart';
import '../src/core/theme/app_colors.dart';
import '../src/core/utils/color_utils.dart';
import '../src/core/constants/app_brand.dart';

/// Layout خاص بالويب - يحتوي على Sidebar و Header
class WebLayout extends StatefulWidget {
  final Widget child;
  final String title;

  const WebLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  State<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends State<WebLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1024;
        
        if (isWide) {
          // Desktop Layout
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                // Sidebar
                _buildSidebar(context),
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(context),
                      // Content
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile/Tablet Layout - Sidebar becomes drawer
          return Scaffold(
            backgroundColor: AppColors.background,
            key: _scaffoldKey,
            drawer: Drawer(
              width: 260,
              backgroundColor: AppColors.white,
              child: _buildSidebar(context),
            ),
            body: Column(
              children: [
                // Header with menu button
                _buildMobileHeader(context),
                // Content
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight,
            blurRadius: 4,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppBrand.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard,
                  title: 'لوحة التحكم',
                  route: '/dashboard',
                  index: 0,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.point_of_sale,
                  title: 'إدارة المبيعات',
                  route: '/sales-management',
                  index: 1,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.home,
                  title: 'إدارة العقارات',
                  route: '/properties-management',
                  index: 2,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.people_outline,
                  title: 'إدارة العملاء',
                  route: '/customers-management',
                  index: 3,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.home_work,
                  title: 'إدارة الإيجارات',
                  route: '/rentals-management',
                  index: 4,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.store,
                  title: 'إدارة الفروع',
                  route: '/branches-management',
                  index: 5,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.analytics,
                  title: 'التقارير والإحصائيات',
                  route: '/analytics',
                  index: 6,
                ),
              ],
            ),
          ),
          // User Info & Logout
          Consumer<AuthState>(
            builder: (context, authState, _) {
              if (authState.user == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  border: Border(
                    top: BorderSide(
                      color: ColorUtils.withOpacity(AppColors.primary, 0.1),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (authState.user?.name != null && authState.user!.name.isNotEmpty)
                                ? authState.user!.name.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authState.user?.name ?? 'مستخدم',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                authState.user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          await authService.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('تسجيل الخروج'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required int index,
  }) {
    // ✅ تحديد الصفحة الحالية بناءً على Route
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final isSelected = _getRouteIndex(currentRoute) == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.primary
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            debugPrint('🖱️ Menu item tapped: $title -> $route');
            
            // ✅ محاولة إغلاق Drawer على الموبايل (باستخدام try-catch لتجنب الأخطاء)
            try {
              final scaffoldState = Scaffold.of(context);
              if (scaffoldState.hasDrawer && scaffoldState.isDrawerOpen) {
                Navigator.of(context).pop();
                // ✅ انتظار قليل قبل التنقل
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    _navigateToRoute(context, route);
                  }
                });
                return;
              }
            } catch (e) {
              debugPrint('⚠️ Scaffold not found, proceeding with navigation: $e');
            }
            
            // ✅ التنقل مباشرة
            _navigateToRoute(context, route);
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          hoverColor: AppColors.primary.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.white
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ دالة مساعدة للتنقل - مثل الإجراءات السريعة
  void _navigateToRoute(BuildContext context, String route) {
    if (!context.mounted) return;
    
    debugPrint('🚀 Navigating to: $route');
    
    // ✅ معالجة خاصة لصفحة التقارير - تحتاج businessId
    if (route == '/analytics') {
      final authState = Provider.of<AuthState>(context, listen: false);
      final businessId = authState.user?.id ?? '';
      if (businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لا يمكن الوصول إلى التقارير بدون معرف المستخدم'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      // ✅ استخدام pushNamed مثل الإجراءات السريعة
      Navigator.of(context).pushNamed(route, arguments: businessId);
    } else {
      // ✅ استخدام pushNamed مباشرة مثل الإجراءات السريعة
      Navigator.of(context).pushNamed(route);
    }
  }

  int _getRouteIndex(String route) {
    switch (route) {
      case '/dashboard':
        return 0;
      case '/sales-management':
        return 1;
      case '/properties-management':
        return 2;
      case '/customers-management':
        return 3;
      case '/rentals-management':
        return 4;
      case '/branches-management':
        return 5;
      case '/analytics':
        return 6;
      default:
        return -1;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          // Actions
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.textPrimary,
            tooltip: 'الإشعارات',
            onPressed: () {
              // TODO: إشعارات
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.textPrimary,
            tooltip: 'الإعدادات',
            onPressed: () {
              // TODO: إعدادات
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu Button
          IconButton(
            icon: const Icon(Icons.menu),
            color: AppColors.textPrimary,
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const SizedBox(width: 12),
          // Logo
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.business,
              color: AppColors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.textPrimary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('قريباً: الإشعارات'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
