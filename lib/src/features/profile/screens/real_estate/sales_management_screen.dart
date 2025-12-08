import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/property_models.dart';
import 'viewmodels/sales_management_viewmodel.dart';
import 'widgets/sales_summary_widget.dart';
import 'widgets/quick_stats_widget.dart';
import 'widgets/monthly_sales_chart_widget.dart';
import 'widgets/recent_transactions_widget.dart';
import 'widgets/sales_tab_widget.dart';
import 'widgets/inventory_tab_widget.dart';
import 'widgets/reports_tab_widget.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import 'package:mastermax_2030/src/core/utils/color_utils.dart';

class RealEstateSalesManagementScreen extends StatefulWidget {
  const RealEstateSalesManagementScreen({super.key});

  @override
  State<RealEstateSalesManagementScreen> createState() => _RealEstateSalesManagementScreenState();
}

class _RealEstateSalesManagementScreenState extends State<RealEstateSalesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = const [
    'نظرة عامة',
    'المبيعات',
    'المخزون',
    'التقارير',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SalesManagementViewModel()..initializeData(),
      child: Consumer<SalesManagementViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (viewModel.error != null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.initializeData(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: Container(
                color: Colors.white,
              ),
              title: const Text(
                'إدارة المبيعات العقارية',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.file_download),
                  color: AppColors.accent,
                  onPressed: () => _showExportDialog(context, viewModel),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  color: AppColors.accent,
                  onPressed: () => _selectDate(context, viewModel),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications),
                  color: AppColors.accent,
                  onPressed: () {},
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.white70,
                indicatorColor: AppColors.accent,
                tabs: _tabs.map((title) => Tab(text: title)).toList(),
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // نظرة عامة
                  Container(
                    color: Colors.white,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await viewModel.initializeData();
                      },
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SalesSummaryWidget(sales: viewModel.sales),
                            const SizedBox(height: 20),
                            QuickStatsWidget(sales: viewModel.sales),
                            const SizedBox(height: 20),
                            MonthlySalesChartWidget(sales: viewModel.sales),
                            const SizedBox(height: 20),
                            RecentTransactionsWidget(
                              tabController: _tabController,
                              sales: viewModel.sales,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // المبيعات
                  Container(
                    color: Colors.white,
                    child: SalesTabWidget(sales: viewModel.sales),
                  ),
                  // المخزون
                  Container(
                    color: Colors.white,
                    child: InventoryTabWidget(inventory: viewModel.inventory),
                  ),
                  // التقارير
                  Container(
                    color: Colors.white,
                    child: ReportsTabWidget(sales: viewModel.sales),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showAddSaleDialog(context, viewModel),
              backgroundColor: AppColors.accent,
              icon: const Icon(Icons.add),
              label: const Text('إضافة عملية بيع'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, SalesManagementViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: AppColors.white,
              surface: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      viewModel.updateSelectedDate(picked);
    }
  }

  void _showAddSaleDialog(BuildContext context, SalesManagementViewModel viewModel) {
    PropertyDetails? selectedProperty;
    PaymentMethod? selectedPaymentMethod;
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Row(
          children: [
            Icon(Icons.add_business, color: AppColors.accent),
            SizedBox(width: 8),
            Text(
              'إضافة عملية بيع جديدة',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.secondary, 0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<PropertyDetails>(
                      value: selectedProperty,
                      decoration: InputDecoration(
                        labelText: 'اختر العقار',
                        labelStyle: const TextStyle(color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null) return 'الرجاء اختيار العقار';
                        return null;
                      },
                      items: viewModel.inventory.map((property) {
                        return DropdownMenuItem<PropertyDetails>(
                          value: property,
                          child: Text(
                            property.title,
                            style: const TextStyle(color: AppColors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedProperty = value;
                        });
                      },
                      dropdownColor: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'سعر البيع',
                        labelStyle: const TextStyle(color: AppColors.accent),
                        prefixIcon: const Icon(Icons.monetization_on, color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال سعر البيع';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'الرجاء إدخال سعر صحيح';
                        }
                        if (selectedProperty != null && amount < selectedProperty!.purchasePrice) {
                          return 'سعر البيع أقل من سعر الشراء';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.white),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PaymentMethod>(
                      value: selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'طريقة الدفع',
                        labelStyle: const TextStyle(color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null) return 'الرجاء اختيار طريقة الدفع';
                        return null;
                      },
                      items: PaymentMethod.values.map((method) {
                        return DropdownMenuItem<PaymentMethod>(
                          value: method,
                          child: Text(
                            method.arabicName,
                            style: const TextStyle(color: AppColors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMethod = value;
                        });
                      },
                      dropdownColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (selectedProperty != null && 
                    selectedPaymentMethod != null && 
                      amount > 0) {
                  viewModel.addNewSale(
                    selectedProperty!,
                    amount,
                    selectedPaymentMethod!,
                  );
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, SalesManagementViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text(
          'تصدير التقرير',
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportButton(
              'تصدير PDF',
              Icons.picture_as_pdf,
              AppColors.error,
              () {
                Navigator.pop(context);
                viewModel.exportToPDF();
              },
            ),
            const SizedBox(height: 16),
            _buildExportButton(
              'تصدير Excel',
              Icons.table_chart,
              AppColors.success,
              () {
                Navigator.pop(context);
                viewModel.exportToExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: ColorUtils.withOpacity(color, 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: ColorUtils.withOpacity(color, 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 