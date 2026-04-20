import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../providers/real_estate/rental_provider.dart';
import '../../../providers/real_estate/rental_payment_provider.dart';
import '../../../models/real_estate/rental_model.dart';
import '../widgets/rentals/payment_schedule_widget.dart';
import '../dialogs/rentals/add_rental_payment_dialog.dart';
import 'rental_contract_viewer_screen.dart';

/// شاشة تفاصيل عقد الإيجار
///
/// تعرض تفاصيل عقد إيجار معين مع جدول الدفعات
/// يتبع الثيم الموحد للتطبيق
class RentalDetailsScreen extends StatefulWidget {
  final String rentalId;

  const RentalDetailsScreen({
    super.key,
    required this.rentalId,
  });

  @override
  State<RentalDetailsScreen> createState() => _RentalDetailsScreenState();
}

class _RentalDetailsScreenState extends State<RentalDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RentalPaymentProvider>().loadPayments(widget.rentalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final currencyFormat = NumberFormat('#,###', 'ar');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        title: const Text('تفاصيل عقد الإيجار'),
      ),
      body: Consumer2<RentalProvider, RentalPaymentProvider>(
        builder: (context, rentalProvider, paymentProvider, child) {
          // ✅ تحميل العقود إذا لم تكن محملة
          if (rentalProvider.rentals.isEmpty && !rentalProvider.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              rentalProvider.loadRentals();
            });
          }

          final rental = rentalProvider.getRentalById(widget.rentalId);
          
          if (rental == null) {
            return Center(
              child: rentalProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'عقد الإيجار غير موجود',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => rentalProvider.loadRentals(),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ معلومات العقد
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rental.propertyTitle,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rental.customerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: ColorUtils.withOpacity(
                                _getStatusColor(rental.status),
                                0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ColorUtils.withOpacity(
                                  _getStatusColor(rental.status),
                                  0.35,
                                ),
                              ),
                            ),
                            child: Text(
                              rental.status.arabicName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(rental.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'نوع الإيجار',
                        rental.rentalType.arabicName,
                        Icons.category,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'الإيجار الشهري',
                        '${currencyFormat.format(rental.monthlyRent)} ريال',
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'تاريخ البداية',
                        dateFormat.format(rental.startDate),
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'تاريخ النهاية',
                        dateFormat.format(rental.endDate),
                        Icons.event,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'مدة العقد',
                        '${rental.contractDurationMonths} شهر',
                        Icons.schedule,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'الضمان',
                        '${currencyFormat.format(rental.deposit)} ريال',
                        Icons.security,
                      ),
                      if (rental.contractNumber != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'رقم العقد',
                          rental.contractNumber!,
                          Icons.numbers,
                        ),
                      ],
                      // ✅ زر عرض ملف العقد
                      if (rental.contractPdfUrl != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // ✅ استخراج اسم الملف من URL
                              String? fileName;
                              try {
                                final uri = Uri.parse(rental.contractPdfUrl!);
                                final pathSegments = uri.pathSegments;
                                if (pathSegments.isNotEmpty) {
                                  fileName = pathSegments.last;
                                  if (fileName.contains('?')) {
                                    fileName = fileName.split('?').first;
                                  }
                                }
                              } catch (e) {
                                fileName = 'عقد_الإيجار.pdf';
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RentalContractViewerScreen(
                                    contractUrl: rental.contractPdfUrl!,
                                    rentalTitle: rental.propertyTitle,
                                    fileName: fileName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('عرض ملف العقد'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ✅ جدول الدفعات
                PaymentScheduleWidget(payments: paymentProvider.payments),
                const SizedBox(height: 80), // مساحة للـ FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<RentalProvider>(
        builder: (context, provider, child) {
          final rental = provider.getRentalById(widget.rentalId);
          if (rental == null) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => AddRentalPaymentDialog.show(
              context,
              rentalId: widget.rentalId,
              amount: rental.monthlyRent,
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.payment),
            label: const Text('تسجيل دفعة'),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(RentalStatus status) {
    switch (status) {
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
}
