import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/business_analytics_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

class BusinessAnalyticsScreen extends StatefulWidget {
  final String businessId;

  const BusinessAnalyticsScreen({
    required this.businessId, super.key,
  });

  @override
  State<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  final String _selectedPeriod = 'الشهر الحالي';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    if (_startDate == null || _endDate == null) {
      _initializeDates();
    }
    context.read<BusinessAnalyticsProvider>().loadAnalytics(
      widget.businessId,
      startDate: _startDate!,
      endDate: _endDate!,
    );
  }

  void _initializeDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'الأسبوع الحالي':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now;
        break;
      case 'الشهر الحالي':
        _startDate = DateTime(now.year, now.month);
        _endDate = now;
        break;
      case 'الشهر السابق':
        final lastMonth = DateTime(now.year, now.month - 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 0);
        break;
      case 'آخر 3 أشهر':
        _startDate = DateTime(now.year, now.month - 2);
        _endDate = now;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'التحليلات التجارية',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.accent),
            onPressed: () {
              // TODO: Implement filter functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.accent),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
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
                      'الملخص المالي',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          'المبيعات',
                          '٥٠٠,٠٠٠ ر.س',
                          Icons.trending_up,
                          AppColors.success,
                          growth: '+15%',
                        ),
                        _buildMetricCard(
                          'المصروفات',
                          '١٥٠,٠٠٠ ر.س',
                          Icons.trending_down,
                          AppColors.error,
                          growth: '-8%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 150,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                sections: [
                                  PieChartSectionData(
                                    value: 35,
                                    title: 'التسويق',
                                    color: ColorUtils.withOpacity(AppColors.primary, 0.7),
                                    radius: 40,
                                    titleStyle: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: 30,
                                    title: 'الرواتب',
                                    color: ColorUtils.withOpacity(AppColors.secondary, 0.7),
                                    radius: 40,
                                    titleStyle: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: 20,
                                    title: 'الصيانة',
                                    color: ColorUtils.withOpacity(AppColors.accent, 0.7),
                                    radius: 40,
                                    titleStyle: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: 15,
                                    title: 'أخرى',
                                    color: ColorUtils.withOpacity(AppColors.error, 0.7),
                                    radius: 40,
                                    titleStyle: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem('التسويق', '35%', AppColors.primary),
                              _buildLegendItem('الرواتب', '30%', AppColors.secondary),
                              _buildLegendItem('الصيانة', '20%', AppColors.accent),
                              _buildLegendItem('أخرى', '15%', AppColors.error),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
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
                      'المبيعات الشهرية',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              
                            ),
                            rightTitles: const AxisTitles(
                              
                            ),
                            topTitles: const AxisTitles(
                              
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو'];
                                  if (value.toInt() < 0 || value.toInt() >= months.length) {
                                    return const Text('');
                                  }
                                  return Text(
                                    months[value.toInt()],
                                    style: TextStyle(
                                      color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 3),
                                FlSpot(1, 4),
                                FlSpot(2, 3.5),
                                FlSpot(3, 5),
                                FlSpot(4, 4),
                                FlSpot(5, 6),
                              ],
                              isCurved: true,
                              color: AppColors.accent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
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
                      'المخزون',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInventoryCard(
                          'السيارات المتاحة',
                          '٢٥',
                          Icons.directions_car,
                          AppColors.success,
                        ),
                        _buildInventoryCard(
                          'قيد الحجز',
                          '٥',
                          Icons.pending,
                          AppColors.warning,
                        ),
                        _buildInventoryCard(
                          'تم البيع',
                          '١٥',
                          Icons.check_circle,
                          AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? growth}) {
    return custom_animations.AnimatedScale(
      onTap: () {
        _showMetricDetails(title, value, icon, color);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (growth != null) ...[
              const SizedBox(height: 4),
              Text(
                growth,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(color, 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            percentage,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(String title, String value, IconData icon, Color color) {
    return custom_animations.AnimatedScale(
      onTap: () {
        _showInventoryDetails(title, value, icon, color);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetricDetails(String title, String value, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDetailButton(
                  'تفاصيل',
                  Icons.info_outline,
                  () {
                    // TODO: Implement details view
                    Navigator.pop(context);
                  },
                ),
                _buildDetailButton(
                  'تصدير',
                  Icons.file_download,
                  () {
                    // TODO: Implement export functionality
                    Navigator.pop(context);
                  },
                ),
                _buildDetailButton(
                  'مشاركة',
                  Icons.share,
                  () {
                    // TODO: Implement share functionality
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInventoryDetails(String title, String value, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDetailButton(
                  'تفاصيل',
                  Icons.info_outline,
                  () {
                    // TODO: Implement details view
                    Navigator.pop(context);
                  },
                ),
                _buildDetailButton(
                  'تحديث',
                  Icons.refresh,
                  () {
                    // TODO: Implement refresh functionality
                    Navigator.pop(context);
                  },
                ),
                _buildDetailButton(
                  'تقرير',
                  Icons.assessment,
                  () {
                    // TODO: Implement report functionality
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailButton(String label, IconData icon, VoidCallback onPressed) {
    return custom_animations.AnimatedScale(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.accent, 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: ColorUtils.withOpacity(AppColors.textLight, 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 