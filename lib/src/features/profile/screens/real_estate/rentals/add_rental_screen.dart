import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../providers/real_estate/rental_provider.dart';
import '../../../providers/real_estate/rental_payment_provider.dart';
import '../../../models/real_estate/rental_model.dart';
import '../../../providers/real_estate/real_estate_customers_provider.dart';
import '../../../models/real_estate/real_estate_customer_model.dart';
import '../../../../properties/providers/property_provider.dart';
import '../../../../properties/models/property_model.dart';
import '../../../../properties/models/property_type.dart';
import '../widgets/rentals/rental_card.dart';
import '../dialogs/rentals/edit_rental_dialog.dart';
import '../dialogs/rentals/renew_rental_dialog.dart';
import 'rental_details_screen.dart';

/// صفحة كاملة لإضافة عقد إيجار جديد
///
/// تعرض نموذج إضافة العقد في الأعلى
/// تعرض قائمة بالعقود المضافة تلقائياً بعد الإضافة
/// تدعم الفلترة والبحث داخل الصفحة
/// يتبع الثيم الموحد للتطبيق
class AddRentalScreen extends StatefulWidget {
  final PropertyModel? property;
  final String? customerId;

  const AddRentalScreen({
    super.key,
    this.property,
    this.customerId,
  });

  @override
  State<AddRentalScreen> createState() => _AddRentalScreenState();
}

