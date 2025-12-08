import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BankTransferScreen extends StatefulWidget {
  final double amount;
  final String planId;

  const BankTransferScreen({
    required this.amount, required this.planId, super.key,
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _submitTransfer() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        // TODO: تنفيذ عملية التحويل البنكي
        await Future.delayed(const Duration(seconds: 2)); // محاكاة العملية
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ أثناء التحويل')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'التحويل البنكي',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
        ),
      ),
      body: Form(
        key: _formKey,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'معلومات الحساب البنكي',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBankDetails(context, colorScheme, textTheme),
                  const SizedBox(height: 24),
                  _buildTransferInstructions(context, colorScheme, textTheme),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: Text(
                      'تأكيد التحويل',
                      style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBankDetails(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBankField(context, colorScheme, textTheme, 'اسم البنك', 'البنك الأهلي السعودي'),
            _buildBankField(context, colorScheme, textTheme, 'اسم الحساب', 'شركة عقارات ماكس'),
            _buildBankField(context, colorScheme, textTheme, 'رقم الحساب (IBAN)', 'SA0380000000608010167519'),
            _buildBankField(context, colorScheme, textTheme, 'المبلغ', '${widget.amount} ريال'),
          ],
        ),
      ),
    );
  }

  Widget _buildBankField(BuildContext context, ColorScheme colorScheme, TextTheme textTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.copy, size: 20, color: colorScheme.primary),
                onPressed: () => _copyToClipboard(value),
                tooltip: 'نسخ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferInstructions(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعليمات التحويل',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('1. قم بنسخ رقم الحساب (IBAN)', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
            Text('2. قم بالتحويل عبر تطبيق البنك الخاص بك', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
            Text('3. احتفظ بإيصال التحويل', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
            Text('4. اضغط على زر تأكيد التحويل', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم النسخ')),
      );
    }
  }
} 