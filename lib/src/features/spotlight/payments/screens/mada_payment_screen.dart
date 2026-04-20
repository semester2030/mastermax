import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mada_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';

class MadaPaymentScreen extends StatefulWidget {
  final double amount;
  final String userId;
  final String planId;

  const MadaPaymentScreen({
    required this.amount, required this.userId, required this.planId, super.key,
  });

  @override
  State<MadaPaymentScreen> createState() => _MadaPaymentScreenState();
}

class _MadaPaymentScreenState extends State<MadaPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _madaService = MadaService();
  bool _isLoading = false;

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

    setState(() => _isLoading = true);
    try {
      final success = await _madaService.processPayment(
        amount: widget.amount,
        userId: widget.userId,
        planId: widget.planId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في عملية الدفع'),
            backgroundColor: AppTheme.royalPurple,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حدث خطأ، يرجى المحاولة مرة أخرى'),
          backgroundColor: AppTheme.royalPurple,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: AppTheme.brightGold),
      prefixIcon: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ColorUtils.withOpacity(AppTheme.brightGold, 0.1),
          border: Border.all(
            color: ColorUtils.withOpacity(AppTheme.brightGold, 0.3),
          ),
        ),
        child: Icon(icon, color: AppTheme.brightGold, size: 20),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ColorUtils.withOpacity(AppTheme.brightGold, 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ColorUtils.withOpacity(AppTheme.brightGold, 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppTheme.brightGold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: ColorUtils.withOpacity(AppColors.error, 0.5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      filled: true,
      fillColor: ColorUtils.withOpacity(AppTheme.royalPurple, 0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: Text(
          'الدفع بمدى',
          style: TextStyle(
            color: AppTheme.brightGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(AppTheme.royalPurple, 0.1),
              ColorUtils.withOpacity(AppTheme.skyBlue, 0.1),
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightGold),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorUtils.withOpacity(AppTheme.royalPurple, 0.2),
                              ColorUtils.withOpacity(AppTheme.skyBlue, 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ColorUtils.withOpacity(AppTheme.brightGold, 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المبلغ: ${widget.amount} ريال',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brightGold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _cardNumberController,
                              decoration: _buildInputDecoration(
                                labelText: 'رقم البطاقة',
                                icon: Icons.credit_card,
                              ),
                              style: const TextStyle(color: AppColors.white),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(16),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال رقم البطاقة';
                                }
                                if (value.length != 16) {
                                  return 'رقم البطاقة يجب أن يكون 16 رقم';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _expiryController,
                                    decoration: _buildInputDecoration(
                                      labelText: 'تاريخ الانتهاء',
                                      icon: Icons.calendar_today,
                                    ),
                                    style: const TextStyle(color: AppColors.white),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'الرجاء إدخال تاريخ الانتهاء';
                                      }
                                      if (value.length != 4) {
                                        return 'التاريخ غير صحيح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cvvController,
                                    decoration: _buildInputDecoration(
                                      labelText: 'CVV',
                                      icon: Icons.security,
                                    ),
                                    style: const TextStyle(color: AppColors.white),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'الرجاء إدخال CVV';
                                      }
                                      if (value.length != 3) {
                                        return 'CVV يجب أن يكون 3 أرقام';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: _buildInputDecoration(
                                labelText: 'الاسم على البطاقة',
                                icon: Icons.person,
                              ),
                              style: const TextStyle(color: AppColors.white),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال الاسم على البطاقة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ColorUtils.withOpacity(AppTheme.brightGold, 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Material(
                                color: AppColors.transparent,
                                child: InkWell(
                                  onTap: _processPayment,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 32,
                                    ),
                                    child: Text(
                                      'إتمام الدفع',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.royalPurple,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
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
      ),
    );
  }
} 