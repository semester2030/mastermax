import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/real_estate/branches_provider.dart';
import '../../models/real_estate/branch_model.dart';
import 'dialogs/add_branch_dialog.dart';
import 'dialogs/edit_branch_dialog.dart';

/// شاشة إدارة الفروع
///
/// تعرض قائمة بالفروع مع إمكانية CRUD
/// يتبع الثيم الموحد للتطبيق
class BranchesManagementScreen extends StatefulWidget {
  const BranchesManagementScreen({super.key});

  @override
  State<BranchesManagementScreen> createState() => _BranchesManagementScreenState();
}

class _BranchesManagementScreenState extends State<BranchesManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchesProvider>().loadBranches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
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
                Icons.store,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'إدارة الفروع',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<BranchesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.branches.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            );
          }

          if (provider.error != null && provider.branches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('حدث خطأ', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(provider.error!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadBranches(),
                      style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.branches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store, size: 64, color: colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('لا توجد فروع بعد', style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('عند إضافة فروع ستظهر هنا.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => AddBranchDialog.show(context),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة فرع'),
                      style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadBranches(),
            color: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            strokeWidth: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.branches.length,
              itemBuilder: (context, index) {
                final branch = provider.branches[index];
                return _buildBranchCard(context, branch, provider, colorScheme, textTheme);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddBranchDialog.show(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('إضافة فرع'),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildBranchCard(BuildContext context, BranchModel branch, BranchesProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colorScheme.primaryContainer, width: 1)),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primaryContainer,
          highlightColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.store, color: colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(branch.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: branch.isActive ? AppColors.success.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(branch.isActive ? 'نشط' : 'غير نشط', style: textTheme.bodySmall?.copyWith(color: branch.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.location_on, size: 16, color: colorScheme.onSurfaceVariant), const SizedBox(width: 4), Expanded(child: Text(branch.address, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis))]),
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.phone, size: 16, color: colorScheme.onSurfaceVariant), const SizedBox(width: 4), Text(branch.phone, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant))]),
                      if (branch.managerName != null && branch.managerName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [Icon(Icons.person, size: 16, color: colorScheme.primary), const SizedBox(width: 4), Text('المدير: ${branch.managerName}', style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w500))]),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20), const SizedBox(width: 8), const Text('تعديل')])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [Icon(branch.isActive ? Icons.block : Icons.check_circle, color: colorScheme.primary, size: 20), const SizedBox(width: 8), Text(branch.isActive ? 'تعطيل' : 'تفعيل')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: AppColors.error, size: 20), const SizedBox(width: 8), const Text('حذف', style: TextStyle(color: AppColors.error))])),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      EditBranchDialog.show(context, branch);
                    } else if (value == 'toggle') {
                      await provider.updateBranch(branch.copyWith(isActive: !branch.isActive));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(branch.isActive ? 'تم تعطيل الفرع' : 'تم تفعيل الفرع'), backgroundColor: AppColors.success));
                      }
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('تأكيد الحذف'), content: Text('هل أنت متأكد من حذف الفرع "${branch.name}"؟'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('حذف'))]));
                      if (confirmed == true && mounted) {
                        try {
                          await provider.deleteBranch(branch.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم حذف الفرع بنجاح'), backgroundColor: AppColors.success));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: AppColors.error));
                          }
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
