import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';
import '../../../src/core/utils/color_utils.dart';
import '../../services/geo_analytics_service.dart';
import '../../utils/audit_csv_download.dart';

enum _KindFilter {
  all,
  property,
  car,
  spotlightEstate,
  spotlightCar,
}

enum _DistrictSort { most, least, alpha }

enum _SellerSort { most, least, alpha }

String _csvCell(String? s) {
  if (s == null || s.isEmpty) return '';
  final t = s.replaceAll('"', '""');
  if (t.contains(',') || t.contains('\n') || t.contains('\r') || t.contains('"')) {
    return '"$t"';
  }
  return t;
}

/// تحليل جغرافي تفاعلي: مدينة، حي، نوع المحتوى، بائع، تجميعات وتصدير CSV.
class GeoAnalyticsScreen extends StatefulWidget {
  const GeoAnalyticsScreen({super.key});

  @override
  State<GeoAnalyticsScreen> createState() => _GeoAnalyticsScreenState();
}

class _GeoAnalyticsScreenState extends State<GeoAnalyticsScreen> with SingleTickerProviderStateMixin {
  final GeoAnalyticsService _svc = GeoAnalyticsService();
  late TabController _tabs;

  List<GeoListingRow> _all = [];
  bool _loading = true;
  String? _error;

