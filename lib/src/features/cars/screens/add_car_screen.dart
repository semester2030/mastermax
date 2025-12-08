import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_model.dart';
import '../providers/car_provider.dart';
import '../widgets/car_form.dart';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  bool _isLoading = false;
  CarModel? vehicle;

  Future<void> _submitCar(CarModel car) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<CarProvider>().addCar(car);
      if (!mounted) return;
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: colorScheme.error,
        ),
      );
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'إضافة سيارة',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: colorScheme.surface,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              )
            : CarForm(
                onSubmit: _submitCar,
              ),
      ),
    );
  }
} 