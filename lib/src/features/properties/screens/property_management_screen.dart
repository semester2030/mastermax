import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/property_provider.dart';
import '../models/property_model.dart';
import '../../auth/providers/auth_state.dart';
import '../../auth/utils/listing_vertical_guard.dart';
import '../../../core/theme/app_colors.dart';
import 'add_property_screen.dart';

class PropertyManagementScreen extends StatefulWidget {
  const PropertyManagementScreen({super.key});

  @override
  State<PropertyManagementScreen> createState() => _PropertyManagementScreenState();
}

class _PropertyManagementScreenState extends State<PropertyManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthState>();
      final t = auth.user?.type ?? auth.userType;
      if (!ListingVerticalGuard.mayPublishProperties(
        t,
        isAdmin: auth.isAdmin,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ListingVerticalGuard.denialMessageForPropertyListing(t),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
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
    
    // ✅ PropertyProvider موجود في web_main.dart و main.dart
    return Consumer2<PropertyProvider, AuthState>(
      builder: (context, provider, authState, _) {
        final accountType = authState.user?.type ?? authState.userType;
        final canManageProperties = ListingVerticalGuard.mayPublishProperties(
          accountType,
          isAdmin: authState.isAdmin,
        );
        // ✅ تحميل البيانات عند أول بناء للشاشة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.properties.isEmpty && !provider.isLoading) {
            final ownerId = authState.user?.id;
            provider.loadProperties(ownerId: ownerId);
          }
        });
        
        return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.white, // ✅ استخدام الثيم الموحد
          elevation: 1,
          shadowColor: colorScheme.primary.withValues(alpha: 0.3),
          title: Text(
            'إدارة العقارات',
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary, // ✅ استخدام الثيم الموحد
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (canManageProperties)
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: AppColors.primary, // ✅ استخدام الثيم الموحد
                ),
                onPressed: () => _navigateToAddProperty(context),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary, // ✅ استخدام الثيم الموحد
            unselectedLabelColor: AppColors.textSecondary, // ✅ استخدام الثيم الموحد
            indicatorColor: AppColors.primary, // ✅ استخدام الثيم الموحد
            labelStyle: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: textTheme.titleMedium,
            tabs: const [
              Tab(text: 'جميع العقارات'),
              Tab(text: 'عروض البيع'),
              Tab(text: 'عروض الإيجار'),
            ],
          ),
        ),
        body: Consumer<PropertyProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadProperties(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // ✅ جميع العقارات
                _buildPropertiesList(
                  context,
                  provider.properties,
                  provider,
                  colorScheme,
                  textTheme,
                  null, // لا فلترة
                ),
                // ✅ عروض البيع (فقط المتاحة للبيع)
                _buildPropertiesList(
                  context,
                  provider.properties
                      .where((p) => p.offerType == OfferType.sale && p.status == PropertyStatus.available)
                      .toList(),
                  provider,
                  colorScheme,
                  textTheme,
                  OfferType.sale,
                ),
                // ✅ عروض الإيجار (فقط المتاحة للإيجار - قبل التأجير)
                _buildPropertiesList(
                  context,
                  provider.properties
                      .where((p) => p.offerType == OfferType.rent && p.status == PropertyStatus.available)
                      .toList(),
                  provider,
                  colorScheme,
                  textTheme,
                  OfferType.rent,
                ),
              ],
            );
          },
        ),
        );
      },
    );
  }

  Widget _buildPropertiesList(
    BuildContext context,
    List<PropertyModel> properties,
    PropertyProvider provider,
    ColorScheme colorScheme,
    TextTheme textTheme,
    OfferType? offerType, // نوع العرض المحدد (للرسائل)
  ) {
    if (properties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                offerType == OfferType.rent
                    ? Icons.home_work_outlined
                    : offerType == OfferType.sale
                        ? Icons.sell_outlined
                        : Icons.home_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                offerType == OfferType.rent
                    ? 'لا توجد عقارات معروضة للإيجار'
                    : offerType == OfferType.sale
                        ? 'لا توجد عقارات معروضة للبيع'
                        : 'لا توجد عقارات',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                offerType == OfferType.rent
                    ? 'سيتم عرض العقارات المعروضة للإيجار هنا\nيمكنك تعديلها قبل تحويلها إلى عقود إيجار'
                    : offerType == OfferType.sale
                        ? 'سيتم عرض العقارات المعروضة للبيع هنا'
                        : 'سيتم عرض العقارات هنا عند إضافة أول عقار',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authState = Provider.of<AuthState>(context, listen: false);
        final ownerId = authState.user?.id;
        await provider.loadProperties(ownerId: ownerId);
      },
      child: ListView.builder(
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return _buildPropertyCard(context, property, provider);
        },
      ),
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    PropertyModel property,
    PropertyProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: property.images.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: property.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.home,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                    // تحسين الأداء للصور الصغيرة
                    // ✅ إزالة memCacheWidth/memCacheHeight للحفاظ على الدقة الكاملة
                    // memCacheWidth: null,
                    // memCacheHeight: null,
                  ),
                )
              : Icon(
                  Icons.home,
                  size: 40,
                  color: colorScheme.primary,
                ),
        ),
        title: Text(
          property.title,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${property.price} ريال',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              property.address,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                // ✅ نوع العرض (بيع/إيجار)
                Container(
                  margin: const EdgeInsets.only(top: 4, left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: property.offerType == OfferType.rent
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    property.offerType.arabicName,
                    style: textTheme.bodySmall?.copyWith(
                      color: property.offerType == OfferType.rent
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // ✅ حالة العقار
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    property.status.arabicName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: colorScheme.onSurfaceVariant,
          ),
          onSelected: (value) => _handleMenuAction(
            context,
            value,
            property,
            provider,
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تعديل',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'حذف',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddProperty(BuildContext context) async {
    final auth = context.read<AuthState>();
    final t = auth.user?.type ?? auth.userType;
    if (!ListingVerticalGuard.mayPublishProperties(
      t,
      isAdmin: auth.isAdmin,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ListingVerticalGuard.denialMessageForPropertyListing(t),
          ),
        ),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );
    
    // ✅ إعادة تحميل القائمة بعد إضافة عقار جديد
    if (result != null && context.mounted) {
      await context.read<PropertyProvider>().loadProperties();
    }
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    PropertyModel property,
    PropertyProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    switch (action) {
      case 'edit':
        final auth = context.read<AuthState>();
        final t = auth.user?.type ?? auth.userType;
        if (!ListingVerticalGuard.mayPublishProperties(
          t,
          isAdmin: auth.isAdmin,
        )) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ListingVerticalGuard.denialMessageForPropertyListing(t),
              ),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddPropertyScreen(property: property),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'تأكيد الحذف',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف هذا العقار؟',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.deleteProperty(property.id);
                  Navigator.pop(context);
                },
                child: Text(
                  'حذف',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        );
        break;
    }
  }
} 