import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/time/riyadh_calendar.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/platform_analytics_service.dart';

enum _ChartMode {
  last14Days,
  last30Days,
  weeks12,
  yearMonths,
  monthDays,
}

/// إحصائيات المنصة: إجمالي العقارات والسيارات، مشاهدات فيديو اليوم (السعودية)، ومخطط زمني.
class PlatformAnalyticsScreen extends StatefulWidget {
  const PlatformAnalyticsScreen({super.key});

  @override
  State<PlatformAnalyticsScreen> createState() => _PlatformAnalyticsScreenState();
}

class _PlatformAnalyticsScreenState extends State<PlatformAnalyticsScreen> {
  final PlatformAnalyticsService _svc = PlatformAnalyticsService();

  bool _loading = true;
  bool _chartBusy = false;
  String? _error;
  PlatformOverviewSnapshot? _overview;

  _ChartMode _mode = _ChartMode.last30Days;
  int _chartYear = RiyadhCalendar.nowRiyadhWallClock().year;
  int _chartMonth = RiyadhCalendar.nowRiyadhWallClock().month;

  List<DailyViewPoint> _dailySeries = [];
  List<MonthlyViewPoint> _monthlySeries = [];
  List<WeeklyViewPoint> _weeklySeries = [];

  DateTime? _pickedDay;
  int _pickedDayViews = 0;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _svc.loadOverview();
      await _loadChartData();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadChartData() async {
    if (mounted) setState(() => _chartBusy = true);
    try {
      final wall = RiyadhCalendar.nowRiyadhWallClock();
      final todayKey = RiyadhCalendar.todayDateKey();

      switch (_mode) {
        case _ChartMode.last14Days:
          final start = wall.subtract(const Duration(days: 13));
          final from = RiyadhCalendar.dateKeyFromWall(start);
          _dailySeries = await _svc.fetchDailySeries(from, todayKey);
          _monthlySeries = [];
          _weeklySeries = [];
          break;
        case _ChartMode.last30Days:
          final start = wall.subtract(const Duration(days: 29));
          final from = RiyadhCalendar.dateKeyFromWall(start);
          _dailySeries = await _svc.fetchDailySeries(from, todayKey);
          _monthlySeries = [];
          _weeklySeries = [];
          break;
        case _ChartMode.weeks12:
          _weeklySeries = await _svc.aggregateWeeksEndingOn(todayKey, weekCount: 12);
          _dailySeries = [];
          _monthlySeries = [];
          break;
        case _ChartMode.yearMonths:
          _monthlySeries = await _svc.aggregateByMonthForYear(_chartYear);
          _dailySeries = [];
          _weeklySeries = [];
          break;
        case _ChartMode.monthDays:
          final last = RiyadhCalendar.daysInMonth(_chartYear, _chartMonth);
          final from =
              '${_chartYear.toString().padLeft(4, '0')}-${_chartMonth.toString().padLeft(2, '0')}-01';
          final to =
              '${_chartYear.toString().padLeft(4, '0')}-${_chartMonth.toString().padLeft(2, '0')}-${last.toString().padLeft(2, '0')}';
          _dailySeries = await _svc.fetchDailySeries(from, to);
          _monthlySeries = [];
          _weeklySeries = [];
          break;
      }
    } finally {
      if (mounted) setState(() => _chartBusy = false);
    }
  }

