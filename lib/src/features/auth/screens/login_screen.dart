import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state.dart';
import '../services/auth_service.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isForgotPasswordHovered = false;
  bool _isCreateAccountHovered = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authState = Provider.of<AuthState>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final user = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      authState.setAuthenticated(user);
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      Provider.of<AuthState>(context, listen: false).setError(e.toString());
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
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        color: colorScheme.surface,
        child: custom_animations.AnimatedGlow(
          glowColor: colorScheme.primary.withOpacity(0.08),
          maxRadius: 50,
          duration: const Duration(seconds: 2),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Hero(
                      tag: 'app_logo',
                      child: custom_animations.AnimatedGlow(
                        glowColor: colorScheme.primary,
                        maxRadius: 30,
                        duration: const Duration(seconds: 2),
                        child: Container(
                          height: 180,
                          width: 180,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surface,
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: colorScheme.surface.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: -5,
                                offset: const Offset(-5, -5),
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/images/logos/master_max_logo.svg',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    custom_animations.ShimmerLoading(
                      baseColor: colorScheme.primary,
                      highlightColor: colorScheme.primary.withOpacity(0.8),
                      child: Text(
                        'MASTER MAX',
                        style: textTheme.displaySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          custom_animations.AnimatedScale(
                            scale: 0.98,
                            duration: const Duration(milliseconds: 100),
                            child: _buildTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              icon: Icons.email,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال البريد الإلكتروني';
                                }
                                return null;
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(height: 20),
                          custom_animations.AnimatedScale(
                            scale: 0.98,
                            duration: const Duration(milliseconds: 100),
                            child: _buildTextField(
                              controller: _passwordController,
                              label: 'كلمة المرور',
                              icon: Icons.lock,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال كلمة المرور';
                                }
                                return null;
                              },
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(height: 30),
                          custom_animations.AnimatedScale(
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.15),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: colorScheme.onPrimary,
                                  shadowColor: Colors.transparent,
                                ),
                                child: _isLoading
                                    ? CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                      )
                                    : Text(
                                        'تسجيل الدخول',
                                        style: textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    MouseRegion(
                      onEnter: (_) => setState(() => _isForgotPasswordHovered = true),
                      onExit: (_) => setState(() => _isForgotPasswordHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _isForgotPasswordHovered 
                              ? colorScheme.primary 
                              : colorScheme.primary.withOpacity(0.3),
                            width: _isForgotPasswordHovered ? 3 : 2,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/forgot-password');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'نسيت كلمة المرور؟',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    MouseRegion(
                      onEnter: (_) => setState(() => _isCreateAccountHovered = true),
                      onExit: (_) => setState(() => _isCreateAccountHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _isCreateAccountHovered 
                              ? colorScheme.primary 
                              : colorScheme.primary.withOpacity(0.3),
                            width: _isCreateAccountHovered ? 3 : 2,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/user-type-selection');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'إنشاء حساب',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MouseRegion(
                      onEnter: (_) => setState(() => _isCreateAccountHovered = true),
                      onExit: (_) => setState(() => _isCreateAccountHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _isCreateAccountHovered 
                              ? colorScheme.primary 
                              : colorScheme.primary.withOpacity(0.3),
                            width: _isCreateAccountHovered ? 3 : 2,
                          ),
                        ),
                        child: Consumer<AuthState>(
                          builder: (context, authState,_) {
                            return TextButton(
                              onPressed: () async {
                                  try {
                                      await authState.loginAsGuest();
                                      if (context.mounted) {
                                        Navigator.pushReplacementNamed(context, '/main');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'جرب التطبيق',
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary,
                                ),
                              ),
                            );
                          }
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool isPassword = false,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: colorScheme.primary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
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
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      validator: validator,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }
} 