  String? _city;
  String? _district;
  _KindFilter _kind = _KindFilter.all;
  final TextEditingController _seller = TextEditingController();
  String _sellerDebounced = '';
  _DistrictSort _distSort = _DistrictSort.most;
  _SellerSort _sellerSort = _SellerSort.most;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _seller.addListener(_onSellerChanged);
    _load();
  }

  void _onSellerChanged() {
    final v = _seller.text.trim();
    if (v == _sellerDebounced) return;
    setState(() => _sellerDebounced = v);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _seller.removeListener(_onSellerChanged);
    _seller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.loadDataset(limitPerCollection: 450);
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Iterable<GeoListingRow> get _filtered {
    return _all.where((r) {
      if (_city != null && _city!.isNotEmpty && r.city != _city) return false;
      if (_district != null && _district!.isNotEmpty && r.district != _district) return false;
      if (_sellerDebounced.isNotEmpty) {
        final q = _sellerDebounced.toLowerCase();
        if (!r.sellerName.toLowerCase().contains(q) && !r.sellerId.toLowerCase().contains(q)) {
          return false;
        }
      }
      switch (_kind) {
        case _KindFilter.all:
          break;
        case _KindFilter.property:
          if (r.category != GeoRowCategory.property) return false;
          break;
        case _KindFilter.car:
          if (r.category != GeoRowCategory.car) return false;
          break;
        case _KindFilter.spotlightEstate:
          if (r.category != GeoRowCategory.spotlightRealEstate) return false;
          break;
        case _KindFilter.spotlightCar:
          if (r.category != GeoRowCategory.spotlightCar) return false;
          break;
      }
      return true;
    });
  }

  List<String> get _cities {
    final s = _all.map((e) => e.city).toSet().toList()..sort();
    return s;
  }

  List<String> get _districtsForCity {
    if (_city == null || _city!.isEmpty) {
      final s = _all.map((e) => e.district).toSet().toList()..sort();
      return s;
    }
    final s = _all.where((e) => e.city == _city).map((e) => e.district).toSet().toList()..sort();
    return s;
  }

  List<DistrictRollup> get _districtRollups {
    var list = GeoAnalyticsService.rollupByDistrict(_filtered);
    switch (_distSort) {
      case _DistrictSort.most:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      case _DistrictSort.least:
        list.sort((a, b) => a.total.compareTo(b.total));
        break;
      case _DistrictSort.alpha:
        list.sort((a, b) {
          final c = a.city.compareTo(b.city);
          return c != 0 ? c : a.district.compareTo(b.district);
        });
        break;
    }
    return list;
  }

  List<SellerRollup> get _sellerRollups {
    var list = GeoAnalyticsService.rollupBySeller(_filtered);
    switch (_sellerSort) {
      case _SellerSort.most:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      case _SellerSort.least:
        list.sort((a, b) => a.total.compareTo(b.total));
        break;
      case _SellerSort.alpha:
        list.sort((a, b) => a.sellerName.compareTo(b.sellerName));
        break;
    }
    return list;
  }

  void _exportDetailsCsv() {
    final rows = _filtered.toList();
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
      [
        'id',
        'category',
        'city',
        'district',
        'sellerId',
        'sellerName',
        'viewsCount',
        'parseSource',
        'address',
      ].join(','),
    );
    for (final r in rows) {
      buf.writeln([
        _csvCell(r.id),
        _csvCell(r.kindLabel),
        _csvCell(r.city),
        _csvCell(r.district),
        _csvCell(r.sellerId),
        _csvCell(r.sellerName),
        '${r.viewsCount}',
        _csvCell(r.parseSource.name),
        _csvCell(r.rawAddress),
      ].join(','));
    }
    downloadAuditCsv(
      'geo_listings_${DateTime.now().millisecondsSinceEpoch}.csv',
      buf.toString(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تنزيل CSV (${rows.length} صف)')),
    );
  }

  void _exportDistrictsCsv() {
    final list = _districtRollups;
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
      'city,district,properties,cars,videoRealEstate,videoCar,total',
    );
    for (final r in list) {
      buf.writeln([
        _csvCell(r.city),
        _csvCell(r.district),
        '${r.properties}',
        '${r.cars}',
        '${r.spotlightRealEstate}',
        '${r.spotlightCar}',
        '${r.total}',
      ].join(','));
    }
    downloadAuditCsv(
      'geo_districts_${DateTime.now().millisecondsSinceEpoch}.csv',
      buf.toString(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تنزيل تجميع الأحياء (${list.length} صف)')),
    );
  }

  void _exportSellersCsv() {
    final list = _sellerRollups;
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
      'sellerId,sellerName,properties,cars,videoRealEstate,videoCar,total',
    );
    for (final r in list) {
      buf.writeln([
        _csvCell(r.sellerId),
        _csvCell(r.sellerName),
        '${r.properties}',
        '${r.cars}',
        '${r.spotlightRealEstate}',
        '${r.spotlightCar}',
        '${r.total}',
      ].join(','));
    }
    downloadAuditCsv(
      'geo_sellers_${DateTime.now().millisecondsSinceEpoch}.csv',
      buf.toString(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تنزيل تجميع البائعين (${list.length} صف)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    final dr = _districtRollups;
    final topDistrictMost = _distSort == _DistrictSort.most && dr.isNotEmpty ? dr.first : null;
    final leastWhenSortedMost = _distSort == _DistrictSort.most && dr.length > 1 ? dr.last : null;
    final topDistrictLeast = _distSort == _DistrictSort.least && dr.isNotEmpty ? dr.first : null;
    final topSellerMost = _sellerSort == _SellerSort.most && _sellerRollups.isNotEmpty ? _sellerRollups.first : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'التحليل الجغرافي (مدن وأحياء)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث البيانات'),
            ],
          ),
          Text(
            'عيّنة حتى 450 سجل لكل من: العقارات، السيارات، فيديوهات السبوتلايت. المدينة/الحي من الحقلين city/district إن وُجدا، وإلا من تحليل العنوان.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniStat(
                'صفوف بعد الفلتر',
                '${_filtered.length}',
                Icons.filter_alt_rounded,
              ),
              if (topDistrictMost != null)
                _miniStat(
                  'أكثر حي (بالفلتر)',
                  '${topDistrictMost.district} (${topDistrictMost.total})',
                  Icons.trending_up_rounded,
                ),
              if (leastWhenSortedMost != null)
                _miniStat(
                  'أقل حي (ضمن نفس الفلتر)',
                  '${leastWhenSortedMost.district} (${leastWhenSortedMost.total})',
                  Icons.trending_down_rounded,
                ),
              if (topDistrictLeast != null)
                _miniStat(
                  'أقل حي (ترتيب الأقل)',
                  '${topDistrictLeast.district} (${topDistrictLeast.total})',
                  Icons.vertical_align_bottom_rounded,
                ),
              if (topSellerMost != null)
                _miniStat(
                  'أكثر بائعاً',
                  '${topSellerMost.sellerName} (${topSellerMost.total})',
                  Icons.storefront_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('فلترة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth < 720) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _cityDropdown(),
                            const SizedBox(height: 10),
                            _districtDropdown(),
                            const SizedBox(height: 10),
                            _sellerField(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _cityDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _districtDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _sellerField()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('نوع المحتوى', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _kindChip('الكل', _KindFilter.all),
                      _kindChip('عقارات', _KindFilter.property),
                      _kindChip('سيارات', _KindFilter.car),
                      _kindChip('فيديو عقار', _KindFilter.spotlightEstate),
                      _kindChip('فيديو سيارة', _KindFilter.spotlightCar),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _city = null;
                            _district = null;
                            _kind = _KindFilter.all;
                            _seller.clear();
                            _sellerDebounced = '';
                          });
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('مسح الفلاتر'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportDetailsCsv,
                        icon: const Icon(Icons.table_rows_rounded, size: 18),
                        label: const Text('CSV تفصيلي'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportDistrictsCsv,
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('CSV أحياء'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportSellersCsv,
                        icon: const Icon(Icons.groups_rounded, size: 18),
                        label: const Text('CSV بائعون'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'تجميع الأحياء'),
              Tab(text: 'تجميع البائعين'),
              Tab(text: 'التفصيلي'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _districtTab(),
                _sellerTab(),
                _detailTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityDropdown() {
    return DropdownButtonFormField<String>(
      value: _city,
      decoration: const InputDecoration(
        labelText: 'المدينة',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('— الكل —')),
        ..._cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (v) => setState(() {
        _city = v;
        _district = null;
      }),
    );
  }

  Widget _districtDropdown() {
    return DropdownButtonFormField<String>(
      value: _district,
      decoration: const InputDecoration(
        labelText: 'الحي',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('— الكل —')),
        ..._districtsForCity.map((d) => DropdownMenuItem(value: d, child: Text(d))),
      ],
      onChanged: (v) => setState(() => _district = v),
    );
  }

  Widget _sellerField() {
    return TextField(
      controller: _seller,
      decoration: const InputDecoration(
        labelText: 'اسم البائع / الشركة أو المعرف',
        border: OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
  }

  Widget _kindChip(String label, _KindFilter v) {
    final sel = _kind == v;
    return FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => setState(() => _kind = v),
    );
  }

  Widget _districtTab() {
    final list = _districtRollups;
    final maxTotal = list.isEmpty ? 0 : list.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('ترتيب: ', style: TextStyle(color: AppColors.textSecondary)),
              ChoiceChip(
                label: const Text('الأكثر عروضاً'),
                selected: _distSort == _DistrictSort.most,
                onSelected: (_) => setState(() => _distSort = _DistrictSort.most),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('الأقل'),
                selected: _distSort == _DistrictSort.least,
                onSelected: (_) => setState(() => _distSort = _DistrictSort.least),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('أبجدي'),
                selected: _distSort == _DistrictSort.alpha,
                onSelected: (_) => setState(() => _distSort = _DistrictSort.alpha),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا توجد بيانات مطابقة'))
              : Scrollbar(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final r = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: ColorUtils.withOpacity(AppColors.primary, 0.1)),
                        ),
                        child: ExpansionTile(
                          title: Text('${r.city} — ${r.district}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('الإجمالي: ${r.total} (عقار ${r.properties} · سيارة ${r.cars} · فيديو عقار ${r.spotlightRealEstate} · فيديو سيارة ${r.spotlightCar})'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: LinearProgressIndicator(
                                value: maxTotal > 0 ? (r.total / maxTotal).clamp(0.0, 1.0) : null,
                                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sellerTab() {
    final list = _sellerRollups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('ترتيب: ', style: TextStyle(color: AppColors.textSecondary)),
              ChoiceChip(
                label: const Text('الأكثر إعلانات'),
                selected: _sellerSort == _SellerSort.most,
                onSelected: (_) => setState(() => _sellerSort = _SellerSort.most),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('الأقل'),
                selected: _sellerSort == _SellerSort.least,
                onSelected: (_) => setState(() => _sellerSort = _SellerSort.least),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('حسب الاسم'),
                selected: _sellerSort == _SellerSort.alpha,
                onSelected: (_) => setState(() => _sellerSort = _SellerSort.alpha),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا توجد بيانات مطابقة'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(r.sellerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'معرف: ${r.sellerId.isEmpty ? '—' : r.sellerId}\nإجمالي ${r.total} — عقار ${r.properties} · سيارة ${r.cars} · فيديو عقار ${r.spotlightRealEstate} · فيديو سيارة ${r.spotlightCar}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detailTab() {
    final list = _filtered.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('${list.length} صفاً — المصدر: explicitFields = حقول محفوظة؛ heuristic = من العنوان', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 0,
                      child: ListTile(
                        dense: true,
                        title: Text('${r.kindLabel} · ${r.city} / ${r.district}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          '${r.sellerName} (${r.sellerId})\n${r.rawAddress}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: r.viewsCount > 0 ? Text('${r.viewsCount} مشاهدة') : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
