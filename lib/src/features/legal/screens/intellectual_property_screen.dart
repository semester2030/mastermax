import 'package:flutter/material.dart';

class IntellectualPropertyScreen extends StatelessWidget {
  const IntellectualPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'الملكية الفكرية',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.secondary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              icon: Icons.copyright,
              title: 'حقوق النشر',
              content: 'جميع المحتويات والمواد المنشورة في تطبيق أضواء ماكس محمية بموجب قوانين حقوق النشر.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _buildSection(
              icon: Icons.verified_user,
              title: 'العلامات التجارية',
              content: 'جميع العلامات التجارية والشعارات المستخدمة في التطبيق هي ملك لأصحابها المعنيين.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _buildSection(
              icon: Icons.gavel,
              title: 'براءات الاختراع',
              content: 'التقنيات والابتكارات المستخدمة في التطبيق قد تكون محمية بموجب براءات اختراع مسجلة.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _buildSection(
              icon: Icons.security,
              title: 'حماية المحتوى',
              content: 'يحظر نسخ أو إعادة نشر أي محتوى من التطبيق دون إذن كتابي مسبق.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(26), // 0.1 * 255
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.secondary.withAlpha(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.secondary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha(179),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
} 