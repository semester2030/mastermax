import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الشعار
                custom_animations.AnimatedGlow(
                  glowColor: colorScheme.primary.withOpacity(0.15),
                  maxRadius: 30,
                  duration: const Duration(seconds: 2),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.secondary, width: 2),
                    ),
                    child: Icon(
                      Icons.star,
                      size: 80,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                custom_animations.ShimmerLoading(
                  baseColor: colorScheme.onPrimary,
                  highlightColor: colorScheme.secondary,
                  child: Text(
                    'MASTER MAX',
                    style: textTheme.displayMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // جرب التطبيق
                Consumer<AuthState>(
                  builder: (context, authState, child) {
                    return SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () async {
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: authState.isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSecondary),
                                ),
                              )
                            : Text(
                                'جرب التطبيق',
                                style: textTheme.titleLarge?.copyWith(color: colorScheme.onSecondary),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // تسجيل الدخول
                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'تسجيل الدخول',
                      style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // إنشاء حساب جديد
                SizedBox(
                  width: 300,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(color: colorScheme.onPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'إنشاء حساب جديد',
                      style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
                    ),
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