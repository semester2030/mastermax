import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../providers/car_showroom/sales_provider.dart';
import '../../../providers/car_showroom/customers_provider.dart';
import '../../../../cars/providers/car_provider.dart';
import '../../../models/car_showroom/sale_model.dart';

/// Dialog لتسجيل عملية بيع جديدة
///
/// يعرض form لتسجيل عملية بيع مع ربط مع Firestore
/// يتبع الثيم الموحد للتطبيق
class AddSaleDialog extends StatefulWidget {
  const AddSaleDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddSaleDialog(),
    );
  }

  @override
  State<AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends State<AddSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _salePriceController = TextEditingController();
  final _profitController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedCarId;
  String? _selectedCustomerId;
  String? _selectedPaymentMethod;
  DateTime _saleDate = DateTime.now();
  bool _isLoading = false;

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ar');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void dispose() {
    _salePriceController.dispose();
    _profitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار السيارة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار العميل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final salesProvider = context.read<SalesProvider>();
      final carProvider = context.read<CarProvider>();
      final customersProvider = context.read<CustomersProvider>();

      final car = carProvider.cars.firstWhere((c) => c.id == _selectedCarId);
      final customer = customersProvider.customers.firstWhere((c) => c.id == _selectedCustomerId);

      final salePrice = double.tryParse(_salePriceController.text.trim().replaceAll(',', '')) ?? 0;
      
      // ✅ حساب الربح تلقائياً من سعر الشراء/التكلفة إذا كان موجوداً
      double? profit;
      if (_profitController.text.trim().isNotEmpty) {
        // إذا تم إدخال الربح يدوياً، استخدمه
        profit = double.tryParse(_profitController.text.trim().replaceAll(',', ''));
      } else if (car.purchasePrice != null && car.purchasePrice! > 0) {
        // إذا لم يتم إدخال الربح يدوياً، احسبه تلقائياً من سعر الشراء/التكلفة
        profit = salePrice - car.purchasePrice!;
      }

      final now = DateTime.now();

      final sale = SaleModel(
        id: '',
        sellerId: '', // سيتم تعيينه في Provider
        carId: car.id,
        carTitle: car.title,
        customerId: customer.id,
        customerName: customer.name,
        salePrice: salePrice,
        profit: profit,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        saleDate: _saleDate,
        createdAt: now,
        updatedAt: now,
      );

      await salesProvider.addSale(sale);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل عملية البيع بنجاح'),
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
    return Consumer3<CarProvider, CustomersProvider, SalesProvider>(
      builder: (context, carProvider, customersProvider, salesProvider, child) {
        final userCars = carProvider.cars.where((car) => car.isActive).toList();
        final customers = customersProvider.customers;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('تسجيل عملية بيع'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار السيارة
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'المركبة *',
                      prefixIcon: Icon(Icons.directions_car, color: AppColors.primary),
                    ),
                    value: _selectedCarId,
                    items: userCars.map((car) {
                      return DropdownMenuItem<String>(
                        value: car.id,
                        child: Text('${car.title} - ${_numberFormat.format(car.price)} ر.س'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCarId = value;
                        // ✅ حساب الربح تلقائياً عند اختيار السيارة
                        if (value != null) {
                          final selectedCar = userCars.firstWhere((car) => car.id == value);
                          if (selectedCar.purchasePrice != null && selectedCar.purchasePrice! > 0) {
                            // إذا كان هناك سعر شراء/تكلفة، احسب الربح المتوقع
                            final salePrice = double.tryParse(_salePriceController.text.trim().replaceAll(',', '')) ?? selectedCar.price;
                            final expectedProfit = salePrice - selectedCar.purchasePrice!;
                            if (expectedProfit > 0) {
                              _profitController.text = _numberFormat.format(expectedProfit);
                            }
                          }
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء اختيار السيارة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // اختيار العميل
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'العميل *',
                      prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    ),
                    value: _selectedCustomerId,
                    items: customers.map((customer) {
                      return DropdownMenuItem<String>(
                        value: customer.id,
                        child: Text('${customer.name} - ${customer.phone}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomerId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء اختيار العميل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // تاريخ البيع
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _saleDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          _saleDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ البيع *',
                        prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                      ),
                      child: Text(_dateFormat.format(_saleDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // سعر البيع
                  TextFormField(
                    controller: _salePriceController,
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع *',
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // ✅ تحديث الربح تلقائياً عند تغيير سعر البيع
                      if (_selectedCarId != null && value.isNotEmpty) {
                        final selectedCar = userCars.firstWhere((car) => car.id == _selectedCarId);
                        if (selectedCar.purchasePrice != null && selectedCar.purchasePrice! > 0) {
                          final salePrice = double.tryParse(value.trim().replaceAll(',', '')) ?? 0;
                          if (salePrice > 0) {
                            final expectedProfit = salePrice - selectedCar.purchasePrice!;
                            setState(() {
                              if (expectedProfit > 0) {
                                _profitController.text = _numberFormat.format(expectedProfit);
                              } else {
                                _profitController.clear();
                              }
                            });
                          }
                        }
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'سعر البيع مطلوب';
                      }
                      final price = double.tryParse(value.trim().replaceAll(',', ''));
                      if (price == null || price <= 0) {
                        return 'سعر البيع يجب أن يكون أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // الربح
                  TextFormField(
                    controller: _profitController,
                    decoration: const InputDecoration(
                      labelText: 'الربح (اختياري - يحسب تلقائياً)',
                      prefixIcon: Icon(Icons.trending_up, color: AppColors.primary),
                      helperText: 'سيتم حساب الربح تلقائياً من سعر الشراء/التكلفة إذا كان موجوداً',
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: _selectedCarId != null && 
                              userCars.any((car) => car.id == _selectedCarId && car.purchasePrice != null),
                  ),
                  const SizedBox(height: 16),
                  
                  // طريقة الدفع
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      prefixIcon: Icon(Icons.payment, color: AppColors.primary),
                    ),
                    value: _selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                      DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
                      DropdownMenuItem(value: 'تقسيط', child: Text('تقسيط')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // ملاحظات
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      prefixIcon: Icon(Icons.note, color: AppColors.primary),
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
              onPressed: _isLoading ? null : _handleAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
      },
    );
  }
}
