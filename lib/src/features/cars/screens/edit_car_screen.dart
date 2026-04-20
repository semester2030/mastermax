import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_model.dart';
import '../providers/car_provider.dart';
import '../widgets/car_form.dart';
import '../../../core/theme/app_colors.dart';

/// تعديل مركبة موجودة (من إدارة المركبات والمبيعات).
class EditCarScreen extends StatefulWidget {
  final CarModel car;

  const EditCarScreen({super.key, required this.car});

  @override
  State<EditCarScreen> createState() => _EditCarScreenState();
}

class _EditCarScreenState extends State<EditCarScreen> {
  bool _isSaving = false;

  Future<void> _submit(CarModel car) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await context.read<CarProvider>().updateCar(car);
      if (!mounted) return;
      final err = context.read<CarProvider>().error;
      if (err != null) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: Text(
          'تعديل السيارة',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: colorScheme.surface,
        child: _isSaving
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              )
            : CarForm(
                initialCar: widget.car,
                onSubmit: _submit,
              ),
      ),
    );
  }
}
