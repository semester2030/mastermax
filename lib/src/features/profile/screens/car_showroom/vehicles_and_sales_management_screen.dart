import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';

class VehiclesAndSalesManagementScreen extends StatefulWidget {
  const VehiclesAndSalesManagementScreen({super.key});

  @override
  State<VehiclesAndSalesManagementScreen> createState() => _VehiclesAndSalesManagementScreenState();
}

class _VehiclesAndSalesManagementScreenState extends State<VehiclesAndSalesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDashboardStats(),
          const SizedBox(height: 20),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVehiclesList(),
                _buildSalesView(),
                _buildCustomersView(),
                _buildReportsView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.transparent,
      elevation: 0,
      title: const Row(
        children: [
          Icon(
            Icons.directions_car_filled,
            color: AppColors.brightGold,
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'إدارة المركبات والمبيعات',
            style: TextStyle(
              color: AppColors.brightGold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.brightGold,
          onPressed: () {
            // Show notifications
            _showNotificationsDialog();
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          color: AppColors.brightGold,
          onPressed: () {
            // Show settings
            _showSettingsDialog();
          },
        ),
      ],
    );
  }

  Widget _buildDashboardStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_outlined, color: AppColors.brightGold),
              SizedBox(width: 8),
              Text(
                'لوحة المعلومات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'إجمالي المركبات',
                '25',
                Icons.directions_car_filled,
                AppColors.brightGold,
                'عدد السيارات المتوفرة حالياً',
              ),
              _buildStatCard(
                'المركبات المباعة',
                '12',
                Icons.sell_outlined,
                Colors.green,
                'إجمالي المبيعات هذا الشهر',
              ),
              _buildStatCard(
                'تحت الحجز',
                '5',
                Icons.pending_actions_outlined,
                Colors.orange,
                'عدد الحجوزات النشطة',
              ),
              _buildStatCard(
                'إجمالي الأرباح',
                '١،٢٥٠،٠٠٠ ر.س',
                Icons.account_balance_wallet_outlined,
                AppColors.accent,
                'الأرباح الإجمالية للشهر الحالي',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(Colors.grey, 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
        indicatorColor: AppColors.brightGold,
        labelColor: AppColors.brightGold,
        unselectedLabelColor: Colors.grey,
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
        onPressed = _showAddVehicleDialog;
        break;
      case 1:
        icon = Icons.add_shopping_cart_outlined;
        tooltip = 'تسجيل عملية بيع';
        onPressed = _showAddSaleDialog;
        break;
      case 2:
        icon = Icons.person_add_outlined;
        tooltip = 'إضافة عميل جديد';
        onPressed = _showAddCustomerDialog;
        break;
      default:
        icon = Icons.add_chart;
        tooltip = 'إنشاء تقرير جديد';
        onPressed = _showCreateReportDialog;
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.brightGold,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  Widget _buildVehiclesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.withOpacity(Colors.grey, 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car_filled,
                color: AppColors.brightGold,
                size: 32,
              ),
            ),
            title: const Text(
              'تويوتا كامري 2023',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: AppColors.brightGold,
                    ),
                    SizedBox(width: 4),
                    Text('السعر: ١٢٠،٠٠٠ ر.س'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: AppColors.brightGold,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'معروض',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.brightGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: AppColors.brightGold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                _buildPopupMenuItem(
                  'تعديل',
                  Icons.edit_outlined,
                  'edit',
                ),
                _buildPopupMenuItem(
                  'حذف',
                  Icons.delete_outline,
                  'delete',
                ),
              ],
              onSelected: (value) {
                // Handle menu item selection
              },
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem _buildPopupMenuItem(String title, IconData icon, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.brightGold,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.brightGold,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'رقم المعاملة: #12345',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تاريخ البيع: ${DateTime.now().toString().substring(0, 10)}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                const Row(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      color: AppColors.brightGold,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('تويوتا كامري 2023'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: AppColors.brightGold,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text('سعر البيع: ١٢٠،٠٠٠ ر.س'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'الربح: ١٠،٠٠٠ ر.س',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomersView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.brightGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: AppColors.brightGold,
                ),
                SizedBox(width: 8),
                Text(
                  'اسم العميل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    const Text('رقم الجوال: 05xxxxxxxx'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brightGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'عدد المعاملات: 2',
                        style: TextStyle(
                          color: AppColors.brightGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brightGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.brightGold,
                  size: 16,
                ),
              ),
              onPressed: () {
                // Navigate to customer details
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsView() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildReportCard(
          'تقرير المبيعات',
          Icons.bar_chart,
          'تحليل المبيعات والإيرادات',
          () => _showSalesReport(),
        ),
        _buildReportCard(
          'تقرير المخزون',
          Icons.inventory_2,
          'حالة المخزون والتكاليف',
          () => _showInventoryReport(),
        ),
        _buildReportCard(
          'تقرير العملاء',
          Icons.people,
          'تحليل بيانات العملاء',
          () => _showCustomersReport(),
        ),
        _buildReportCard(
          'تقرير الأداء',
          Icons.trending_up,
          'مؤشرات الأداء الرئيسية',
          () => _showPerformanceReport(),
        ),
      ],
    );
  }

  Widget _buildReportCard(String title, IconData icon, String description, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.brightGold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalesReport() {
    // تنفيذ منطق تقرير المبيعات
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('تقرير المبيعات'),
          ],
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // هنا يمكن إضافة رسم بياني أو إحصائيات المبيعات
              Text('إجمالي المبيعات: ١،٢٥٠،٠٠٠ ر.س'),
              Text('عدد المركبات المباعة: ١٢'),
              Text('متوسط سعر البيع: ١٠٤،١٦٧ ر.س'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              // تصدير التقرير
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('تصدير PDF'),
          ),
        ],
      ),
    );
  }

  void _showInventoryReport() {
    // تنفيذ منطق تقرير المخزون
  }

  void _showCustomersReport() {
    // تنفيذ منطق تقرير العملاء
  }

  void _showPerformanceReport() {
    // تنفيذ منطق تقرير الأداء
  }

  void _showCreateReportDialog() {
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_chart, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('إنشاء تقرير جديد'),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: 'نوع التقرير',
                      prefixIcon: Icon(Icons.description, color: AppColors.brightGold),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sales', child: Text('تقرير المبيعات')),
                      DropdownMenuItem(value: 'inventory', child: Text('تقرير المخزون')),
                      DropdownMenuItem(value: 'customers', child: Text('تقرير العملاء')),
                      DropdownMenuItem(value: 'performance', child: Text('تقرير الأداء')),
                    ],
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.brightGold,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => startDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ',
                        prefixIcon: Icon(Icons.calendar_today, color: AppColors.brightGold),
                      ),
                      child: Text(
                        startDate != null
                            ? '${startDate!.year}/${startDate!.month}/${startDate!.day}'
                            : 'اختر التاريخ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.brightGold,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => endDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'إلى تاريخ',
                        prefixIcon: Icon(Icons.calendar_today, color: AppColors.brightGold),
                      ),
                      child: Text(
                        endDate != null
                            ? '${endDate!.year}/${endDate!.month}/${endDate!.day}'
                            : 'اختر التاريخ',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (startDate != null && endDate != null) {
                // إنشاء التقرير باستخدام التواريخ المحددة
                Navigator.pop(context);
                // يمكن هنا إضافة منطق إنشاء التقرير
                _showGeneratedReport(startDate!, endDate!);
              } else {
                // إظهار رسالة خطأ إذا لم يتم اختيار التواريخ
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء اختيار التواريخ'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _showGeneratedReport(DateTime startDate, DateTime endDate) {
    // هنا يمكن إضافة منطق عرض التقرير المولد
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('التقرير المولد'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الفترة: من ${startDate.toString().substring(0, 10)} إلى ${endDate.toString().substring(0, 10)}'),
            const SizedBox(height: 16),
            // هنا يمكن إضافة محتوى التقرير
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              // تصدير التقرير
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('تصدير PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Card(
          elevation: 4,
          child: InkWell(
            onTap: () => _showDetailedStatsDialog(title, value, tooltip),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailedStatsDialog(String title, String value, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: AppColors.brightGold),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.brightGold),
              title: const Text('القيمة الحالية'),
              subtitle: Text(value),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.brightGold),
              title: const Text('الوصف'),
              subtitle: Text(description),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.brightGold),
              title: const Text('السجل التاريخي'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to historical data
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up, color: AppColors.brightGold),
              title: const Text('التوقعات'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to predictions
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brightGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.brightGold,
              ),
            ),
            const SizedBox(width: 8),
            const Text('الإشعارات'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                    child: const Icon(
                      Icons.notification_important_outlined,
                      color: AppColors.brightGold,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'إشعار ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفاصيل الإشعار ${index + 1}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'منذ ${index + 1} ساعات',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.brightGold,
                    ),
                    onPressed: () {
                      // Show notification options
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.close,
              color: Colors.grey[600],
              size: 20,
            ),
            label: Text(
              'إغلاق',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton.icon(
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppColors.brightGold,
              size: 20,
            ),
            label: const Text(
              'تعليم الكل كمقروء',
              style: TextStyle(
                color: AppColors.brightGold,
              ),
            ),
            onPressed: () {
              // Mark all as read
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brightGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings,
                color: AppColors.brightGold,
              ),
            ),
            const SizedBox(width: 8),
            const Text('الإعدادات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingsItem(
              'اللغة',
              Icons.language_outlined,
              'تغيير لغة التطبيق',
              () {
                // Handle language settings
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsItem(
              'الإشعارات',
              Icons.notifications_outlined,
              'إدارة إعدادات الإشعارات',
              () {
                // Handle notification settings
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsItem(
              'الأمان',
              Icons.security_outlined,
              'إعدادات الأمان والخصوصية',
              () {
                // Handle security settings
              },
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.close,
              color: Colors.grey[600],
              size: 20,
            ),
            label: Text(
              'إغلاق',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.brightGold,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: AppColors.brightGold,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAddVehicleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('إضافة مركبة جديدة'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'نوع المركبة',
                  prefixIcon: Icon(Icons.directions_car, color: AppColors.brightGold),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'الموديل',
                  prefixIcon: Icon(Icons.calendar_today, color: AppColors.brightGold),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'السعر',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.brightGold),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle adding vehicle
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddSaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart_outlined, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('تسجيل عملية بيع'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'المركبة',
                  prefixIcon: Icon(Icons.directions_car, color: AppColors.brightGold),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('تويوتا كامري 2023')),
                  DropdownMenuItem(value: '2', child: Text('هوندا أكورد 2023')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'العميل',
                  prefixIcon: Icon(Icons.person, color: AppColors.brightGold),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('أحمد محمد')),
                  DropdownMenuItem(value: '2', child: Text('محمد أحمد')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'سعر البيع',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.brightGold),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle sale
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_outlined, color: AppColors.brightGold),
            SizedBox(width: 8),
            Text('إضافة عميل جديد'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'اسم العميل',
                  prefixIcon: Icon(Icons.person, color: AppColors.brightGold),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'رقم الجوال',
                  prefixIcon: Icon(Icons.phone, color: AppColors.brightGold),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email, color: AppColors.brightGold),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle adding customer
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightGold,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
} 