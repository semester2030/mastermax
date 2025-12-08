import 'package:flutter/material.dart';
import '../models/user_type.dart';
import '../models/business_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;

class RegisterScreen extends StatefulWidget {
  final UserType userType;

  const RegisterScreen({
    required this.userType, super.key,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'email': TextEditingController(),
    'phone': TextEditingController(),
    'password': TextEditingController(),
  };
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final fields = BusinessFields.getFieldsByType(widget.userType);
    for (var section in fields.values) {
      for (var field in section) {
        if (!_controllers.containsKey(field.key)) {
          _controllers[field.key] = TextEditingController();
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _controllers['email']!.text,
        password: _controllers['password']!.text,
      );

      await userCredential.user?.sendEmailVerification();

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'name': _controllers['name']!.text,
        'email': _controllers['email']!.text,
        'phone': _controllers['phone']!.text,
        'userType': widget.userType.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
      });

      if (!mounted) return;
      
      await auth.signOut();

      if (!mounted) return;
      
      final messenger = ScaffoldMessenger.of(context);
      final email = _controllers['email']!.text;
      final colorScheme = Theme.of(context).colorScheme;
      
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم إنشاء الحساب بنجاح'),
              const SizedBox(height: 8),
              Text(
                'تم إرسال رابط التفعيل إلى بريدك الإلكتروني $email',
                style: const TextStyle(fontSize: 12),
              ),
              const Text(
                'يرجى تفعيل حسابك من خلال الرابط المرسل قبل تسجيل الدخول',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'فهمت',
            textColor: colorScheme.onPrimary,
            onPressed: () {},
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/auth/login');
      
    } catch (e) {
      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إنشاء الحساب',
            style: TextStyle(color: colorScheme.onError),
          ),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fields = BusinessFields.getFieldsByType(widget.userType);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                        height: 180,
                        width: 180,
                        padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withOpacity(0.05),
                        border: Border.all(
                            color: colorScheme.primary.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: colorScheme.primary.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: SvgPicture.asset(
                        'assets/images/logos/master_max_logo.svg',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  custom_animations.ShimmerLoading(
                    baseColor: colorScheme.primary,
                    highlightColor: colorScheme.primary,
                    child: Text(
                      'إنشاء حساب جديد',
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBasicFields(context, colorScheme, textTheme),
                        const SizedBox(height: 24),
                        ...fields.entries.map((section) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            custom_animations.ShimmerLoading(
                              baseColor: colorScheme.primary,
                              highlightColor: colorScheme.primary,
                              child: Text(
                                section.key,
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...section.value.map((field) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                controller: _controllers[field.key],
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  hintText: field.label,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary.withOpacity(0.8),
                                  ),
                                  prefixIcon: Icon(
                                    field.icon,
                                    color: colorScheme.primary.withOpacity(0.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (field.required && (value == null || value.isEmpty)) {
                                    return 'هذا الحقل مطلوب';
                                  }
                                  return null;
                                },
                                keyboardType: field.isDate ? TextInputType.datetime : TextInputType.text,
                              ),
                            )),
                          ],
                        )),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : () { _register(); },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                )
                              : Text(
                                  'إنشاء الحساب',
                                  style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimary),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicFields(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        TextFormField(
          controller: _controllers['name'],
      decoration: InputDecoration(
            labelText: 'الاسم',
            hintText: 'أدخل اسمك الكامل',
        border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
        ),
        enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
        ),
        focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary,
              ),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary.withOpacity(0.8),
            ),
            prefixIcon: Icon(
              Icons.person_outline,
              color: colorScheme.primary.withOpacity(0.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الاسم';
        }
        return null;
      },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _controllers['email'],
          decoration: InputDecoration(
            labelText: 'البريد الإلكتروني',
            hintText: 'أدخل بريدك الإلكتروني',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary,
              ),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary.withOpacity(0.8),
            ),
            prefixIcon: Icon(
              Icons.email_outlined,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال البريد الإلكتروني';
  }
            if (!value.contains('@')) {
              return 'الرجاء إدخال بريد إلكتروني صحيح';
        }
            return null;
          },
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _controllers['phone'],
          decoration: InputDecoration(
            labelText: 'رقم الجوال',
            hintText: 'أدخل رقم جوالك',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary,
              ),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary.withOpacity(0.8),
            ),
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال رقم الجوال';
        }
            if (value.length != 10) {
              return 'رقم الجوال يجب أن يكون 10 أرقام';
        }
            return null;
          },
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _controllers['password'],
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            hintText: 'أدخل كلمة المرور',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: colorScheme.primary,
              ),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary.withOpacity(0.8),
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
      }
            if (value.length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
            return null;
          },
          obscureText: _obscurePassword,
        ),
      ],
    );
  }
} 