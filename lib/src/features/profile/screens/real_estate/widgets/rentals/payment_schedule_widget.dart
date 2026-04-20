import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/color_utils.dart';
import '../../../../models/real_estate/rental_payment_model.dart';

/// Widget لعرض جدول دفعات الإيجار
///
/// يعرض جدول بجميع دفعات عقد الإيجار
/// يتبع الثيم الموحد للتطبيق
class PaymentScheduleWidget extends StatelessWidget {
  final List<RentalPaymentModel> payments;

  const PaymentScheduleWidget({
    super.key,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.payment_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد دفعات',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final currencyFormat = NumberFormat('#,###', 'ar');

    return Container(
      margin: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'جدول الدفعات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _buildPaymentItem(payment, dateFormat, currencyFormat);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
    RentalPaymentModel payment,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // alpha يجب 0–1؛ القيمة 26 كانت تُفسَّر خطأً فتصبح الخلفية معتمة بالكامل وتختفي الأيقونة
          color: ColorUtils.withOpacity(_getStatusColor(payment.status), 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getStatusIcon(payment.status),
          color: _getStatusColor(payment.status),
          size: 20,
        ),
      ),
      title: Text(
        'دفعة ${currencyFormat.format(payment.amount)} ريال',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'تاريخ الاستحقاق: ${dateFormat.format(payment.dueDate)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (payment.paidDate != null)
            Text(
              'تاريخ الدفع: ${dateFormat.format(payment.paidDate!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.success,
              ),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ColorUtils.withOpacity(_getStatusColor(payment.status), 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorUtils.withOpacity(_getStatusColor(payment.status), 0.35),
          ),
        ),
        child: Text(
          payment.status.arabicName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(payment.status),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.overdue:
        return AppColors.error;
      case PaymentStatus.due:
        return Colors.orange;
      case PaymentStatus.pending:
        return AppColors.primary;
    }
  }

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Icons.check_circle;
      case PaymentStatus.overdue:
        return Icons.error;
      case PaymentStatus.due:
        return Icons.warning;
      case PaymentStatus.pending:
        return Icons.schedule;
    }
  }
}
