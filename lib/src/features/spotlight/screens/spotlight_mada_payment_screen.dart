import 'package:flutter/material.dart';
import '../models/spotlight_plan.dart';
import '../payments/services/mada_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class SpotlightMadaPaymentScreen extends StatefulWidget {
  final SpotlightPlan plan;

  const SpotlightMadaPaymentScreen({
    required this.plan, super.key,
  });

  @override
  State<SpotlightMadaPaymentScreen> createState() => _SpotlightMadaPaymentScreenState();
}

class _SpotlightMadaPaymentScreenState extends State<SpotlightMadaPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final madaService = MadaService();
      final success = await madaService.processPayment(
        amount: widget.plan.price,
        userId: 'user_id', // يجب استبداله بمعرف المستخدم الفعلي
        planId: widget.plan.id,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/spotlight/payments/confirmation',
          arguments: {
            'success': true,
            'message': 'تم الدفع بنجاح!',
            'plan': widget.plan,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
            AppColors.primaryDark,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          title: const Text(
            'الدفع عبر مدى',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(AppColors.textPrimary, 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تفاصيل الدفع',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentField(
                      label: 'رقم البطاقة',
                      hint: '•••• •••• •••• ••••',
                      controller: _cardNumberController,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentField(
                            label: 'تاريخ الانتهاء',
                            hint: 'MM/YY',
                            controller: _expiryController,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPaymentField(
                            label: 'CVV',
                            hint: '•••',
                            controller: _cvvController,
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentField(
                      label: 'الاسم على البطاقة',
                      hint: 'الاسم الكامل',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: AppColors.white)
                          : const Text(
                              'إتمام الدفع',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
} 