  Future<void> _pickSingleDay() async {
    final initial = _pickedDay ?? RiyadhCalendar.nowRiyadhWallClock();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.utc(2024),
      lastDate: RiyadhCalendar.nowRiyadhWallClock().add(const Duration(days: 1)),
      helpText: 'اختر اليوم',
    );
    if (d == null || !mounted) return;
    final key = RiyadhCalendar.dateKeyFromCalendarDate(d);
    final n = await _svc.fetchViewsForDateKey(key);
    if (!mounted) return;
    setState(() {
      _pickedDay = d;
      _pickedDayViews = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _reloadAll, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'إحصائيات المنصة والمشاهدات',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'تحديث',
                            onPressed: _reloadAll,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إجماليات فورية من Firestore. المشاهدات اليومية تُسجَّل منذ تفعيل التجميع اليومي (كل مشاهدة فيديو تزيد عداد اليوم بتوقيت السعودية).',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_overview != null) _buildKpiRow(_overview!),
                      const SizedBox(height: 24),
                      _buildModeSelector(),
                      const SizedBox(height: 12),
                      if (_mode == _ChartMode.yearMonths) _buildYearSelector(),
                      if (_mode == _ChartMode.monthDays) _buildMonthSelector(),
                      const SizedBox(height: 8),
                      _buildDayPickerRow(),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _chartTitle(),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 320,
                                child: _chartBusy
                                    ? const Center(
                                        child: CircularProgressIndicator(color: AppColors.primary),
                                      )
                                    : _buildChart(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _chartTitle() {
    switch (_mode) {
      case _ChartMode.last14Days:
        return 'مشاهدات الفيديو — آخر 14 يومًا';
      case _ChartMode.last30Days:
        return 'مشاهدات الفيديو — آخر 30 يومًا';
      case _ChartMode.weeks12:
        return 'مشاهدات الفيديو — 12 أسبوعًا (مجموع كل أسبوع)';
      case _ChartMode.yearMonths:
        return 'مشاهدات الفيديو — $_chartYear (إجمالي كل شهر)';
      case _ChartMode.monthDays:
        return 'مشاهدات الفيديو — ${RiyadhCalendar.monthArabicLabel(_chartYear, _chartMonth)} (يوم بيوم)';
    }
  }

  Widget _buildKpiRow(PlatformOverviewSnapshot o) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final n = w > 900 ? 3 : (w > 520 ? 2 : 1);
        final tileW = (w - (n - 1) * 12) / n;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiTile(
              width: tileW,
              icon: Icons.apartment_rounded,
              label: 'إجمالي العقارات',
              value: '${o.totalProperties}',
              color: AppColors.primary,
            ),
            _KpiTile(
              width: tileW,
              icon: Icons.directions_car_filled_rounded,
              label: 'إجمالي السيارات',
              value: '${o.totalCars}',
              color: AppColors.primaryDark,
            ),
            _KpiTile(
              width: tileW,
              icon: Icons.visibility_rounded,
              label: 'مشاهدات فيديو اليوم',
              value: '${o.todayVideoViews}',
              subtitle: 'اليوم: ${o.todayDateKey} (توقيت السعودية)',
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _modeChip('14 يومًا', _ChartMode.last14Days),
        _modeChip('30 يومًا', _ChartMode.last30Days),
        _modeChip('12 أسبوعًا', _ChartMode.weeks12),
        _modeChip('سنة / شهور', _ChartMode.yearMonths),
        _modeChip('شهر / أيام', _ChartMode.monthDays),
      ],
    );
  }

  Widget _modeChip(String label, _ChartMode m) {
    final sel = _mode == m;
    return FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) async {
        setState(() => _mode = m);
        await _loadChartData();
      },
    );
  }

  Widget _buildYearSelector() {
    final y = RiyadhCalendar.nowRiyadhWallClock().year;
    final years = [y - 1, y, y + 1];
    return Row(
      children: [
        const Text('السنة: ', style: TextStyle(color: AppColors.textSecondary)),
        DropdownButton<int>(
          value: _chartYear,
          items: years
              .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _chartYear = v);
            await _loadChartData();
          },
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        const Text('السنة: ', style: TextStyle(color: AppColors.textSecondary)),
        DropdownButton<int>(
          value: _chartYear,
          items: List.generate(
            5,
            (i) {
              final yy = RiyadhCalendar.nowRiyadhWallClock().year - 2 + i;
              return DropdownMenuItem(value: yy, child: Text('$yy'));
            },
          ),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _chartYear = v);
            await _loadChartData();
          },
        ),
        const SizedBox(width: 16),
        const Text('الشهر: ', style: TextStyle(color: AppColors.textSecondary)),
        DropdownButton<int>(
          value: _chartMonth,
          items: List.generate(
            12,
            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
          ),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _chartMonth = v);
            await _loadChartData();
          },
        ),
      ],
    );
  }

  Widget _buildDayPickerRow() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickSingleDay,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: const Text('يوم محدد'),
            ),
            const SizedBox(width: 16),
            if (_pickedDay != null)
              Text(
                'المشاهدات في ${RiyadhCalendar.dateKeyFromCalendarDate(_pickedDay!)}: $_pickedDayViews',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            else
              const Expanded(
                child: Text(
                  'اختر يومًا لمقارنة رقم المشاهدات مع الشهر الحالي في وضع «شهر / أيام».',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_mode == _ChartMode.weeks12) {
      return _WeeklyBarChart(points: _weeklySeries);
    }
    if (_mode == _ChartMode.yearMonths) {
      return _MonthlyBarChart(points: _monthlySeries);
    }
    return _DailyLineChart(points: _dailySeries);
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart({required this.points});

  final List<DailyViewPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('لا بيانات في هذه الفترة'));
    }
    final maxY = points.map((e) => e.views).fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.views.toDouble())).toList();
    final step = (points.length / 6).ceil().clamp(1, points.length);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (v) => FlLine(
            color: ColorUtils.withOpacity(AppColors.textSecondary, 0.12),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= points.length || i % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    RiyadhCalendar.shortArabicLabel(points[i].dateKey),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((t) {
                final i = t.x.toInt();
                if (i < 0 || i >= points.length) return null;
                return LineTooltipItem(
                  '${points[i].dateKey}\n${points[i].views} مشاهدة',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                );
              }).whereType<LineTooltipItem>().toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.8,
            isStrokeCapRound: true,
            dotData: FlDotData(show: points.length <= 18),
            belowBarData: BarAreaData(
              show: true,
              color: ColorUtils.withOpacity(AppColors.primary, 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.points});

  final List<MonthlyViewPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('لا بيانات'));
    final maxY = points.map((e) => e.views).fold<int>(1, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: ColorUtils.withOpacity(AppColors.textSecondary, 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= 12) return const SizedBox.shrink();
                return Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          12,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].views.toDouble(),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.points});

  final List<WeeklyViewPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('لا بيانات'));
    final rev = points.reversed.toList();
    final maxY = rev.map((e) => e.views).fold<int>(1, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: ColorUtils.withOpacity(AppColors.textSecondary, 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= rev.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    RiyadhCalendar.shortArabicLabel(rev[i].labelEnd),
                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          rev.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: rev[i].views.toDouble(),
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: AppColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
