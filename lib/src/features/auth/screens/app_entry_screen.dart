import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_brand_logo_header.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../onboarding/onboarding_storage.dart';
import 'login_screen.dart';

/// نقطة الدخول: تحميل حالة الترحيب ثم إما [OnboardingScreen] أو [LoginScreen].
class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _loaded = false;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await OnboardingStorage.isCompleted();
    if (!mounted) return;
    setState(() {
      _onboardingDone = done;
      _loaded = true;
    });
  }

  Future<void> _completeOnboardingLogin() async {
    await OnboardingStorage.setCompleted();
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  Future<void> _completeOnboardingRegister() async {
    await OnboardingStorage.setCompleted();
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed('/user-type-selection');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppBrandLogoHeader(maxWidth: 200),
              const SizedBox(height: 28),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_onboardingDone) {
      return OnboardingScreen(
        onLoginChosen: _completeOnboardingLogin,
        onRegisterChosen: _completeOnboardingRegister,
      );
    }

    return const LoginScreen();
  }
}
