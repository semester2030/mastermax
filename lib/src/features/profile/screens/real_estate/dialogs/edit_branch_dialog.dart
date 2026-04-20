import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../providers/real_estate/branches_provider.dart';
import '../../../models/real_estate/branch_model.dart';

class EditBranchDialog extends StatefulWidget {
  final BranchModel branch;
  const EditBranchDialog({super.key, required this.branch});

  static void show(BuildContext context, BranchModel branch) {
    showDialog(context: context, builder: (context) => EditBranchDialog(branch: branch));
  }

  @override
  State<EditBranchDialog> createState() => _EditBranchDialogState();
}

class _EditBranchDialogState extends State<EditBranchDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.branch.name);
  late final _addressController = TextEditingController(text: widget.branch.address);
  late final _phoneController = TextEditingController(text: widget.branch.phone);
  late final _emailController = TextEditingController(text: widget.branch.email ?? '');
  late final _managerNameController = TextEditingController(text: widget.branch.managerName ?? '');
  late final _managerPhoneController = TextEditingController(text: widget.branch.managerPhone ?? '');
  late bool _isActive = widget.branch.isActive;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<BranchesProvider>();
      final updated = widget.branch.copyWith(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        managerName: _managerNameController.text.trim().isEmpty ? null : _managerNameController.text.trim(),
        managerPhone: _managerPhoneController.text.trim().isEmpty ? null : _managerPhoneController.text.trim(),
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );
      await provider.updateBranch(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الفرع بنجاح'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Icon(Icons.edit_outlined, color: colorScheme.primary), const SizedBox(width: 8), const Text('تعديل بيانات الفرع')]),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'اسم الفرع *', prefixIcon: Icon(Icons.store, color: colorScheme.primary)), validator: (v) => v?.trim().isEmpty ?? true ? 'اسم الفرع مطلوب' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, decoration: InputDecoration(labelText: 'العنوان *', prefixIcon: Icon(Icons.location_on, color: colorScheme.primary)), maxLines: 2, validator: (v) => v?.trim().isEmpty ?? true ? 'العنوان مطلوب' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, decoration: InputDecoration(labelText: 'رقم الهاتف *', prefixIcon: Icon(Icons.phone, color: colorScheme.primary)), keyboardType: TextInputType.phone, validator: (v) => v?.trim().isEmpty ?? true ? 'رقم الهاتف مطلوب' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email, color: colorScheme.primary)), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextFormField(controller: _managerNameController, decoration: InputDecoration(labelText: 'اسم المدير', prefixIcon: Icon(Icons.person, color: colorScheme.primary))),
              const SizedBox(height: 16),
              TextFormField(controller: _managerPhoneController, decoration: InputDecoration(labelText: 'رقم هاتف المدير', prefixIcon: Icon(Icons.phone, color: colorScheme.primary)), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text('الفرع نشط'), value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: colorScheme.primary),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _isLoading ? null : _handleUpdate, style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), child: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary))) : const Text('حفظ التغييرات')),
      ],
    );
  }
}
