import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context,
                'نحن نجمع المعلومات التي تقدمها مباشرة عند:',
                [
                  'إنشاء حساب',
                  'نشر إعلان',
                  'التواصل مع المستخدمين الآخرين',
                  'استخدام خدمات التطبيق',
                ],
              ),
              const SizedBox(height: 32),
              _buildSection(
                context,
                'نستخدم المعلومات التي نجمعها لتحسين خدماتنا وتجربة المستخدم',
                [
                  'تقديم وتحسين خدماتنا',
                  'التواصل معك',
                  'حماية حقوقك وحقوق الآخرين',
                  'الامتثال للقوانين واللوائح',
                ],
              ),
              const SizedBox(height: 32),
              _buildSection(
                context,
                'نتخذ إجراءات أمنية لحماية معلوماتك:',
                [
                  'تشفير البيانات',
                  'مراقبة الأنظمة',
                  'تحديث إجراءات الأمان بشكل دوري',
                  'تدريب الموظفين على أمن المعلومات',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> points) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
} 