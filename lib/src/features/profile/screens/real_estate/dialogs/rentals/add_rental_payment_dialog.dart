import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../providers/real_estate/rental_payment_provider.dart';
import '../../../../models/real_estate/rental_payment_model.dart';

/// Dialog لتسجيل دفعة إيجار
///
/// يعرض form لتسجيل دفعة إيجار
/// يتبع الثيم الموحد للتطبيق
class AddRentalPaymentDialog extends StatefulWidget {
  final String rentalId;
  final double? amount;

  const AddRentalPaymentDialog({
    super.key,
    required this.rentalId,
    this.amount,
  });

  static void show(BuildContext context, {required String rentalId, double? amount}) {
    showDialog(
      context: context,
      builder: (context) => AddRentalPaymentDialog(
        rentalId: rentalId,
        amount: amount,
      ),
    );
  }

  @override
  State<AddRentalPaymentDialog> createState() => _AddRentalPaymentDialogState();
}

class _AddRentalPaymentDialogState extends State<AddRentalPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _paidDate;
  bool _isPaid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.amount != null) {
      _amountController.text = widget.amount!.toString();
    }
    _dueDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? DateTime.now()) : (_paidDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _paidDate = picked;
        }
      });
    }
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ الاستحقاق'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<RentalPaymentProvider>();

      final payment = RentalPaymentModel(
        id: '',
        rentalId: widget.rentalId,
        amount: double.parse(_amountController.text),
        dueDate: _dueDate!,
        paidDate: _isPaid ? (_paidDate ?? DateTime.now()) : null,
        status: _isPaid ? PaymentStatus.paid : PaymentStatus.pending,
        receiptNumber: _receiptNumberController.text.trim().isEmpty
            ? null
            : _receiptNumberController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await provider.addPayment(payment);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدفعة بنجاح'),
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

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.payment, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('تسجيل دفعة'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'المبلغ (ريال) *',
                  prefixIcon: Icon(Icons.attach_money, color: colorScheme.primary),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'المبلغ مطلوب';
                  }
                  if (double.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ الاستحقاق *',
                    prefixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
                  ),
                  child: Text(
                    _dueDate != null
                        ? dateFormat.format(_dueDate!)
                        : 'اختر التاريخ',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('تم الدفع'),
                value: _isPaid,
                onChanged: (value) => setState(() {
                  _isPaid = value;
                  if (value) {
                    _paidDate = DateTime.now();
                  }
                }),
                contentPadding: EdgeInsets.zero,
              ),
              if (_isPaid) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تاريخ الدفع',
                      prefixIcon: Icon(Icons.event, color: colorScheme.primary),
                    ),
                    child: Text(
                      _paidDate != null
                          ? dateFormat.format(_paidDate!)
                          : 'اختر التاريخ',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _receiptNumberController,
                  decoration: InputDecoration(
                    labelText: 'رقم الإيصال',
                    prefixIcon: Icon(Icons.receipt, color: colorScheme.primary),
                    hintText: 'اختياري',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.note, color: colorScheme.primary),
                  hintText: 'اختياري',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAdd,
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
              : const Text('تسجيل'),
        ),
      ],
    );
  }
}
