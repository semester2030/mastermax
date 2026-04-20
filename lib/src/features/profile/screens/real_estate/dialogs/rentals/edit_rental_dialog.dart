import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../providers/real_estate/rental_provider.dart';
import '../../../../models/real_estate/rental_model.dart';
import '../../../../providers/real_estate/real_estate_customers_provider.dart';
import '../../../../../properties/providers/property_provider.dart';
import '../../../../../properties/models/property_model.dart';
import '../../../../../properties/models/property_type.dart';

/// Dialog لتعديل عقد إيجار موجود
///
/// يعرض form لتعديل بيانات عقد إيجار مع ربط مع Firestore
/// يتبع الثيم الموحد للتطبيق
class EditRentalDialog extends StatefulWidget {
  final RentalModel rental;

  const EditRentalDialog({
    super.key,
    required this.rental,
  });

  static void show(BuildContext context, RentalModel rental) {
    showDialog(
      context: context,
      builder: (context) => EditRentalDialog(rental: rental),
    );
  }

  @override
  State<EditRentalDialog> createState() => _EditRentalDialogState();
}

class _EditRentalDialogState extends State<EditRentalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController();
  final _contractNumberController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  RentalType _rentalType = RentalType.residential;
  PropertyModel? _selectedProperty;
  bool _includesUtilities = false;
  bool _isLoading = false;
  File? _contractPdfFile;
  String? _contractPdfUrl;
  bool _isUploadingPdf = false;

  @override
  void initState() {
    super.initState();
    // ✅ تحميل البيانات الحالية
    _monthlyRentController.text = widget.rental.monthlyRent.toString();
    _depositController.text = widget.rental.deposit.toString();
    _contractNumberController.text = widget.rental.contractNumber ?? '';
    _notesController.text = widget.rental.notes ?? '';
    _startDate = widget.rental.startDate;
    _endDate = widget.rental.endDate;
    _rentalType = widget.rental.rentalType;
    _includesUtilities = widget.rental.includesUtilities;
    _contractPdfUrl = widget.rental.contractPdfUrl;
  }

  @override
  void dispose() {
    _monthlyRentController.dispose();
    _depositController.dispose();
    _contractNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// اختيار ملف PDF أو Word للعقد
  Future<void> _pickContractFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _contractPdfFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الملف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// رفع ملف PDF أو Word إلى Firebase Storage
  Future<String?> _uploadContractFile() async {
    if (_contractPdfFile == null) return null;

    try {
      setState(() {
        _isUploadingPdf = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'يجب تسجيل الدخول لرفع الملف';
      }

      final filePath = _contractPdfFile!.path.toLowerCase();
      final String fileExtension;
      final String contentType;
      
      if (filePath.endsWith('.pdf')) {
        fileExtension = 'pdf';
        contentType = 'application/pdf';
      } else if (filePath.endsWith('.doc')) {
        fileExtension = 'doc';
        contentType = 'application/msword';
      } else if (filePath.endsWith('.docx')) {
        fileExtension = 'docx';
        contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else {
        throw 'نوع الملف غير مدعوم. يرجى اختيار ملف PDF أو Word';
      }

      final fileName = 'rental_contract_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('rental_contracts')
          .child(user.uid)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        _contractPdfFile!,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'fileType': fileExtension,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _contractPdfUrl = downloadUrl;
        _isUploadingPdf = false;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploadingPdf = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء رفع الملف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار تاريخ البداية والنهاية'),
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
      final propertyProvider = context.read<PropertyProvider>();

      // ✅ جلب العقار المحدد
      if (_selectedProperty == null) {
        // استخدام العقار الحالي من العقد
        final property = propertyProvider.properties.firstWhere(
          (p) => p.id == widget.rental.propertyId,
          orElse: () => propertyProvider.properties.first,
        );
        _selectedProperty = property;
      }

      // ✅ رفع ملف PDF أو Word إذا كان موجوداً
      String? pdfUrl = _contractPdfUrl;
      if (_contractPdfFile != null && pdfUrl == null) {
        pdfUrl = await _uploadContractFile();
      }

      final updatedRental = widget.rental.copyWith(
        propertyId: _selectedProperty!.id,
        propertyTitle: _selectedProperty!.title,
        rentalType: _rentalType,
        monthlyRent: double.parse(_monthlyRentController.text),
        startDate: _startDate!,
        endDate: _endDate!,
        deposit: _depositController.text.isNotEmpty
            ? double.parse(_depositController.text)
            : 0,
        includesUtilities: _includesUtilities,
        contractNumber: _contractNumberController.text.trim().isEmpty
            ? null
            : _contractNumberController.text.trim(),
        contractPdfUrl: pdfUrl,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await rentalProvider.updateRental(updatedRental);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث عقد الإيجار بنجاح'),
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
          Icon(Icons.edit, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('تعديل عقد إيجار'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ نوع الإيجار
              const Text(
                'نوع الإيجار *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<RentalType>(
                      title: const Text('سكني'),
                      value: RentalType.residential,
                      groupValue: _rentalType,
                      onChanged: (value) => setState(() => _rentalType = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<RentalType>(
                      title: const Text('تجاري'),
                      value: RentalType.commercial,
                      groupValue: _rentalType,
                      onChanged: (value) => setState(() => _rentalType = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ✅ الإيجار الشهري
              TextFormField(
                controller: _monthlyRentController,
                decoration: InputDecoration(
                  labelText: 'الإيجار الشهري (ريال) *',
                  prefixIcon: Icon(Icons.attach_money, color: colorScheme.primary),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الإيجار الشهري مطلوب';
                  }
                  if (double.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ✅ تاريخ البداية
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ البداية *',
                    prefixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
                  ),
                  child: Text(
                    _startDate != null
                        ? dateFormat.format(_startDate!)
                        : 'اختر التاريخ',
                    style: TextStyle(
                      color: _startDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ✅ تاريخ النهاية
              InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ النهاية *',
                    prefixIcon: Icon(Icons.event, color: colorScheme.primary),
                  ),
                  child: Text(
                    _endDate != null
                        ? dateFormat.format(_endDate!)
                        : 'اختر التاريخ',
                    style: TextStyle(
                      color: _endDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ✅ الضمان
              TextFormField(
                controller: _depositController,
                decoration: InputDecoration(
                  labelText: 'الضمان (ريال)',
                  prefixIcon: Icon(Icons.security, color: colorScheme.primary),
                  hintText: 'اختياري',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // ✅ يشمل المرافق
              SwitchListTile(
                title: const Text('يشمل المرافق'),
                value: _includesUtilities,
                onChanged: (value) => setState(() => _includesUtilities = value),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              // ✅ رقم العقد
              TextFormField(
                controller: _contractNumberController,
                decoration: InputDecoration(
                  labelText: 'رقم العقد',
                  prefixIcon: Icon(Icons.numbers, color: colorScheme.primary),
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 16),
              // ✅ رفع ملف PDF أو Word للعقد
              const Text(
                'ملف العقد (PDF أو Word)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.upload_file,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    _contractPdfFile != null
                        ? _contractPdfFile!.path.split('/').last
                        : _contractPdfUrl != null
                            ? 'ملف موجود (اضغط لتغييره)'
                            : 'اضغط لاختيار ملف PDF أو Word',
                    style: TextStyle(
                      color: _contractPdfFile != null || _contractPdfUrl != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  trailing: _isUploadingPdf
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _contractPdfFile != null || _contractPdfUrl != null
                          ? IconButton(
                              icon: const Icon(Icons.close, color: AppColors.error),
                              onPressed: () {
                                setState(() {
                                  _contractPdfFile = null;
                                  _contractPdfUrl = null;
                                });
                              },
                            )
                          : null,
                  onTap: _isUploadingPdf ? null : _pickContractFile,
                ),
              ),
              if (_contractPdfFile != null || _contractPdfUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _contractPdfFile != null
                              ? 'سيتم رفع الملف تلقائياً عند حفظ التعديلات'
                              : 'الملف الحالي سيتم الاحتفاظ به',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'الأنواع المدعومة: PDF, DOC, DOCX',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // ✅ ملاحظات
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.note, color: colorScheme.primary),
                  hintText: 'اختياري',
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
              : const Text('حفظ التعديلات'),
        ),
      ],
    );
  }
}
