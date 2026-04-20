import 'package:flutter/material.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/app_colors.dart';

class PremiumAdsScreen extends StatefulWidget {
  const PremiumAdsScreen({super.key});

  @override
  State<PremiumAdsScreen> createState() => _PremiumAdsScreenState();
}

class _PremiumAdsScreenState extends State<PremiumAdsScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
              ],
            ),
          ),
        ),
        title: custom_animations.ShimmerLoading(
          baseColor: ColorUtils.withOpacity(colorScheme.tertiary, 0.5),
          highlightColor: colorScheme.tertiary,
          child: Text(
            'الإعلانات المميزة',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(colorScheme.primary, 0.1),
              ColorUtils.withOpacity(colorScheme.secondary, 0.1),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildPremiumPackages(context),
              const SizedBox(height: 24),
              _buildFeatures(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return custom_animations.AnimatedScale(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorUtils.withOpacity(colorScheme.primary, 0.2),
              ColorUtils.withOpacity(colorScheme.secondary, 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorUtils.withOpacity(colorScheme.tertiary, 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            custom_animations.AnimatedGlow(
              glowColor: colorScheme.tertiary,
              child: Icon(
                Icons.workspace_premium,
                size: 64,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اجعل إعلاناتك مميزة',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'احصل على مشاهدات أكثر وعملاء محتملين',
              style: textTheme.bodyLarge?.copyWith(
                color: ColorUtils.withOpacity(colorScheme.onSurface, 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPackages(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'باقات الإعلانات المميزة',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPackageCard(
                context,
                'باقة أساسية',
                '99',
                ['ظهور مميز لمدة 7 أيام', 'أولوية في نتائج البحث', 'تقارير المشاهدات'],
                colorScheme.primary,
              ),
              _buildPackageCard(
                context,
                'باقة احترافية',
                '199',
                [
                  'ظهور مميز لمدة 15 يوم',
                  'أولوية قصوى في البحث',
                  'تقارير تفصيلية',
                  'دعم مخصص'
                ],
                colorScheme.secondary,
              ),
              _buildPackageCard(
                context,
                'باقة الأعمال',
                '499',
                [
                  'ظهور مميز لمدة 30 يوم',
                  'أعلى أولوية في البحث',
                  'تقارير متقدمة',
                  'دعم مخصص على مدار الساعة',
                  'تصميم إعلان احترافي'
                ],
                colorScheme.tertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    String title,
    String price,
    List<String> features,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return custom_animations.AnimatedScale(
      onTap: () {
        // TODO: Implement package selection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('سيتم تفعيل هذه الميزة قريباً'),
            backgroundColor: colorScheme.primary,
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorUtils.withOpacity(color, 0.2),
              ColorUtils.withOpacity(color, 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorUtils.withOpacity(color, 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            custom_animations.AnimatedGlow(
              glowColor: color,
              child: Text(
                '$price ريال',
                style: textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      custom_animations.AnimatedGlow(
                        glowColor: color,
                        child: Icon(Icons.check_circle, color: color, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: textTheme.bodyMedium?.copyWith(
                            color: ColorUtils.withOpacity(colorScheme.onSurface, 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'مميزات الإعلانات المميزة',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildFeatureCard(
              context,
              Icons.visibility,
              'ظهور مميز',
              'إعلانك يظهر في أعلى نتائج البحث',
              colorScheme.primary,
            ),
            _buildFeatureCard(
              context,
              Icons.analytics,
              'تقارير متقدمة',
              'احصل على إحصائيات مفصلة عن مشاهدات إعلانك',
              colorScheme.secondary,
            ),
            _buildFeatureCard(
              context,
              Icons.support_agent,
              'دعم مخصص',
              'فريق الدعم الفني جاهز لمساعدتك على مدار الساعة',
              colorScheme.tertiary,
            ),
            _buildFeatureCard(
              context,
              Icons.design_services,
              'تصميم احترافي',
              'تصميم إعلانك بشكل احترافي يجذب العملاء',
              colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorUtils.withOpacity(color, 0.2),
            ColorUtils.withOpacity(color, 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorUtils.withOpacity(color, 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          custom_animations.AnimatedGlow(
            glowColor: color,
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: ColorUtils.withOpacity(colorScheme.onSurface, 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 