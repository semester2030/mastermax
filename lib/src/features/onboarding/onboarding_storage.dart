import 'package:shared_preferences/shared_preferences.dart';

/// حفظ إكمال شاشة الترحيب (مرة واحدة لكل جهاز).
class OnboardingStorage {
  OnboardingStorage._();

  static const String _key = 'dk_onboarding_completed';

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> setCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}
