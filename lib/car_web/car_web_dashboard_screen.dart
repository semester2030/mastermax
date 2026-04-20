import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../src/core/theme/app_colors.dart';
import '../src/features/auth/providers/auth_state.dart';
import '../src/features/cars/models/car_model.dart';
import '../src/features/cars/providers/car_provider.dart';
import '../src/features/profile/models/car_showroom/sale_model.dart';
import '../src/features/profile/providers/car_showroom/customers_provider.dart';
import '../src/features/profile/providers/car_showroom/sales_provider.dart';

/// لوحة تحكم ويب لمعرض السيارات — نفس منطق البيانات والثيم المستخدم في التطبيق
/// (تصفية `sellerId`، إحصائيات المركبات، المبيعات، صور السيارات).
class CarWebDashboardScreen extends StatefulWidget {
  const CarWebDashboardScreen({super.key});

  @override
  State<CarWebDashboardScreen> createState() => _CarWebDashboardScreenState();
}

class _CarWebDashboardScreenState extends State<CarWebDashboardScreen> {
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadAll());
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    await Future.wait<void>([
      context.read<CarProvider>().loadCars(),
      context.read<CustomersProvider>().loadCustomers(),
      context.read<SalesProvider>().loadSales(),
    ]);
  }

  void _navigate(BuildContext context, String route) {
    if (route == '/analytics') {
      final businessId = context.read<AuthState>().user?.id ?? '';
      if (businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح التقارير: معرّف المستخدم غير متوفر'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      Navigator.of(context).pushNamed(route, arguments: businessId);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  String _carImageUrl(CarModel car) {
    if (car.mainImage.isNotEmpty) return car.mainImage;
    if (car.images.isNotEmpty) return car.images.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: _reloadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Consumer4<AuthState, CarProvider, SalesProvider, CustomersProvider>(
          builder: (context, auth, carsProv, salesProv, custProv, _) {
            final uid = auth.user?.id;
            if (uid == null) {
              return Center(
                child: Text(
                  'يجب تسجيل الدخول',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            final myCars =
                carsProv.cars.where((c) => c.sellerId == uid).toList();
            final sales = salesProv.sales;
            final soldCarIds =
                sales.map((s) => s.carId).where((id) => id.isNotEmpty).toSet();
            final remainingCars = myCars
                .where((c) => !soldCarIds.contains(c.id))
                .toList();
            final soldStillInList =
                myCars.where((c) => soldCarIds.contains(c.id)).length;
            final inventoryValueRemaining = remainingCars.fold<double>(
              0,
              (s, c) => s + c.price,
            );
            final loading = carsProv.isLoading ||
                salesProv.isLoading ||
                custProv.isLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة المعلومات',
                  subtitle:
                      'بيانات حسابك فقط — متوافقة مع شاشة المركبات والمبيعات في التطبيق',
                ),
                const SizedBox(height: 16),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      color: colorScheme.primary,
                      backgroundColor: colorScheme.primaryContainer,
                    ),
                  ),
                _statsWrap(
                  context,
                  items: [
                    _StatItem(
                      title: 'إجمالي مركباتي',
                      value: loading ? '…' : '${myCars.length}',
                      icon: Icons.directions_car_filled,
                      color: colorScheme.primary,
                      tooltip: 'عدد سياراتك في القائمة الحالية (نشطة في الاستعلام)',
                    ),
                    _StatItem(
                      title: 'المعروضة (نشطة)',
                      value: loading
                          ? '…'
                          : '${myCars.where((c) => c.isActive).length}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      tooltip: 'مركباتك ذات العرض النشط',
                    ),
                    _StatItem(
                      title: 'متبقية للبيع',
                      value: loading
                          ? '…'
                          : '${remainingCars.length}',
                      icon: Icons.storefront_outlined,
                      color: colorScheme.primary,
                      tooltip:
                          'سياراتك غير المسجّل بيعها في سجل المبيعات (حسب معرّف السيارة)',
                    ),
                    _StatItem(
                      title: 'عمليات البيع',
                      value: loading ? '…' : '${sales.length}',
                      icon: Icons.receipt_long,
                      color: const Color(0xFF0891B2),
                      tooltip: 'عدد عمليات البيع المسجّلة لحسابك',
                    ),
                    _StatItem(
                      title: 'مباعة (في قائمتك)',
                      value: loading ? '…' : '$soldStillInList',
                      icon: Icons.sell_outlined,
                      color: colorScheme.primary,
                      tooltip:
                          'سياراتك الظاهرة الآن في القائمة ولها سجل بيع (قد يكون العدد أقل إذا أُزيلت السيارة من العرض النشط)',
                    ),
                    _StatItem(
                      title: 'قيمة المخزون المتبقي',
                      value: loading
                          ? '…'
                          : '${_numberFormat.format(inventoryValueRemaining)} ر.س',
                      icon: Icons.account_balance_wallet_outlined,
                      color: colorScheme.primary,
                      tooltip: 'مجموع أسعار المعروض المتبقي (غير المباع في السجل)',
                    ),
                    _StatItem(
                      title: 'إيرادات المبيعات',
                      value: loading
                          ? '…'
                          : '${_numberFormat.format(salesProv.totalSales)} ر.س',
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                      tooltip: 'مجموع أسعار البيع المسجّلة',
                    ),
                    _StatItem(
                      title: 'إجمالي الربح',
                      value: loading
                          ? '…'
                          : '${_numberFormat.format(salesProv.totalProfit)} ر.س',
                      icon: Icons.trending_up,
                      color: colorScheme.primary,
                      tooltip: 'مجموع الربح المسجّل في المبيعات',
                    ),
                    _StatItem(
                      title: 'العملاء',
                      value: loading ? '…' : '${custProv.customers.length}',
                      icon: Icons.people_outline,
                      color: AppColors.primaryDark,
                      tooltip: 'عملاء معرضك المسجّلون',
                    ),
                    _StatItem(
                      title: 'تحت الحجز',
                      value: loading ? '…' : '0',
                      icon: Icons.pending_actions_outlined,
                      color: colorScheme.primary,
                      tooltip: 'قريباً — نفس التطبيق',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _sectionHeader(
                  context,
                  icon: Icons.history,
                  title: 'أحدث المبيعات',
                  subtitle: 'آخر العمليات المسجّلة',
                ),
                const SizedBox(height: 12),
                _recentSalesCard(context, sales, loading),
                const SizedBox(height: 28),
                _sectionHeader(
                  context,
                  icon: Icons.directions_car,
                  title: 'مركباتك',
                  subtitle:
                      'صورة وسعر وسنة — اضغط للانتقال إلى إدارة المركبات والمبيعات',
                ),
                const SizedBox(height: 12),
                _vehiclesSection(context, myCars, soldCarIds, loading),
                const SizedBox(height: 28),
                _sectionHeader(
                  context,
                  icon: Icons.bolt,
                  title: 'اختصارات',
                  subtitle: null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ShortcutChip(
                      label: 'المركبات والمبيعات',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => _navigate(context, '/vehicles-crm'),
                    ),
                    _ShortcutChip(
                      label: 'إضافة سيارة',
                      icon: Icons.add_circle_outline,
                      onTap: () => _navigate(context, '/add-car'),
                    ),
                    _ShortcutChip(
                      label: 'التقارير والإحصائيات',
                      icon: Icons.analytics,
                      onTap: () => _navigate(context, '/analytics'),
                    ),
                    _ShortcutChip(
                      label: 'تصدير تقرير (من التطبيق)',
                      icon: Icons.table_chart,
                      onTap: () => _navigate(context, '/vehicles-crm'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statsWrap(BuildContext context, {required List<_StatItem> items}) {
    // يحدّ أقصى عرض لكل بطاقة حتى لا تصبح مربعات ضخمة على الشاشات العريضة
    // (سابقاً: حتى 5 أعمدة فقط → كل بطاقة تأخذ ~1/5 عرض الشاشة).
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.28,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _themedStatCard(context, items[i]),
    );
  }

  Widget _themedStatCard(BuildContext context, _StatItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: item.tooltip,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.primaryContainer,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                item.value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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

  Widget _recentSalesCard(
    BuildContext context,
    List<SaleModel> sales,
    bool loading,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sorted = List<SaleModel>.from(sales)
      ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
    final top = sorted.take(8).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : top.isEmpty
                ? Text(
                    'لا توجد مبيعات مسجّلة بعد. سجّل البيع من شاشة المركبات والمبيعات.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: top.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 8, color: colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.carTitle,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.customerName} · ${_numberFormat.format(s.salePrice)} ر.س · ${_dateFormat.format(s.saleDate)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
      ),
    );
  }

  Widget _vehiclesSection(
    BuildContext context,
    List<CarModel> myCars,
    Set<String> soldCarIds,
    bool loading,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (loading && myCars.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (myCars.isEmpty) {
      return Text(
        'لا توجد مركبات في القائمة. أضف سيارة أو تحقق من أن إعلاناتك «نشطة» (يستعلم النظام عن المركبات النشطة فقط).',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }

    final sorted = List<CarModel>.from(myCars)
      ..sort((a, b) {
        final as = soldCarIds.contains(a.id) ? 1 : 0;
        final bs = soldCarIds.contains(b.id) ? 1 : 0;
        if (as != bs) return as - bs;
        return b.createdAt.compareTo(a.createdAt);
      });

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = w > 1000
            ? 3
            : w > 640
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: cross == 1 ? 2.4 : 0.92,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final car = sorted[index];
            final sold = soldCarIds.contains(car.id);
            final url = _carImageUrl(car);
            return _VehicleTile(
              car: car,
              imageUrl: url,
              sold: sold,
              active: car.isActive,
              numberFormat: _numberFormat,
              onOpen: () => _navigate(context, '/vehicles-crm'),
            );
          },
        );
      },
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String tooltip;

  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.tooltip,
  });
}

class _VehicleTile extends StatelessWidget {
  final CarModel car;
  final String imageUrl;
  final bool sold;
  final bool active;
  final NumberFormat numberFormat;
  final VoidCallback onOpen;

  const _VehicleTile({
    required this.car,
    required this.imageUrl,
    required this.sold,
    required this.active,
    required this.numberFormat,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primaryContainer,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        splashColor: colorScheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(colorScheme),
                        )
                      : _placeholder(colorScheme),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 8,
                    end: 8,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (sold)
                          _chip(
                            'مباع',
                            AppColors.success,
                            colorScheme,
                          ),
                        if (!active)
                          _chip(
                            'موقوف',
                            AppColors.error,
                            colorScheme,
                          ),
                        if (active && !sold)
                          _chip(
                            'معروض',
                            colorScheme.primary,
                            colorScheme,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${car.brand} ${car.model} · ${car.year}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${numberFormat.format(car.price)} ر.س',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
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

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Icon(
        Icons.directions_car_filled,
        size: 48,
        color: colorScheme.primary,
      ),
    );
  }

  Widget _chip(String label, Color bg, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: bg == colorScheme.primary ? colorScheme.onPrimary : AppColors.white,
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
