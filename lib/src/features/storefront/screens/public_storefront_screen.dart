import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../cars/models/car_model.dart';
import '../../properties/models/property_model.dart';
import '../models/storefront_public_listings.dart';
import '../models/tenant_status.dart';
import '../models/tenant_type.dart';
import '../navigation/storefront_routes.dart';
import '../services/tenant_listings_service.dart';
import '../services/tenant_service.dart';
import '../widgets/storefront_listing_tile.dart';
import '../widgets/storefront_public_header.dart';
import '../widgets/storefront_public_projects_section.dart';
import '../widgets/storefront_qr_sheet.dart';
import '../widgets/storefront_video_tile.dart';
import 'storefront_not_found_screen.dart';

/// واجهة الزائر `/store/{slug}` — S2.
///
/// PR-027: lightweight tenant revalidation on resume / navigation return /
/// sensitive actions only (no permanent listeners, polling, or AuthState rewrite).
class PublicStorefrontScreen extends StatefulWidget {
  const PublicStorefrontScreen({super.key, required this.slug});

  final String slug;

  @override
  State<PublicStorefrontScreen> createState() => _PublicStorefrontScreenState();
}

class _PublicStorefrontScreenState extends State<PublicStorefrontScreen>
    with WidgetsBindingObserver {
  /// MEP FLAG `TENANT_REVALIDATE` — disable with `--dart-define=TENANT_REVALIDATE=false`.
  static const bool _tenantRevalidate =
      bool.fromEnvironment('TENANT_REVALIDATE', defaultValue: true);

  final TenantService _tenants = TenantService();
  final TenantListingsService _listings = TenantListingsService();

  Future<StorefrontPublicListings?>? _cached;

  /// Set when a light revalidate finds the tenant no longer public.
  bool _forceSuspended = false;

  /// Tracks [ModalRoute.isCurrent] to revalidate when returning from a pushed route.
  bool _routeWasCurrent = true;

  bool _revalidating = false;

  Future<StorefrontPublicListings?> _load() async {
    final tenant = await _tenants.getBySlug(widget.slug);
    if (tenant == null) return null;
    if (tenant.status == TenantStatus.suspended) {
      throw _SuspendedStorefront();
    }
    if (!tenant.status.isPublicVisible) return null;
    return _listings.loadPublicListings(tenant);
  }

  void _reload() {
    setState(() {
      _forceSuspended = false;
      _cached = _load();
    });
  }

  /// Light status check only — does not reload listings when still active.
  Future<bool> _revalidateTenantStatus() async {
    if (!_tenantRevalidate || !mounted) return !_forceSuspended;
    if (_revalidating) return !_forceSuspended;
    _revalidating = true;
    try {
      final tenant = await _tenants.getBySlug(widget.slug);
      if (!mounted) return false;

      final ok = tenant != null && tenant.status.isPublicVisible;
      if (!ok) {
        if (!_forceSuspended) {
          setState(() => _forceSuspended = true);
        }
        return false;
      }

      if (_forceSuspended) {
        setState(() {
          _forceSuspended = false;
          _cached = _load();
        });
      }
      return true;
    } catch (_) {
      // Soft-fail: do not evict on transient network errors.
      return !_forceSuspended;
    } finally {
      _revalidating = false;
    }
  }

  Future<void> _runSensitive(VoidCallback action) async {
    final ok = await _revalidateTenantStatus();
    if (!ok || !mounted) return;
    action();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cached = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_revalidateTenantStatus());
    }
  }

  @override
  void didUpdateWidget(PublicStorefrontScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _reload();
    }
  }

  void _maybeRevalidateOnRouteReturn(BuildContext context) {
    if (!_tenantRevalidate) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent && !_routeWasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_revalidateTenantStatus());
      });
    }
    _routeWasCurrent = isCurrent;
  }

  Widget _suspendedScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('المعرض الرقمي')),
      body: const Center(
        child: Text('هذا المعرض غير متاح حالياً.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _maybeRevalidateOnRouteReturn(context);

    if (_forceSuspended) {
      return _suspendedScaffold();
    }

    return FutureBuilder<StorefrontPublicListings?>(
      future: _cached,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          if (snapshot.error is _SuspendedStorefront) {
            return _suspendedScaffold();
          }
          return Scaffold(
            appBar: AppBar(title: const Text('المعرض الرقمي')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('تعذر تحميل المعرض'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        final listings = snapshot.data;
        if (listings == null) {
          return StorefrontNotFoundScreen(slug: widget.slug);
        }

        return _StorefrontScaffold(
          listings: listings,
          onRefresh: () async {
            _reload();
            await _cached;
          },
          onTabNavigation: () => unawaited(_revalidateTenantStatus()),
          onSensitiveAction: _runSensitive,
        );
      },
    );
  }
}

class _SuspendedStorefront implements Exception {}

class _StorefrontScaffold extends StatefulWidget {
  const _StorefrontScaffold({
    required this.listings,
    required this.onRefresh,
    required this.onTabNavigation,
    required this.onSensitiveAction,
  });

  final StorefrontPublicListings listings;
  final Future<void> Function() onRefresh;
  final VoidCallback onTabNavigation;
  final Future<void> Function(VoidCallback action) onSensitiveAction;

  @override
  State<_StorefrontScaffold> createState() => _StorefrontScaffoldState();
}

class _StorefrontScaffoldState extends State<_StorefrontScaffold>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  static int _computeTabCount(StorefrontPublicListings listings) {
    final tenant = listings.tenant;
    var n = 1; // overview
    if (tenant.type == TenantType.carDealer) n++;
    if (tenant.type == TenantType.realEstateCompany) {
      if (AppConfig.enableCinematicProjects) n++;
      n++;
    }
    if (listings.hasVideos) n++;
    return n;
  }

  @override
  void initState() {
    super.initState();
    _attachTabControllerIfNeeded(_computeTabCount(widget.listings));
  }

  @override
  void didUpdateWidget(covariant _StorefrontScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _computeTabCount(widget.listings);
    if (_tabController == null || _tabController!.length != next) {
      _attachTabControllerIfNeeded(next);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _attachTabControllerIfNeeded(int length) {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabController = null;
    if (length <= 1) return;
    _tabController = TabController(length: length, vsync: this);
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final c = _tabController;
    if (c == null || c.indexIsChanging) return;
    widget.onTabNavigation();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.listings.tenant;
    final tabs = <Tab>[];
    final views = <Widget>[];

    tabs.add(const Tab(text: 'نظرة عامة'));
    views.add(
      _OverviewTab(
        listings: widget.listings,
        onRefresh: widget.onRefresh,
        onSensitiveAction: widget.onSensitiveAction,
      ),
    );

    if (tenant.type == TenantType.carDealer) {
      tabs.add(Tab(text: 'السيارات (${widget.listings.cars.length})'));
      views.add(_CarsTab(cars: widget.listings.cars));
    }

    if (tenant.type == TenantType.realEstateCompany) {
      if (AppConfig.enableCinematicProjects) {
        tabs.add(const Tab(text: 'مشاريع'));
        views.add(StorefrontPublicProjectsTab(tenant: tenant));
      }
      tabs.add(Tab(text: 'العقارات (${widget.listings.properties.length})'));
      views.add(_PropertiesTab(properties: widget.listings.properties));
    }

    if (widget.listings.hasVideos) {
      tabs.add(Tab(text: 'فيديو (${widget.listings.videos.length})'));
      views.add(StorefrontVideoGrid(videos: widget.listings.videos));
    }

    if (tabs.length == 1) {
      return Scaffold(
        appBar: AppBar(title: Text(tenant.displayNameAr)),
        body: views.first,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant.displayNameAr),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: tabs.length > 3,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: views,
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.listings,
    required this.onRefresh,
    required this.onSensitiveAction,
  });

  final StorefrontPublicListings listings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(VoidCallback action) onSensitiveAction;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          StorefrontPublicHeader(tenant: listings.tenant),
          if (listings.tenant.type == TenantType.carDealer &&
              (AppConfig.enableStorefrontVisit ||
                  AppConfig.enableVirtualShowroomWalk))
            _GatedServicesRow(
              slug: listings.tenant.slug,
              displayNameAr: listings.tenant.displayNameAr,
              onSensitiveAction: onSensitiveAction,
            ),
          ..._overviewSections(listings),
        ],
      ),
    );
  }
}

