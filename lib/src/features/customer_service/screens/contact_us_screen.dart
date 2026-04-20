import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/theme/app_colors.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لا يمكن فتح الرابط'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: Implement form submission
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إرسال رسالتك بنجاح'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      _formKey.currentState?.reset();
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
          'اتصل بنا',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colorScheme.secondary.withAlpha(179), // 0.7 * 255
              colorScheme.primary.withAlpha(179),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildContactInfo(colorScheme, textTheme),
              const SizedBox(height: 32),
              _buildContactForm(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return custom_animations.AnimatedScale(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withAlpha(51), // 0.2 * 255
              colorScheme.secondary.withAlpha(51),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.secondary.withAlpha(77), // 0.3 * 255
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withAlpha(26), // 0.1 * 255
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            custom_animations.ShimmerLoading(
              baseColor: colorScheme.secondary.withAlpha(128), // 0.5 * 255
              highlightColor: colorScheme.secondary,
              child: Text(
                'معلومات الاتصال',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              icon: Icons.phone,
              title: 'الهاتف',
              content: '+966 XX XXX XXXX',
              onTap: () => _launchUrl('tel:+966XXXXXXXX'),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            Divider(color: colorScheme.secondary.withAlpha(51)),
            _buildContactItem(
              icon: Icons.email,
              title: 'البريد الإلكتروني',
              content: 'support@mastermax.com',
              onTap: () => _launchUrl('mailto:support@mastermax.com'),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            Divider(color: colorScheme.secondary.withAlpha(51)),
            _buildContactItem(
              icon: Icons.location_on,
              title: 'العنوان',
              content: 'الرياض، المملكة العربية السعودية',
              onTap: () => _launchUrl('https://maps.google.com/?q=Riyadh'),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String content,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return custom_animations.AnimatedScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            custom_animations.AnimatedGlow(
              glowColor: colorScheme.secondary,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withAlpha(26), // 0.1 * 255
                  border: Border.all(
                    color: colorScheme.secondary.withAlpha(77),
                  ),
                ),
                child: Icon(icon, color: colorScheme.secondary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    content,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm(ColorScheme colorScheme, TextTheme textTheme) {
    return custom_animations.AnimatedScale(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withAlpha(51),
              colorScheme.secondary.withAlpha(51),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.secondary.withAlpha(77),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withAlpha(26),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              custom_animations.ShimmerLoading(
                baseColor: colorScheme.secondary.withAlpha(128),
                highlightColor: colorScheme.secondary,
                child: Text(
                  'أرسل لنا رسالة',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                labelText: 'الاسم',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                labelText: 'البريد الإلكتروني',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$')
                      .hasMatch(value!)) {
                    return 'الرجاء إدخال بريد إلكتروني صحيح';
                  }
                  return null;
                },
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _messageController,
                labelText: 'الرسالة',
                maxLines: 5,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'الرجاء إدخال الرسالة';
                  }
                  return null;
                },
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 24),
              custom_animations.AnimatedScale(
                onTap: _submitForm,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary,
                        colorScheme.secondary.withAlpha(204), // 0.8 * 255
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.secondary.withAlpha(77),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    'إرسال',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String? Function(String?) validator,
    int maxLines = 1,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: colorScheme.secondary.withAlpha(77),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.secondary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        filled: true,
        fillColor: colorScheme.primary.withAlpha(51),
      ),
      validator: validator,
    );
  }
} 