class _AddRentalScreenState extends State<AddRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController();
  final _contractNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  
  // ✅ Controllers للعميل الجديد
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerNotesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  RentalType _rentalType = RentalType.residential;
  PropertyModel? _selectedProperty;
  bool _includesUtilities = false;
  bool _createPaymentSchedule = true;
  bool _isLoading = false;
  bool _isFormExpanded = true; // ✅ حالة توسيع/طي النموذج
  File? _contractPdfFile;
  String? _contractPdfUrl;
  bool _isUploadingPdf = false;
  
  // ✅ اختيار نوع العميل
  bool _isNewCustomer = false; // false = عميل موجود، true = عميل جديد
  RealEstateCustomerModel? _selectedCustomer; // العميل المختار (إذا كان موجوداً)

  // ✅ فلترة العقود
  RentalStatus? _selectedFilter;
  RentalType? _selectedRentalTypeFilter;
  String _searchQuery = '';
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    if (widget.property != null) {
      _selectedProperty = widget.property;
      _monthlyRentController.text = widget.property!.monthlyRent?.toString() ?? '';
      _includesUtilities = widget.property!.includesUtilities ?? false;
      _rentalType = widget.property!.type == PropertyType.commercial
          ? RentalType.commercial
          : RentalType.residential;
    }
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 365));

    // ✅ تحميل البيانات عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RentalProvider>().loadRentals();
      context.read<PropertyProvider>().loadProperties();
      context.read<RealEstateCustomersProvider>().loadCustomers();
    });

    // ✅ الاستماع لتغييرات البحث
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthlyRentController.dispose();
    _depositController.dispose();
    _contractNumberController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _customerNotesController.dispose();
    super.dispose();
  }

  /// ✅ الحصول على العقارات المتاحة للإيجار
  List<PropertyModel> _getAvailableRentalProperties(PropertyProvider provider) {
    return provider.properties.where((property) {
      if (property.offerType != OfferType.rent || 
          property.status != PropertyStatus.available) {
        return false;
      }
      
      if (_rentalType == RentalType.residential) {
        return property.type == PropertyType.apartment || 
               property.type == PropertyType.villa;
      } else {
        return property.type == PropertyType.commercial;
      }
    }).toList();
  }

  /// ✅ فلترة وترتيب العقود
  List<RentalModel> _getFilteredRentals(List<RentalModel> rentals) {
    // ✅ إنشاء نسخة قابلة للتعديل من القائمة (لأن rentals هي unmodifiable)
    var filtered = List<RentalModel>.from(rentals);

    if (_selectedFilter != null) {
      filtered = filtered.where((r) => r.status == _selectedFilter!).toList();
    }

    if (_selectedRentalTypeFilter != null) {
      filtered = filtered.where((r) => r.rentalType == _selectedRentalTypeFilter!).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.propertyTitle.toLowerCase().contains(query) ||
               r.customerName.toLowerCase().contains(query) ||
               (r.contractNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

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

  void _onPropertySelected(PropertyModel? property) {
    if (property == null) return;
    
    setState(() {
      _selectedProperty = property;
      _monthlyRentController.text = property.monthlyRent?.toString() ?? property.price.toString();
      _includesUtilities = property.includesUtilities ?? false;
    });
  }

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
      firstDate: DateTime.now(),
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

  Future<void> _handleAdd() async {
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
      final customersProvider = context.read<RealEstateCustomersProvider>();

      if (_selectedProperty == null) {
        throw 'الرجاء اختيار عقار من القائمة';
      }

      final property = _selectedProperty!;
      
      // ✅ إضافة العميل الجديد إذا كان جديداً
      RealEstateCustomerModel customer;
      if (_isNewCustomer) {
        // التحقق من صحة بيانات العميل الجديد
        if (_customerNameController.text.trim().isEmpty) {
          throw 'اسم العميل مطلوب';
        }
        if (_customerPhoneController.text.trim().isEmpty) {
          throw 'رقم الجوال مطلوب';
        }
        
        // إنشاء العميل الجديد
        final now = DateTime.now();
        final newCustomer = RealEstateCustomerModel(
          id: '',
          companyId: '', // سيتم تعيينه في Provider
          name: _customerNameController.text.trim(),
          phone: _customerPhoneController.text.trim(),
          email: _customerEmailController.text.trim().isEmpty 
              ? null 
              : _customerEmailController.text.trim(),
          address: _customerAddressController.text.trim().isEmpty 
              ? null 
              : _customerAddressController.text.trim(),
          notes: _customerNotesController.text.trim().isEmpty 
              ? null 
              : _customerNotesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        
        // إضافة العميل إلى قاعدة البيانات
        await customersProvider.addCustomer(newCustomer);
        
        // جلب العميل المضاف (لأخذ ID الصحيح)
        await customersProvider.loadCustomers();
        customer = customersProvider.customers.firstWhere(
          (c) => c.name == newCustomer.name && c.phone == newCustomer.phone,
        );
      } else {
        // استخدام العميل المختار
        if (_selectedCustomer == null) {
          if (customersProvider.customers.isEmpty) {
            throw 'لا يوجد عملاء. يرجى إضافة عميل أولاً أو اختيار "عميل جديد"';
          }
          customer = widget.customerId != null
              ? customersProvider.customers.firstWhere((c) => c.id == widget.customerId)
              : customersProvider.customers.first;
        } else {
          customer = _selectedCustomer!;
        }
      }

      String? pdfUrl = _contractPdfUrl;
      if (_contractPdfFile != null && pdfUrl == null) {
        pdfUrl = await _uploadContractFile();
      }

      final rental = RentalModel(
        id: '',
        ownerId: '',
        propertyId: property.id,
        propertyTitle: property.title,
        customerId: customer.id,
        customerName: customer.name,
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
        status: RentalStatus.active,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await rentalProvider.addRental(rental);

      if (_createPaymentSchedule && mounted) {
        final paymentProvider = context.read<RentalPaymentProvider>();
        final addedRentals = rentalProvider.rentals;
        if (addedRentals.isNotEmpty) {
          final addedRental = addedRentals.first;
          await paymentProvider.createPaymentSchedule(
            rentalId: addedRental.id,
            monthlyRent: rental.monthlyRent,
            startDate: rental.startDate,
            endDate: rental.endDate,
          );
        }
      }

      // ✅ إعادة تعيين النموذج بعد الإضافة الناجحة
      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة عقد الإيجار بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // ✅ العودة إلى الصفحة السابقة بعد الإضافة الناجحة
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context, true); // ✅ إرجاع true للإشارة إلى نجاح الإضافة
          }
        });
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

  /// ✅ إعادة تعيين النموذج
  void _resetForm() {
    setState(() {
      _selectedProperty = null;
      _monthlyRentController.clear();
      _depositController.clear();
      _contractNumberController.clear();
      _notesController.clear();
      _contractPdfFile = null;
      _contractPdfUrl = null;
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 365));
      _includesUtilities = false;
      _createPaymentSchedule = true;
      // ✅ إعادة تعيين بيانات العميل
      _isNewCustomer = false;
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerEmailController.clear();
      _customerAddressController.clear();
      _customerNotesController.clear();
    });
  }

  /// ✅ Dialog الفلترة
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
              const Text(
                'الحالة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...RentalStatus.values.map((status) {
                return RadioListTile<RentalStatus?>(
                  title: Text(status.arabicName),
                  value: status,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                    Navigator.pop(context);
                    _showFilterDialog(context);
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }),
              RadioListTile<RentalStatus?>(
                title: const Text('الكل'),
                value: null,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = null;
                  });
                  Navigator.pop(context);
                  _showFilterDialog(context);
                },
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'نوع الإيجار',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...RentalType.values.map((type) {
                return RadioListTile<RentalType?>(
                  title: Text(type.arabicName),
                  value: type,
                  groupValue: _selectedRentalTypeFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedRentalTypeFilter = value;
                    });
                    Navigator.pop(context);
                    _showFilterDialog(context);
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }),
              RadioListTile<RentalType?>(
                title: const Text('الكل'),
                value: null,
                groupValue: _selectedRentalTypeFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedRentalTypeFilter = null;
                  });
                  Navigator.pop(context);
                  _showFilterDialog(context);
                },
                contentPadding: EdgeInsets.zero,
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
            child: const Text('إعادة تعيين'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
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
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأقدم أولاً'),
              value: 'oldest',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأقرب للانتهاء'),
              value: 'endDate',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('الأعلى سعراً'),
              value: 'monthlyRent',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ تأكيد الحذف
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
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deleteRental(rental.id);
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف العقد بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: colorScheme.primary.withValues(alpha: 0.3),
        title: const Text('إضافة عقد إيجار'),
        actions: [
          // ✅ زر توسيع/طي النموذج
          IconButton(
            icon: Icon(_isFormExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _isFormExpanded = !_isFormExpanded;
              });
            },
            tooltip: _isFormExpanded ? 'طي النموذج' : 'توسيع النموذج',
          ),
        ],
      ),
      body: Consumer<RentalProvider>(
        builder: (context, rentalProvider, child) {
          final filteredRentals = _getFilteredRentals(rentalProvider.rentals);
          final hasActiveFilters = _selectedFilter != null || 
                                   _selectedRentalTypeFilter != null || 
                                   _searchQuery.isNotEmpty;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ✅ نموذج إضافة العقد
              SliverToBoxAdapter(
                child: Container(
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
                          Icon(Icons.add_circle, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'نموذج إضافة عقد إيجار',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_isFormExpanded) ...[
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Column(
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
                                      onChanged: (value) {
                                        setState(() {
                                          _rentalType = value!;
                                          _selectedProperty = null;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<RentalType>(
                                      title: const Text('تجاري'),
                                      value: RentalType.commercial,
                                      groupValue: _rentalType,
                                      onChanged: (value) {
                                        setState(() {
                                          _rentalType = value!;
                                          _selectedProperty = null;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // ✅ Divider مع عنوان قسم العميل
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outline.withValues(alpha: 0.3),
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'بيانات العميل (المستأجر)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outline.withValues(alpha: 0.3),
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ✅ اختيار نوع العميل
                              const Text(
                                'نوع العميل *',
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
                                    child: RadioListTile<bool>(
                                      title: const Text('عميل موجود'),
                                      value: false,
                                      groupValue: _isNewCustomer,
                                      onChanged: (value) {
                                        setState(() {
                                          _isNewCustomer = false;
                                          _selectedCustomer = null;
                                          // مسح حقول العميل الجديد
                                          _customerNameController.clear();
                                          _customerPhoneController.clear();
                                          _customerEmailController.clear();
                                          _customerAddressController.clear();
                                          _customerNotesController.clear();
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<bool>(
                                      title: const Text('عميل جديد'),
                                      value: true,
                                      groupValue: _isNewCustomer,
                                      onChanged: (value) {
                                        setState(() {
                                          _isNewCustomer = true;
                                          _selectedCustomer = null;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ✅ قسم العميل (موجود أو جديد)
                              if (!_isNewCustomer)
                                // ✅ اختيار عميل موجود
                                Consumer<RealEstateCustomersProvider>(
                                  builder: (context, customersProvider, child) {
                                    final customers = customersProvider.customers;
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'اختر العميل *',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (customers.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: colorScheme.errorContainer,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: colorScheme.error),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline, color: colorScheme.error, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'لا يوجد عملاء. يرجى اختيار "عميل جديد" لإضافة عميل',
                                                    style: TextStyle(
                                                      color: colorScheme.onErrorContainer,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          DropdownButtonFormField<RealEstateCustomerModel>(
                                            value: _selectedCustomer ?? (widget.customerId != null
                                                ? customers.firstWhere(
                                                    (c) => c.id == widget.customerId,
                                                    orElse: () => customers.first,
                                                  )
                                                : null),
                                            decoration: InputDecoration(
                                              labelText: 'اختر العميل',
                                              prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            items: customers.map((customer) {
                                              return DropdownMenuItem<RealEstateCustomerModel>(
                                                value: customer,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      customer.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      customer.phone,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (customer) {
                                              setState(() {
                                                _selectedCustomer = customer;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null) {
                                                return 'الرجاء اختيار عميل';
                                              }
                                              return null;
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                )
                              else
                                // ✅ إضافة عميل جديد
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'سيتم إضافة العميل الجديد تلقائياً عند حفظ العقد',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // ✅ اسم العميل
                                    TextFormField(
                                      controller: _customerNameController,
                                      decoration: InputDecoration(
                                        labelText: 'اسم العميل *',
                                        prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (_isNewCustomer && (value == null || value.trim().isEmpty)) {
                                          return 'اسم العميل مطلوب';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // ✅ رقم الجوال
                                    TextFormField(
                                      controller: _customerPhoneController,
                                      decoration: InputDecoration(
                                        labelText: 'رقم الجوال *',
                                        prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (_isNewCustomer && (value == null || value.trim().isEmpty)) {
                                          return 'رقم الجوال مطلوب';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // ✅ البريد الإلكتروني
                                    TextFormField(
                                      controller: _customerEmailController,
                                      decoration: InputDecoration(
                                        labelText: 'البريد الإلكتروني',
                                        prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                                        hintText: 'اختياري',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    // ✅ العنوان
                                    TextFormField(
                                      controller: _customerAddressController,
                                      decoration: InputDecoration(
                                        labelText: 'العنوان',
                                        prefixIcon: Icon(Icons.location_on, color: colorScheme.primary),
                                        hintText: 'اختياري',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 16),
                                    // ✅ ملاحظات العميل
                                    TextFormField(
                                      controller: _customerNotesController,
                                      decoration: InputDecoration(
                                        labelText: 'ملاحظات العميل',
                                        prefixIcon: Icon(Icons.note, color: colorScheme.primary),
                                        hintText: 'اختياري',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 24),
                              // ✅ Divider مع عنوان قسم العقار
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outline.withValues(alpha: 0.3),
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.home_outlined,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'بيانات العقار',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: colorScheme.outline.withValues(alpha: 0.3),
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ✅ اختيار العقار
                              Consumer<PropertyProvider>(
                                builder: (context, propertyProvider, child) {
                                  final availableProperties = _getAvailableRentalProperties(propertyProvider);
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'اختر العقار *',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (availableProperties.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: colorScheme.error),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline, color: colorScheme.error, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _rentalType == RentalType.residential
                                                      ? 'لا توجد عقارات سكنية معروضة للإيجار'
                                                      : 'لا توجد عقارات تجارية معروضة للإيجار',
                                                  style: TextStyle(
                                                    color: colorScheme.onErrorContainer,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        DropdownButtonFormField<PropertyModel>(
                                          value: _selectedProperty,
                                          decoration: InputDecoration(
                                            labelText: 'اختر العقار',
                                            prefixIcon: Icon(Icons.home, color: colorScheme.primary),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: availableProperties.map((property) {
                                            return DropdownMenuItem<PropertyModel>(
                                              value: property,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    property.title,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${property.address} - ${property.price} ريال',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (property) => _onPropertySelected(property),
                                          validator: (value) {
                                            if (value == null) {
                                              return 'الرجاء اختيار عقار';
                                            }
                                            return null;
                                          },
                                        ),
                                    ],
                                  );
                                },
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
                              // ✅ رفع ملف PDF أو Word
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
                                        : 'اضغط لاختيار ملف PDF أو Word',
                                    style: TextStyle(
                                      color: _contractPdfFile != null
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
                                      : _contractPdfFile != null
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
                              if (_contractPdfFile != null)
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
                                          'سيتم رفع الملف تلقائياً عند حفظ العقد',
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
                              // ✅ إنشاء جدول دفعات
                              SwitchListTile(
                                title: const Text('إنشاء جدول دفعات تلقائياً'),
                                subtitle: const Text('سيتم إنشاء دفعات شهرية تلقائياً'),
                                value: _createPaymentSchedule,
                                onChanged: (value) => setState(() => _createPaymentSchedule = value),
                                contentPadding: EdgeInsets.zero,
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
                              const SizedBox(height: 24),
                              // ✅ زر الإضافة
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleAdd,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                                          ),
                                        )
                                      : const Icon(Icons.add),
                                  label: Text(_isLoading ? 'جاري الإضافة...' : 'إضافة عقد إيجار'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
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
              ),
              // ✅ شريط البحث والفلترة
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'العقود المضافة',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '(${filteredRentals.length})',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ✅ البحث
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن عقد...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ✅ أزرار الفلترة والترتيب
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showFilterDialog(context),
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
                              label: const Text('فلترة'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showSortDialog(context),
                              icon: const Icon(Icons.sort),
                              label: const Text('ترتيب'),
                            ),
                          ),
                        ],
                      ),
                      // ✅ عرض الفلاتر النشطة
                      if (hasActiveFilters)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_selectedFilter != null)
                                Chip(
                                  label: Text(_selectedFilter!.arabicName),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedFilter = null;
                                    });
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              if (_selectedRentalTypeFilter != null)
                                Chip(
                                  label: Text(_selectedRentalTypeFilter!.arabicName),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedRentalTypeFilter = null;
                                    });
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // ✅ قائمة العقود
              if (rentalProvider.isLoading && rentalProvider.rentals.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredRentals.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasActiveFilters ? Icons.search_off : Icons.inbox,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasActiveFilters
                              ? 'لا توجد نتائج للبحث'
                              : 'لا توجد عقود مضافة بعد',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: RentalCard(
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
                          onDelete: () => _confirmDelete(context, rentalProvider, rental),
                          onRenew: () {
                            RenewRentalDialog.show(context, rental);
                          },
                        ),
                      );
                    },
                    childCount: filteredRentals.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