/// Local gated services row — revalidates tenant before visit / walk / QR.
class _GatedServicesRow extends StatelessWidget {
  const _GatedServicesRow({
    required this.slug,
    required this.displayNameAr,
    required this.onSensitiveAction,
  });

  final String slug;
  final String displayNameAr;
  final Future<void> Function(VoidCallback action) onSensitiveAction;

  @override
  Widget build(BuildContext context) {
    final cards = <_GatedServiceCardData>[
      if (AppConfig.enableStorefrontVisit)
        _GatedServiceCardData(
          icon: Icons.movie_filter_outlined,
          title: 'المعرض السينمائي',
          subtitle: 'Hero + Ring',
          color: const Color(0xFF7B61FF),
          onTap: () => onSensitiveAction(
            () => Navigator.pushNamed(context, StorefrontRoutes.visit(slug)),
          ),
        ),
      if (AppConfig.enableVirtualShowroomWalk)
        _GatedServiceCardData(
          icon: Icons.panorama_photosphere_outlined,
          title: 'زيارة المعرض',
          subtitle: 'جولة 360°',
          color: const Color(0xFFC4A35A),
          onTap: () => onSensitiveAction(
            () => Navigator.pushNamed(context, StorefrontRoutes.walk(slug)),
          ),
        ),
      _GatedServiceCardData(
        icon: Icons.qr_code_2_outlined,
        title: 'QR Code',
        subtitle: 'مشاركة',
        color: AppColors.textSecondary,
        onTap: () => onSensitiveAction(
          () => showStorefrontQrSheet(
            context,
            slug: slug,
            displayNameAr: displayNameAr,
          ),
        ),
      ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'خدمات المعرض',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _GatedServiceCard(data: cards[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GatedServiceCardData {
  const _GatedServiceCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _GatedServiceCard extends StatelessWidget {
  const _GatedServiceCard({required this.data});

  final _GatedServiceCardData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          data.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.color.withValues(alpha: 0.22)),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                data.color.withValues(alpha: 0.08),
                AppColors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, color: data.color, size: 28),
              const Spacer(),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _overviewSections(StorefrontPublicListings listings) {
  final children = <Widget>[];
  if (listings.isEmpty) {
    children.add(
      const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'لا توجد إعلانات منشورة حالياً.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
    return children;
  }
  if (listings.hasCars) {
    children.add(const _SectionTitle('أحدث السيارات'));
    for (final car in listings.cars.take(5)) {
      children.add(StorefrontCarTile(car: car));
    }
  }
  if (listings.hasProperties) {
    children.add(const _SectionTitle('أحدث العقارات'));
    for (final p in listings.properties.take(5)) {
      children.add(StorefrontPropertyTile(property: p));
    }
  }
  if (listings.hasVideos) {
    children.add(const _SectionTitle('فيديو'));
    children.add(StorefrontVideoStrip(videos: listings.videos));
  }
  return children;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _CarsTab extends StatelessWidget {
  const _CarsTab({required this.cars});

  final List<CarModel> cars;

  @override
  Widget build(BuildContext context) {
    if (cars.isEmpty) {
      return const Center(child: Text('لا توجد سيارات معروضة.'));
    }
    return ListView.builder(
      itemCount: cars.length,
      itemBuilder: (context, i) => StorefrontCarTile(car: cars[i]),
    );
  }
}

class _PropertiesTab extends StatelessWidget {
  const _PropertiesTab({required this.properties});

  final List<PropertyModel> properties;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const Center(child: Text('لا توجد عقارات معروضة.'));
    }
    return ListView.builder(
      itemCount: properties.length,
      itemBuilder: (context, i) =>
          StorefrontPropertyTile(property: properties[i]),
    );
  }
}
