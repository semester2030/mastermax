import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/profile/providers/real_estate/rental_provider.dart';
import '../src/features/profile/providers/real_estate/real_estate_customers_provider.dart';
import '../src/features/profile/providers/real_estate/branches_provider.dart';
import '../src/features/profile/screens/real_estate/viewmodels/sales_management_viewmodel.dart';
import '../src/features/profile/screens/real_estate/widgets/monthly_sales_chart_widget.dart';
import '../src/core/theme/app_colors.dart';
import '../src/core/utils/color_utils.dart';
import 'web_layout.dart';

/// لوحة التحكم الرئيسية للويب
class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // تحميل البيانات من جميع الـ Providers
    final context = this.context;
    if (!mounted) return;
    
    try {
      await Future.wait([
        context.read<RentalProvider>().loadRentals(),
        context.read<RealEstateCustomersProvider>().loadCustomers(),
        context.read<BranchesProvider>().loadBranches(),
        context.read<SalesManagementViewModel>().initializeData(context: context),
      ]);
    } catch (e) {
      debugPrint('خطأ في تحميل البيانات: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebLayout(
      title: 'لوحة التحكم',
      child: Consumer5<AuthState, RentalProvider, RealEstateCustomersProvider, BranchesProvider, SalesManagementViewModel>(
        builder: (context, authState, rentalProvider, customersProvider, branchesProvider, salesViewModel, _) {
          if (authState.user == null || _isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final userType = authState.user?.type ?? authState.userType;
          final salesCount = salesViewModel.sales.length;
          final totalSales = salesViewModel.totalSales;
          final totalProfit = salesViewModel.totalProfit;

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(context, authState.user?.name ?? 'مستخدم'),
                  const SizedBox(height: 32),

                  // Quick Stats
                  _buildQuickStats(
                    context,
                    salesCount: salesCount,
                    totalSales: totalSales,
                    totalProfit: totalProfit,
                    customersCount: customersProvider.customers.length,
                    rentalsCount: rentalProvider.rentalsCount,
                    branchesCount: branchesProvider.branches.length,
                  ),
                  const SizedBox(height: 32),

                  // Charts Section
                  _buildChartsSection(context, salesViewModel),
                  const SizedBox(height: 32),

                  // Quick Actions
                  _buildQuickActions(context, userType),
                  const SizedBox(height: 32),

                  // Recent Activity
                  _buildRecentActivity(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $userName',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'إدارة شاملة لعملك العقاري',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.white, 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard,
              size: 40,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context, {
    required int salesCount,
    required double totalSales,
    required double totalProfit,
    required int customersCount,
    required int rentalsCount,
    required int branchesCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        final isMedium = constraints.maxWidth > 800;
        
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'إجمالي المبيعات',
                  value: salesCount.toString(),
                  subtitle: _formatCurrency(totalSales),
                  icon: Icons.point_of_sale,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'إجمالي الأرباح',
                  value: _formatCurrency(totalProfit),
                  subtitle: 'من المبيعات',
                  icon: Icons.trending_up,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'العملاء',
                  value: customersCount.toString(),
                  subtitle: 'عميل نشط',
                  icon: Icons.people,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'عقود الإيجار',
                  value: rentalsCount.toString(),
                  subtitle: 'عقد نشط',
                  icon: Icons.home_work,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'الفروع',
                  value: branchesCount.toString(),
                  subtitle: 'فرع',
                  icon: Icons.store,
                  color: AppColors.primary,
                ),
              ),
            ],
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'إجمالي المبيعات',
                      value: salesCount.toString(),
                      subtitle: _formatCurrency(totalSales),
                      icon: Icons.point_of_sale,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'إجمالي الأرباح',
                      value: _formatCurrency(totalProfit),
                      subtitle: 'من المبيعات',
                      icon: Icons.trending_up,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'العملاء',
                      value: customersCount.toString(),
                      subtitle: 'عميل نشط',
                      icon: Icons.people,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'عقود الإيجار',
                      value: rentalsCount.toString(),
                      subtitle: 'عقد نشط',
                      icon: Icons.home_work,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                title: 'الفروع',
                value: branchesCount.toString(),
                subtitle: 'فرع',
                icon: Icons.store,
                color: AppColors.primary,
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildStatCard(
                context,
                title: 'إجمالي المبيعات',
                value: salesCount.toString(),
                subtitle: _formatCurrency(totalSales),
                icon: Icons.point_of_sale,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                title: 'إجمالي الأرباح',
                value: _formatCurrency(totalProfit),
                subtitle: 'من المبيعات',
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                title: 'العملاء',
                value: customersCount.toString(),
                subtitle: 'عميل نشط',
                icon: Icons.people,
                color: AppColors.primaryDark,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                title: 'عقود الإيجار',
                value: rentalsCount.toString(),
                subtitle: 'عقد نشط',
                icon: Icons.home_work,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                title: 'الفروع',
                value: branchesCount.toString(),
                subtitle: 'فرع',
                icon: Icons.store,
                color: AppColors.primary,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        // Navigate to relevant screen based on title
        switch (title) {
          case 'إجمالي المبيعات':
            Navigator.of(context).pushNamed('/sales-management');
            break;
          case 'العملاء':
            Navigator.of(context).pushNamed('/customers-management');
            break;
          case 'عقود الإيجار':
            Navigator.of(context).pushNamed('/rentals-management');
            break;
          case 'الفروع':
            Navigator.of(context).pushNamed('/branches-management');
            break;
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ColorUtils.withOpacity(color, 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.withOpacity(AppColors.textPrimary, 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ColorUtils.withOpacity(color, 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: ColorUtils.withOpacity(color, 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: ColorUtils.withOpacity(color, 0.7),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}م ر.س';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}ك ر.س';
    }
    return '${amount.toStringAsFixed(0)} ر.س';
  }

  Widget _buildChartsSection(BuildContext context, SalesManagementViewModel salesViewModel) {
    if (salesViewModel.sales.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الرسوم البيانية',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(AppColors.textPrimary, 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: MonthlySalesChartWidget(sales: salesViewModel.sales),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, userType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionCard(
              context,
              title: 'إدارة المبيعات',
              icon: Icons.point_of_sale,
              route: '/sales-management',
              color: AppColors.primary,
            ),
            _buildActionCard(
              context,
              title: 'إدارة العملاء',
              icon: Icons.people_outline,
              route: '/customers-management',
              color: AppColors.success,
            ),
            _buildActionCard(
              context,
              title: 'إدارة الإيجارات',
              icon: Icons.home_work,
              route: '/rentals-management',
              color: AppColors.primaryDark,
            ),
            _buildActionCard(
              context,
              title: 'إدارة الفروع',
              icon: Icons.store,
              route: '/branches-management',
              color: AppColors.textSecondary,
            ),
            _buildActionCard(
              context,
              title: 'التقارير والإحصائيات',
              icon: Icons.analytics,
              route: '/analytics',
              color: AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    required Color color,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ColorUtils.withOpacity(color, 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.withOpacity(AppColors.textPrimary, 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(color, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Consumer4<RentalProvider, RealEstateCustomersProvider, BranchesProvider, SalesManagementViewModel>(
      builder: (context, rentalProvider, customersProvider, branchesProvider, salesViewModel, _) {
        final recentRentals = rentalProvider.rentals.take(3).toList();
        final recentCustomers = customersProvider.customers.take(3).toList();
        final recentSales = salesViewModel.sales.take(3).toList();
        
        final hasActivity = recentRentals.isNotEmpty || recentCustomers.isNotEmpty || recentSales.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'النشاط الأخير',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hasActivity)
                  TextButton(
                    onPressed: () {
                      // Navigate to relevant screen
                    },
                    child: const Text('عرض الكل'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.withOpacity(AppColors.textPrimary, 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: hasActivity
                  ? Column(
                      children: [
                        if (recentSales.isNotEmpty) ...[
                          ...recentSales.map((sale) => _buildActivityItem(
                            context,
                            icon: Icons.point_of_sale,
                            title: 'عملية بيع جديدة',
                            subtitle: sale.propertyDetails.title,
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).pushNamed('/sales-management');
                            },
                          )),
                        ],
                        if (recentRentals.isNotEmpty) ...[
                          ...recentRentals.map((rental) => _buildActivityItem(
                            context,
                            icon: Icons.home_work,
                            title: 'عقد إيجار جديد',
                            subtitle: rental.propertyTitle,
                            color: AppColors.primaryDark,
                            onTap: () {
                              Navigator.of(context).pushNamed('/rentals-management');
                            },
                          )),
                        ],
                        if (recentCustomers.isNotEmpty) ...[
                          ...recentCustomers.map((customer) => _buildActivityItem(
                            context,
                            icon: Icons.person_add,
                            title: 'عميل جديد',
                            subtitle: customer.name,
                            color: AppColors.success,
                            onTap: () {
                              Navigator.of(context).pushNamed('/customers-management');
                            },
                          )),
                        ],
                      ],
                    )
                  : const Center(
                      child: Text(
                        'لا يوجد نشاط حديث',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(color, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: ColorUtils.withOpacity(color, 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
