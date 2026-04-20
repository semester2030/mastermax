import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/constants/app_brand.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../customer_service/screens/customer_service_screen.dart';
import '../../customer_service/screens/faq_screen.dart';
import '../../spotlight/providers/video_provider.dart';
import '../providers/app_user_settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: Text(
          'إعدادات ${AppBrand.displayName}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          custom_animations.AnimatedScale(
            onTap: _resetSettings,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorUtils.withOpacity(AppColors.textPrimary, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
                ),
              ),
              child: const Icon(Icons.restore, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(AppColors.primary, 0.1),
              ColorUtils.withOpacity(AppColors.background, 0.1),
            ],
          ),
        ),
        child: Consumer<AppUserSettingsProvider>(
          builder: (context, settings, _) {
            final qualityLabel =
                AppUserSettingsProvider.videoQualityLabelAr(settings.videoQuality);
            final privacyLabel =
                AppUserSettingsProvider.privacyLabelAr(settings.defaultPrivacy);
            final threshold = settings.viewsNotificationThreshold;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('إعدادات العرض', Icons.settings),
                _buildSettingsCard([
                  _buildSwitchTile(
                    icon: Icons.play_circle_fill,
                    title: 'تشغيل تلقائي للفيديوهات',
                    subtitle: 'تشغيل الفيديوهات تلقائياً عند التصفح',
                    value: settings.autoPlayVideos,
                    onChanged: settings.setAutoPlayVideos,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.visibility,
                    title: 'عرض عدد المشاهدات',
                    subtitle: 'إظهار عدد المشاهدات على الفيديوهات',
                    value: settings.showViewsCount,
                    onChanged: settings.setShowViewsCount,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.high_quality,
                    title: 'جودة الفيديو',
                    subtitle: 'الجودة الحالية: $qualityLabel',
                    onTap: _showQualityDialog,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.branding_watermark,
                    title: 'علامة مائية',
                    subtitle: 'إضافة شعار ${AppBrand.displayName} للفيديوهات',
                    value: settings.enableWatermarkVideos,
                    onChanged: settings.setEnableWatermarkVideos,
                  ),
                ]),

                _buildSectionTitle('إعدادات المحتوى', Icons.video_library),
                _buildSettingsCard([
                  _buildSwitchTile(
                    icon: Icons.location_on,
                    title: 'المحتوى حسب الموقع',
                    subtitle: 'عرض محتوى مخصص حسب موقعك',
                    value: settings.locationBasedContent,
                    onChanged: settings.setLocationBasedContent,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.save,
                    title: 'حفظ تلقائي',
                    subtitle: 'حفظ مسودات الفيديوهات تلقائياً',
                    value: settings.autoSaveDrafts,
                    onChanged: settings.setAutoSaveDrafts,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.privacy_tip,
                    title: 'خصوصية الفيديوهات الافتراضية',
                    subtitle: 'الإعداد الحالي: $privacyLabel',
                    onTap: _showPrivacyDialog,
                  ),
                ]),

                _buildSectionTitle('إعدادات الإشعارات', Icons.notifications),
                _buildSettingsCard([
                  _buildSwitchTile(
                    icon: Icons.remove_red_eye,
                    title: 'إشعارات المشاهدات',
                    subtitle: 'تنبيه عند وصول المشاهدات إلى $threshold',
                    value: settings.notifyNewViews,
                    onChanged: settings.setNotifyNewViews,
                  ),
                  if (settings.notifyNewViews) ...[
                    _buildDivider(),
                    _buildActionTile(
                      icon: Icons.tune,
                      title: 'حد التنبيه',
                      subtitle: '$threshold مشاهدة',
                      onTap: _showThresholdDialog,
                    ),
                  ],
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.comment,
                    title: 'إشعارات التعليقات',
                    subtitle: 'تنبيهات عند تلقي تعليقات جديدة',
                    value: settings.notifyComments,
                    onChanged: settings.setNotifyComments,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.thumb_up,
                    title: 'إشعارات الإعجابات',
                    subtitle: 'تنبيهات عند تلقي إعجابات جديدة',
                    value: settings.notifyLikes,
                    onChanged: settings.setNotifyLikes,
                  ),
                ]),

                _buildSectionTitle('الدعم والمساعدة', Icons.help),
                _buildSettingsCard([
                  _buildActionTile(
                    icon: Icons.help_outline,
                    title: 'دليل الاستخدام',
                    subtitle: 'تعلم كيفية استخدام ${AppBrand.displayName}',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const FAQScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.support_agent,
                    title: 'الدعم الفني',
                    subtitle: 'تواصل مع فريق الدعم',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CustomerServiceScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.info_outline,
                    title: 'عن ${AppBrand.displayName}',
                    subtitle: 'معلومات عن ${AppBrand.displayName} والإصدار',
                    onTap: _showAboutDialog,
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorUtils.withOpacity(AppColors.primary, 0.2),
            ColorUtils.withOpacity(AppColors.background, 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorUtils.withOpacity(AppColors.textPrimary, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: value
                      ? [
                          ColorUtils.withOpacity(AppColors.primary, 0.8),
                        ]
                      : [
                          ColorUtils.withOpacity(AppColors.primaryLight, 0.5),
                          ColorUtils.withOpacity(AppColors.background, 0.5),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: value ? 24 : 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorUtils.withOpacity(AppColors.textPrimary, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: ColorUtils.withOpacity(AppColors.textPrimary, 0.2));
  }

  Future<void> _resetSettings() async {
    final settings = context.read<AppUserSettingsProvider>();
    await settings.resetToDefaults();
    if (!mounted) return;
    await context.read<VideoProvider>().setVideoQuality(settings.videoQuality);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم استعادة الإعدادات الافتراضية'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showQualityDialog() {
    final rootContext = context;
    final settings = context.read<AppUserSettingsProvider>();
    final currentLabel =
        AppUserSettingsProvider.videoQualityLabelAr(settings.videoQuality);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text(
          'اختر جودة الفيديو',
          style: TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption(
                dialogContext, rootContext, settings, currentLabel, 'عالية'),
            _buildQualityOption(
                dialogContext, rootContext, settings, currentLabel, 'متوسطة'),
            _buildQualityOption(
                dialogContext, rootContext, settings, currentLabel, 'منخفضة'),
            _buildQualityOption(
                dialogContext, rootContext, settings, currentLabel, 'تلقائي'),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(
    BuildContext dialogContext,
    BuildContext rootContext,
    AppUserSettingsProvider settings,
    String currentQualityLabel,
    String optionLabel,
  ) {
    final selected = currentQualityLabel == optionLabel;
    return InkWell(
      onTap: () async {
        final q = AppUserSettingsProvider.videoQualityFromLabelAr(optionLabel);
        await settings.setVideoQuality(q);
        if (!rootContext.mounted) return;
        await rootContext.read<VideoProvider>().setVideoQuality(q);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [
                    ColorUtils.withOpacity(AppColors.primaryLight, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.white, 0.1),
                    ColorUtils.withOpacity(AppColors.white, 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
          ),
        ),
        child: Text(
          optionLabel,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    final settings = context.read<AppUserSettingsProvider>();
    final currentLabel =
        AppUserSettingsProvider.privacyLabelAr(settings.defaultPrivacy);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text(
          'اختر خصوصية الفيديوهات',
          style: TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPrivacyOption(
                dialogContext, settings, currentLabel, 'عام'),
            _buildPrivacyOption(
                dialogContext, settings, currentLabel, 'خاص'),
            _buildPrivacyOption(
                dialogContext, settings, currentLabel, 'مخصص'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(
    BuildContext dialogContext,
    AppUserSettingsProvider settings,
    String currentPrivacyLabel,
    String optionLabel,
  ) {
    final selected = currentPrivacyLabel == optionLabel;
    return InkWell(
      onTap: () async {
        final code =
            AppUserSettingsProvider.privacyCodeFromLabelAr(optionLabel);
        await settings.setDefaultPrivacyCode(code);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [
                    ColorUtils.withOpacity(AppColors.primaryLight, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.white, 0.1),
                    ColorUtils.withOpacity(AppColors.white, 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
          ),
        ),
        child: Text(
          optionLabel,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showThresholdDialog() {
    final settings = context.read<AppUserSettingsProvider>();
    final current = settings.viewsNotificationThreshold;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text(
          'حد تنبيهات المشاهدات',
          style: TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThresholdOption(dialogContext, settings, current, 1000),
            _buildThresholdOption(dialogContext, settings, current, 5000),
            _buildThresholdOption(dialogContext, settings, current, 10000),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdOption(
    BuildContext dialogContext,
    AppUserSettingsProvider settings,
    int currentThreshold,
    int threshold,
  ) {
    final selected = currentThreshold == threshold;
    return InkWell(
      onTap: () async {
        await settings.setViewsNotificationThreshold(threshold);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [
                    ColorUtils.withOpacity(AppColors.primaryLight, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.white, 0.1),
                    ColorUtils.withOpacity(AppColors.white, 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.white, 0.3),
          ),
        ),
        child: Text(
          '$threshold مشاهدة',
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: AppBrand.displayName,
      applicationVersion: info.version,
      applicationLegalese: '© ${AppBrand.displayName}',
      children: [
        Text('رقم البناء: ${info.buildNumber}'),
      ],
    );
  }
}
