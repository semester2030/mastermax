import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../providers/real_estate/rental_provider.dart';
import '../../../../models/real_estate/rental_model.dart';

/// Dialog لتجديد عقد إيجار
///
/// يسمح بتحديد تاريخ نهاية جديد للعقد
/// يتبع الثيم الموحد للتطبيق
class RenewRentalDialog extends StatefulWidget {
  final RentalModel rental;

  const RenewRentalDialog({
    super.key,
    required this.rental,
  });

  static void show(BuildContext context, RentalModel rental) {
    showDialog(
      context: context,
      builder: (context) => RenewRentalDialog(rental: rental),
    );
  }

  @override
  State<RenewRentalDialog> createState() => _RenewRentalDialogState();
}

class _RenewRentalDialogState extends State<RenewRentalDialog> {
  DateTime? _newEndDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ✅ التاريخ الافتراضي: سنة من تاريخ انتهاء العقد الحالي
    _newEndDate = widget.rental.endDate.add(const Duration(days: 365));
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newEndDate ?? widget.rental.endDate.add(const Duration(days: 365)),
      firstDate: widget.rental.endDate.add(const Duration(days: 1)), // بعد تاريخ الانتهاء الحالي
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      setState(() {
        _newEndDate = picked;
      });
    }
  }

  Future<void> _handleRenew() async {
    if (_newEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ نهاية جديد'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newEndDate!.isBefore(widget.rental.endDate) || 
        _newEndDate!.isAtSameMomentAs(widget.rental.endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاريخ النهاية الجديد يجب أن يكون بعد تاريخ الانتهاء الحالي'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final rentalProvider = context.read<RentalProvider>();
      await rentalProvider.renewRental(widget.rental, _newEndDate!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تجديد عقد الإيجار بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final colorScheme = Theme.of(context).colorScheme;
    final duration = _newEndDate != null
        ? _newEndDate!.difference(widget.rental.endDate).inDays
        : 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.autorenew, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('تجديد عقد الإيجار'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ معلومات العقد الحالي
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.rental.propertyTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'تاريخ الانتهاء الحالي: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        dateFormat.format(widget.rental.endDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ✅ تاريخ النهاية الجديد
            const Text(
              'تاريخ النهاية الجديد *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'اختر تاريخ النهاية الجديد',
                  prefixIcon: Icon(Icons.event, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _newEndDate != null
                      ? dateFormat.format(_newEndDate!)
                      : 'اختر التاريخ',
                  style: TextStyle(
                    color: _newEndDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            if (_newEndDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                      color: AppColors.success, 
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مدة التجديد: ${duration} يوم (${(duration / 30).toStringAsFixed(1)} شهر)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRenew,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : const Text('تجديد العقد'),
        ),
      ],
    );
  }
}
