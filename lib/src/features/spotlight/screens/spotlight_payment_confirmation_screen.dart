import 'package:flutter/material.dart';
import '../models/spotlight_plan.dart';
import '../../../core/theme/app_colors.dart';

class SpotlightPaymentConfirmationScreen extends StatelessWidget {
  final bool success;
  final String message;
  final SpotlightPlan plan;

  const SpotlightPaymentConfirmationScreen({
    required this.success, required this.message, required this.plan, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد الدفع'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                size: 80,
                color: success ? AppColors.success : AppColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/spotlight/feed',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'العودة للرئيسية',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 