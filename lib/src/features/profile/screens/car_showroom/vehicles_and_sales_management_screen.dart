import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../cars/providers/car_provider.dart';
import '../../providers/car_showroom/customers_provider.dart';
import '../../providers/car_showroom/sales_provider.dart';
import 'widgets/dashboard_stats.dart';
import 'widgets/vehicles_tab.dart';
import 'widgets/sales_tab.dart';
import 'widgets/customers_tab.dart';
import 'widgets/reports_tab.dart';
import 'dialogs/notifications_dialog.dart';
import 'dialogs/settings_dialog.dart';
import 'dialogs/add_sale_dialog.dart';
import 'dialogs/add_customer_dialog.dart';
import 'dialogs/create_report_dialog.dart';
import 'dialogs/generated_report_dialog.dart';

class VehiclesAndSalesManagementScreen extends StatefulWidget {
  /// 0: المركبات، 1: المبيعات، 2: العملاء، 3: التقارير
  final int initialTabIndex;

  const VehiclesAndSalesManagementScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<VehiclesAndSalesManagementScreen> createState() => _VehiclesAndSalesManagementScreenState();
}

class _VehiclesAndSalesManagementScreenState extends State<VehiclesAndSalesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedIndex;
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 3);
    _selectedIndex = initial;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
    // تحميل البيانات من Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarProvider>().loadCars();
      context.read<CustomersProvider>().loadCustomers();
      context.read<SalesProvider>().loadSales();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: _buildAppBar(context, colorScheme, textTheme),
      body: Column(
        children: [
          DashboardStats(numberFormat: _numberFormat),
          const SizedBox(height: 20),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VehiclesTab(numberFormat: _numberFormat),
                const SalesTab(),
                const CustomersTab(),
                const ReportsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 1,
      shadowColor: colorScheme.primary.withValues(alpha: 0.3),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // primaryContainer في الثيم غير مُعرّف → يساوي primary في Material 3،
              // فالأيقونة بنفس لون الخلفية ولا تُرى. نستخدم خلفية فاتحة من هوية التطبيق.
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_car_filled,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'إدارة المركبات والمبيعات',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            tooltip: 'الإشعارات',
            icon: Icon(Icons.notifications_outlined, color: AppColors.primary),
            onPressed: () {
              NotificationsDialog.show(context);
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            tooltip: 'الإعدادات',
            icon: Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () {
              SettingsDialog.show(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(AppColors.primary, 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        tabs: [
          _buildTab('المركبات المعروضة', Icons.directions_car_outlined, 0),
          _buildTab('المبيعات', Icons.point_of_sale_outlined, 1),
          _buildTab('العملاء', Icons.people_outline_outlined, 2),
          _buildTab('التقارير', Icons.analytics_outlined, 3),
        ],
        indicatorColor: colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int index) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    IconData icon;
    String tooltip;
    VoidCallback onPressed;

    switch (_selectedIndex) {
      case 0:
        icon = Icons.add_circle_outline;
        tooltip = 'إضافة مركبة جديدة';
        onPressed = () async {
          final result = await Navigator.pushNamed(context, '/cars/add');
          if (result == true && mounted) {
            if (context.mounted) {
              context.read<CarProvider>().loadCars();
            }
          }
        };
        break;
      case 1:
        icon = Icons.add_shopping_cart_outlined;
        tooltip = 'تسجيل عملية بيع';
        onPressed = () => AddSaleDialog.show(context);
        break;
      case 2:
        icon = Icons.person_add_outlined;
        tooltip = 'إضافة عميل جديد';
        onPressed = () => AddCustomerDialog.show(context);
        break;
      default:
        icon = Icons.add_chart;
        tooltip = 'إنشاء تقرير جديد';
        onPressed = () {
          CreateReportDialog.show(
            context,
            onReportCreated: (startDate, endDate) {
              GeneratedReportDialog.show(
                context,
                startDate: startDate,
                endDate: endDate,
              );
            },
          );
        };
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      tooltip: tooltip,
      icon: Icon(icon),
      label: Text(
        tooltip,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
