import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // متغيرات إعدادات العرض
  bool _autoPlayVideos = true;
  bool _showViewsCount = true;
  String _videoQuality = 'عالية';
  bool _enableWatermark = true;

  // متغيرات إعدادات المحتوى
  bool _enableLocationBasedContent = true;
  bool _enableAutoSave = true;
  String _defaultPrivacy = 'عام';

  // متغيرات إعدادات الإشعارات
  bool _notifyNewViews = true;
  bool _notifyComments = true;
  bool _notifyLikes = true;
  int _viewsNotificationThreshold = 1000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'إعدادات أضواء ماكس',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent),
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
                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.accent, 0.3),
                ),
              ),
              child: const Icon(Icons.restore, color: AppColors.accent),
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
              ColorUtils.withOpacity(AppColors.royalPurple, 0.1),
              ColorUtils.withOpacity(AppColors.skyBlue, 0.1),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // إعدادات العرض
            _buildSectionTitle('إعدادات العرض', Icons.settings),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.play_circle_fill,
                title: 'تشغيل تلقائي للفيديوهات',
                subtitle: 'تشغيل الفيديوهات تلقائياً عند التصفح',
                value: _autoPlayVideos,
                onChanged: (value) => setState(() => _autoPlayVideos = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.visibility,
                title: 'عرض عدد المشاهدات',
                subtitle: 'إظهار عدد المشاهدات على الفيديوهات',
                value: _showViewsCount,
                onChanged: (value) => setState(() => _showViewsCount = value),
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.high_quality,
                title: 'جودة الفيديو',
                subtitle: 'الجودة الحالية: $_videoQuality',
                onTap: _showQualityDialog,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.branding_watermark,
                title: 'علامة مائية',
                subtitle: 'إضافة شعار أضواء ماكس للفيديوهات',
                value: _enableWatermark,
                onChanged: (value) => setState(() => _enableWatermark = value),
              ),
            ]),

            // إعدادات المحتوى
            _buildSectionTitle('إعدادات المحتوى', Icons.video_library),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.location_on,
                title: 'المحتوى حسب الموقع',
                subtitle: 'عرض محتوى مخصص حسب موقعك',
                value: _enableLocationBasedContent,
                onChanged: (value) => setState(() => _enableLocationBasedContent = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.save,
                title: 'حفظ تلقائي',
                subtitle: 'حفظ مسودات الفيديوهات تلقائياً',
                value: _enableAutoSave,
                onChanged: (value) => setState(() => _enableAutoSave = value),
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.privacy_tip,
                title: 'خصوصية الفيديوهات الافتراضية',
                subtitle: 'الإعداد الحالي: $_defaultPrivacy',
                onTap: _showPrivacyDialog,
              ),
            ]),

            // إعدادات الإشعارات
            _buildSectionTitle('إعدادات الإشعارات', Icons.notifications),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.remove_red_eye,
                title: 'إشعارات المشاهدات',
                subtitle: 'تنبيه عند وصول المشاهدات إلى $_viewsNotificationThreshold',
                value: _notifyNewViews,
                onChanged: (value) => setState(() => _notifyNewViews = value),
              ),
              if (_notifyNewViews) ...[
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.tune,
                  title: 'حد التنبيه',
                  subtitle: '$_viewsNotificationThreshold مشاهدة',
                  onTap: _showThresholdDialog,
                ),
              ],
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.comment,
                title: 'إشعارات التعليقات',
                subtitle: 'تنبيهات عند تلقي تعليقات جديدة',
                value: _notifyComments,
                onChanged: (value) => setState(() => _notifyComments = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.thumb_up,
                title: 'إشعارات الإعجابات',
                subtitle: 'تنبيهات عند تلقي إعجابات جديدة',
                value: _notifyLikes,
                onChanged: (value) => setState(() => _notifyLikes = value),
              ),
            ]),

            // الدعم والمساعدة
            _buildSectionTitle('الدعم والمساعدة', Icons.help),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.help_outline,
                title: 'دليل الاستخدام',
                subtitle: 'تعلم كيفية استخدام أضواء ماكس',
                onTap: () {
                  // عرض دليل الاستخدام
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.support_agent,
                title: 'الدعم الفني',
                subtitle: 'تواصل مع فريق الدعم',
                onTap: () {
                  // فتح صفحة الدعم الفني
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.info_outline,
                title: 'عن أضواء ماكس',
                subtitle: 'معلومات عن التطبيق والإصدار',
                onTap: () {
                  // عرض معلومات التطبيق
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
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
            ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
            ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.accent, 0.3),
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
    required ValueChanged<bool> onChanged,
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
                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.accent, 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textLight,
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
                          ColorUtils.withOpacity(AppColors.accent, 0.8),
                        ]
                      : [
                          ColorUtils.withOpacity(AppColors.royalPurple, 0.5),
                          ColorUtils.withOpacity(AppColors.skyBlue, 0.5),
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
                color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.accent, 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: ColorUtils.withOpacity(AppColors.accent, 0.2));
  }

  void _resetSettings() {
    setState(() {
      _autoPlayVideos = true;
      _showViewsCount = true;
      _videoQuality = 'عالية';
      _enableWatermark = true;
      _enableLocationBasedContent = true;
      _enableAutoSave = true;
      _defaultPrivacy = 'عام';
      _notifyNewViews = true;
      _notifyComments = true;
      _notifyLikes = true;
      _viewsNotificationThreshold = 1000;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم استعادة الإعدادات الافتراضية'),
        backgroundColor: AppColors.royalPurple,
      ),
    );
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.royalPurple,
        title: const Text(
          'اختر جودة الفيديو',
          style: TextStyle(color: AppColors.accent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption('عالية'),
            _buildQualityOption('متوسطة'),
            _buildQualityOption('منخفضة'),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String quality) {
    return InkWell(
      onTap: () {
        setState(() => _videoQuality = quality);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _videoQuality == quality
                ? [
                    ColorUtils.withOpacity(AppColors.accent, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
                    ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Text(
          quality,
          style: TextStyle(
            color: _videoQuality == quality
                ? AppColors.royalPurple
                : AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.royalPurple,
        title: const Text(
          'اختر خصوصية الفيديوهات',
          style: TextStyle(color: AppColors.accent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPrivacyOption('عام'),
            _buildPrivacyOption('خاص'),
            _buildPrivacyOption('مخصص'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String privacy) {
    return InkWell(
      onTap: () {
        setState(() => _defaultPrivacy = privacy);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _defaultPrivacy == privacy
                ? [
                    ColorUtils.withOpacity(AppColors.accent, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
                    ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Text(
          privacy,
          style: TextStyle(
            color: _defaultPrivacy == privacy
                ? AppColors.royalPurple
                : AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showThresholdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.royalPurple,
        title: const Text(
          'حد تنبيهات المشاهدات',
          style: TextStyle(color: AppColors.accent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThresholdOption(1000),
            _buildThresholdOption(5000),
            _buildThresholdOption(10000),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdOption(int threshold) {
    return InkWell(
      onTap: () {
        setState(() => _viewsNotificationThreshold = threshold);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _viewsNotificationThreshold == threshold
                ? [
                    ColorUtils.withOpacity(AppColors.accent, 0.8),
                  ]
                : [
                    ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
                    ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.accent, 0.3),
          ),
        ),
        child: Text(
          '$threshold مشاهدة',
          style: TextStyle(
            color: _viewsNotificationThreshold == threshold
                ? AppColors.royalPurple
                : AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 