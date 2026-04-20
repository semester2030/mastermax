import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/color_utils.dart';
import '../../../../models/real_estate/rental_model.dart';
import '../../rentals/rental_contract_viewer_screen.dart';

/// Widget لعرض بطاقة عقد إيجار
///
/// يعرض معلومات مختصرة عن عقد الإيجار بشكل منظم
/// يتبع الثيم الموحد للتطبيق
class RentalCard extends StatelessWidget {
  final RentalModel rental;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRenew; // ✅ تجديد العقد

  const RentalCard({
    super.key,
    required this.rental,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onRenew,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final currencyFormat = NumberFormat('#,###', 'ar');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ColorUtils.withOpacity(_getStatusColor(), 0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Header: العنوان والحالة
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rental.propertyTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // ✅ Badge للعقود القريبة من الانتهاء
                            if (rental.isNearExpiry && rental.status == RentalStatus.active)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rental.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColorUtils.withOpacity(_getStatusColor(), 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ColorUtils.withOpacity(_getStatusColor(), 0.35),
                      ),
                    ),
                    child: Text(
                      rental.status.arabicName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              // ✅ تنبيه للعقود القريبة من الانتهاء
              if (rental.isNearExpiry && rental.status == RentalStatus.active) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                        color: Colors.orange.shade700, 
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ينتهي قريباً (${rental.endDate.difference(DateTime.now()).inDays} يوم)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // ✅ معلومات الإيجار
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.attach_money,
                      label: 'الإيجار الشهري',
                      value: '${currencyFormat.format(rental.monthlyRent)} ريال',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.calendar_today,
                      label: 'تاريخ البداية',
                      value: dateFormat.format(rental.startDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.event,
                      label: 'تاريخ النهاية',
                      value: dateFormat.format(rental.endDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.category,
                      label: 'النوع',
                      value: rental.rentalType.arabicName,
                    ),
                  ),
                ],
              ),
              // ✅ Actions
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // ✅ عرض ملف PDF
                    if (rental.contractPdfUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => _openContractPdf(context, rental.contractPdfUrl!),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('عرض العقد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    // ✅ تجديد العقد (للعقود النشطة أو المنتهية)
                    if (onRenew != null && 
                        (rental.status == RentalStatus.active || 
                         rental.status == RentalStatus.expired))
                      OutlinedButton.icon(
                        onPressed: onRenew,
                        icon: const Icon(Icons.autorenew, size: 18),
                        label: const Text('تجديد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                        ),
                      ),
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('تعديل'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('حذف'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (rental.status) {
      case RentalStatus.active:
        return AppColors.success;
      case RentalStatus.expired:
        return AppColors.error;
      case RentalStatus.cancelled:
        return AppColors.textSecondary;
      case RentalStatus.renewed:
        return AppColors.primary;
    }
  }

  /// ✅ فتح ملف PDF/Word للعقد داخل التطبيق
  void _openContractPdf(BuildContext context, String pdfUrl) {
    // ✅ استخراج اسم الملف من URL
    String? fileName;
    try {
      final uri = Uri.parse(pdfUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        fileName = pathSegments.last;
        // إزالة query parameters من الاسم
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
      }
    } catch (e) {
      // إذا فشل استخراج الاسم، استخدم اسم افتراضي
      fileName = 'عقد_الإيجار.pdf';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalContractViewerScreen(
          contractUrl: pdfUrl,
          rentalTitle: rental.propertyTitle,
          fileName: fileName,
        ),
      ),
    );
  }
}
