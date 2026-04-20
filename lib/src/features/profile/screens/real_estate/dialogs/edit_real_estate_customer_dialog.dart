import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../providers/real_estate/real_estate_customers_provider.dart';
import '../../../models/real_estate/real_estate_customer_model.dart';

/// Dialog لتعديل عميل للعقارات
///
/// يعرض form لتعديل بيانات عميل مع ربط مع Firestore
/// يتبع الثيم الموحد للتطبيق
class EditRealEstateCustomerDialog extends StatefulWidget {
  final RealEstateCustomerModel customer;

  const EditRealEstateCustomerDialog({
    super.key,
    required this.customer,
  });

  static void show(BuildContext context, RealEstateCustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => EditRealEstateCustomerDialog(customer: customer),
    );
  }

  @override
  State<EditRealEstateCustomerDialog> createState() => _EditRealEstateCustomerDialogState();
}

class _EditRealEstateCustomerDialogState extends State<EditRealEstateCustomerDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.customer.name);
  late final _phoneController = TextEditingController(text: widget.customer.phone);
  late final _emailController = TextEditingController(text: widget.customer.email ?? '');
  late final _addressController = TextEditingController(text: widget.customer.address ?? '');
  late final _notesController = TextEditingController(text: widget.customer.notes ?? '');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<RealEstateCustomersProvider>();

      final updatedCustomer = widget.customer.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await provider.updateCustomer(updatedCustomer);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث بيانات العميل بنجاح'),
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('تعديل بيانات العميل'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم العميل *',
                  prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم العميل مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'رقم الجوال *',
                  prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'رقم الجوال مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.location_on, color: colorScheme.primary),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.note, color: colorScheme.primary),
                ),
                maxLines: 3,
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
          onPressed: _isLoading ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                  ),
                )
              : const Text('حفظ التغييرات'),
        ),
      ],
    );
  }
}
