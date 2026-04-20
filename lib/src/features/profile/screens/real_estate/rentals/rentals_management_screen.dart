import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/providers/auth_state.dart';
import '../../../providers/real_estate/rental_provider.dart';
import '../../../models/real_estate/rental_model.dart';
import '../../../../properties/models/property_model.dart';
import '../../../services/real_estate/export_service.dart';
import '../widgets/rentals/rental_card.dart';
import '../widgets/rentals/rental_stats_widget.dart';
import 'add_rental_screen.dart';
import '../dialogs/rentals/edit_rental_dialog.dart';
import '../dialogs/rentals/renew_rental_dialog.dart';
import 'rental_details_screen.dart';

/// شاشة إدارة عقود الإيجار
///
/// تعرض قائمة بعقود الإيجار مع إمكانية CRUD
/// يتبع الثيم الموحد للتطبيق
class RentalsManagementScreen extends StatefulWidget {
  const RentalsManagementScreen({super.key});

  @override
  State<RentalsManagementScreen> createState() => _RentalsManagementScreenState();
}

class _RentalsManagementScreenState extends State<RentalsManagementScreen> {
  RentalStatus? _selectedFilter;
  RentalType? _selectedRentalTypeFilter; // ✅ فلترة حسب نوع الإيجار
  String _searchQuery = ''; // ✅ البحث
  String _sortBy = 'newest'; // ✅ الترتيب: newest, oldest, endDate, monthlyRent
  final RealEstateExportService _exportService = RealEstateExportService();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RentalProvider>().loadRentals();
    });
  }

  /// ✅ فلترة وترتيب العقود
  List<RentalModel> _getFilteredRentals(List<RentalModel> rentals) {
    // ✅ إنشاء نسخة قابلة للتعديل من القائمة (لأن rentals هي unmodifiable)
    var filtered = List<RentalModel>.from(rentals);

    // ✅ فلترة حسب الحالة
    if (_selectedFilter != null) {
      filtered = filtered.where((r) => r.status == _selectedFilter!).toList();
    }

    // ✅ فلترة حسب نوع الإيجار
    if (_selectedRentalTypeFilter != null) {
      filtered = filtered.where((r) => r.rentalType == _selectedRentalTypeFilter!).toList();
    }

    // ✅ البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.propertyTitle.toLowerCase().contains(query) ||
               r.customerName.toLowerCase().contains(query) ||
               (r.contractNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // ✅ الترتيب
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'endDate':
        filtered.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case 'monthlyRent':
        filtered.sort((a, b) => b.monthlyRent.compareTo(a.monthlyRent));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: colorScheme.primary.withValues(alpha: 0.3),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.home_work,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'إدارة عقود الإيجار',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // ✅ التصدير
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : () => _showExportDialog(context),
            tooltip: 'تصدير',
          ),
          // ✅ البحث
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.search),
                if (_searchQuery.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showSearchDialog(context),
            tooltip: 'بحث',
          ),
          // ✅ الترتيب
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
            tooltip: 'ترتيب',
          ),
          // ✅ الفلترة
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedFilter != null || _selectedRentalTypeFilter != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'فلترة',
          ),
        ],
      ),
      body: Consumer<RentalProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.rentals.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            );
          }

          if (provider.error != null && provider.rentals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.loadRentals(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredRentals = _getFilteredRentals(provider.rentals);

          // ✅ عرض عدد النتائج والفلاتر النشطة
          final hasActiveFilters = _selectedFilter != null || 
                                   _selectedRentalTypeFilter != null || 
                                   _searchQuery.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () => provider.loadRentals(),
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // ✅ إحصائيات
                if (provider.rentals.isNotEmpty)
                  SliverToBoxAdapter(
                    child: RentalStatsWidget(rentals: provider.rentals),
                  ),
                // ✅ معلومات الفلاتر النشطة
                if (hasActiveFilters)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt, 
                            color: AppColors.primary, 
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${filteredRentals.length} من ${provider.rentals.length} عقد',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFilter = null;
                                _selectedRentalTypeFilter = null;
                                _searchQuery = '';
                              });
                            },
                            child: const Text('مسح الفلاتر'),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ✅ قائمة العقود
                if (filteredRentals.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasActiveFilters
                                ? 'لا توجد نتائج للبحث'
                                : _selectedFilter == null
                                    ? 'لا توجد عقود إيجار'
                                    : 'لا توجد عقود بهذه الحالة',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasActiveFilters
                                ? 'جرب تغيير معايير البحث أو الفلترة'
                                : 'اضغط على زر الإضافة لإضافة عقد إيجار جديد',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final rental = filteredRentals[index];
                        return RentalCard(
                          rental: rental,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RentalDetailsScreen(rentalId: rental.id),
                              ),
                            );
                          },
                          onEdit: () {
                            EditRentalDialog.show(context, rental);
                          },
                          onDelete: () => _confirmDelete(context, provider, rental),
                          onRenew: () {
                            RenewRentalDialog.show(context, rental);
                          },
                        );
                      },
                      childCount: filteredRentals.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // ✅ الانتقال إلى صفحة إضافة العقد وانتظار النتيجة
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRentalScreen(),
            ),
          );
          
          // ✅ إذا تمت الإضافة بنجاح، إعادة تحميل العقود
          if (result == true && mounted) {
            context.read<RentalProvider>().loadRentals();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عقد إيجار'),
      ),
    );
  }

  /// ✅ Dialog البحث
  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController(text: _searchQuery);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بحث في العقود'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'ابحث بالعقار، المستأجر، أو رقم العقد',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('مسح'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = searchController.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  /// ✅ Dialog الترتيب
  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ترتيب العقود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('الأحدث أولاً'),
              value: 'newest',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأقدم أولاً'),
              value: 'oldest',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأقرب للانتهاء'),
              value: 'endDate',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأعلى سعراً'),
              value: 'monthlyRent',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Dialog الفلترة المتقدمة
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة العقود'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ فلترة حسب الحالة
              const Text(
                'حالة العقد',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              RadioListTile<RentalStatus?>(
                title: const Text('الكل'),
                value: null,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() => _selectedFilter = value);
                },
              ),
              ...RentalStatus.values.map((status) => RadioListTile<RentalStatus?>(
                title: Text(status.arabicName),
                value: status,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() => _selectedFilter = value);
                },
              )),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // ✅ فلترة حسب نوع الإيجار
              const Text(
                'نوع الإيجار',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              RadioListTile<RentalType?>(
                title: const Text('الكل'),
                value: null,
                groupValue: _selectedRentalTypeFilter,
                onChanged: (value) {
                  setState(() => _selectedRentalTypeFilter = value);
                },
              ),
              RadioListTile<RentalType?>(
                title: const Text('سكني'),
                value: RentalType.residential,
                groupValue: _selectedRentalTypeFilter,
                onChanged: (value) {
                  setState(() => _selectedRentalTypeFilter = value);
                },
              ),
              RadioListTile<RentalType?>(
                title: const Text('تجاري'),
                value: RentalType.commercial,
                groupValue: _selectedRentalTypeFilter,
                onChanged: (value) {
                  setState(() => _selectedRentalTypeFilter = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilter = null;
                _selectedRentalTypeFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('مسح الفلاتر'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  /// ✅ Dialog التصدير
  void _showExportDialog(BuildContext context) {
    final provider = context.read<RentalProvider>();
    final filteredRentals = _getFilteredRentals(provider.rentals);
    
    if (filteredRentals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد عقود للتصدير'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text(
          'تصدير تقرير العقود',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سيتم تصدير ${filteredRentals.length} عقد',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _buildExportButton(
              context,
              'تصدير PDF',
              Icons.picture_as_pdf,
              AppColors.error,
              () async {
                Navigator.pop(context);
                await _exportToPDF(context, filteredRentals);
              },
            ),
            const SizedBox(height: 16),
            _buildExportButton(
              context,
              'تصدير Excel',
              Icons.table_chart,
              AppColors.success,
              () async {
                Navigator.pop(context);
                await _exportToExcel(context, filteredRentals);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: _isExporting ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
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

  Future<void> _exportToPDF(BuildContext context, List<RentalModel> rentals) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final authState = context.read<AuthState>();
      final companyName = authState.user?.name ?? 'غير معروف';

      final filePath = await _exportService.exportRentalsToPDF(
        rentals: rentals,
        companyName: companyName,
        startDate: null,
        endDate: null,
      );

      if (!mounted) return;
      
      await _exportService.shareFile(filePath, text: 'تقرير عقود الإيجار', context: context);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في التصدير: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportToExcel(BuildContext context, List<RentalModel> rentals) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final authState = context.read<AuthState>();
      final companyName = authState.user?.name ?? 'غير معروف';

      final filePath = await _exportService.exportRentalsToExcel(
        rentals: rentals,
        companyName: companyName,
        startDate: null,
        endDate: null,
      );

      if (!mounted) return;
      
      await _exportService.shareFile(filePath, text: 'تقرير عقود الإيجار', context: context);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في التصدير: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _confirmDelete(BuildContext context, RentalProvider provider, RentalModel rental) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف عقد الإيجار "${rental.propertyTitle}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deleteRental(rental.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف عقد الإيجار بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
