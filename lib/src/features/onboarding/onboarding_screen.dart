import 'package:flutter/material.dart';

import '../../core/constants/app_brand.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../shared/widgets/app_brand_logo_header.dart';

/// ثلاث شاشات ترحيب — بدون تخطي وبدون وضع زائر.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onLoginChosen,
    required this.onRegisterChosen,
  });

  final Future<void> Function() onLoginChosen;
  final Future<void> Function() onRegisterChosen;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;
  static const int _pageCount = 3;

  void _goNext() {
    if (_index < _pageCount - 1) {
      setState(() => _index++);
    }
  }

  void _goBack() {
    if (_index > 0) {
      setState(() => _index--);
    }
  }

  Future<void> _onLoginTap() async {
    await widget.onLoginChosen();
  }

  Future<void> _onRegisterTap() async {
    await widget.onRegisterChosen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ColorUtils.withOpacity(AppColors.primary, 0.08),
                AppColors.background,
              ],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    if (_index > 0)
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        color: AppColors.primary,
                        tooltip: 'السابق',
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    Text(
                      '${_index + 1} / $_pageCount',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_index),
                    child: _buildPage(_index),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    _buildDots(),
                    const SizedBox(height: 20),
                    if (_index < _pageCount - 1) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            'التالي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _onLoginTap,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _onRegisterTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'إنشاء حساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (i) {
        final active = i == _index;
        return GestureDetector(
          onTap: () => setState(() => _index = i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: active
                  ? AppColors.primary
                  : ColorUtils.withOpacity(AppColors.primary, 0.22),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPage(int i) {
    switch (i) {
      case 0:
        return _OnboardingPage(
          iconRow: _iconPair(
            Icons.home_work_rounded,
            Icons.directions_car_rounded,
          ),
          title: 'عقارات وسيارات في منصة واحدة',
          body:
              'تصفّح الإعلانات والعروض من مكان واحد بسيط وسريع يجمع الجودة والثقة.',
        );
      case 1:
        return _OnboardingPage(
          iconRow: _iconPair(
            Icons.play_circle_fill_rounded,
            Icons.map_rounded,
          ),
          title: 'شاهد على الخريطة وتقرّر بثقة',
          body:
              'فيديوهات تفاعلية وخريطة ذكية تربطك بما يهمك حولك وتساعدك على الاختيار.',
        );
      case 2:
      default:
        return _OnboardingPage(
          showLogo: true,
          title: 'ابدأ الآن مع ${AppBrand.displayName}',
          body:
              'أنشئ حسابك أو سجّل دخولك واستكشف العقارات والسيارات بطريقة حديثة.',
        );
    }
  }

  Widget _iconPair(IconData a, IconData b) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconCircle(a),
        const SizedBox(width: 20),
        _iconCircle(b),
      ],
    );
  }

  Widget _iconCircle(IconData icon) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradientPrimary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: AppColors.white),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.body,
    this.iconRow,
    this.showLogo = false,
  });

  final String title;
  final String body;
  final Widget? iconRow;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (showLogo) ...[
            const AppBrandLogoHeader(
              margin: EdgeInsets.only(bottom: 8),
              maxWidth: 220,
            ),
            const SizedBox(height: 20),
          ],
          if (iconRow != null) ...[
            iconRow!,
            const SizedBox(height: 32),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.28),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
