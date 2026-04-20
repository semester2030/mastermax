import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'كيف يمكنني إنشاء حساب جديد؟',
      answer: 'يمكنك إنشاء حساب جديد عن طريق الضغط على زر "تسجيل" في الشاشة الرئيسية ثم اتباع الخطوات المطلوبة لإكمال عملية التسجيل.',
      icon: Icons.person_add,
    ),
    FAQItem(
      question: 'كيف يمكنني تغيير كلمة المرور الخاصة بي؟',
      answer: 'يمكنك تغيير كلمة المرور من خلال الذهاب إلى صفحة الملف الشخصي، ثم الضغط على "إعدادات الحساب" واختيار "تغيير كلمة المرور".',
      icon: Icons.lock,
    ),
    FAQItem(
      question: 'كيف يمكنني الإعلان عن سيارتي؟',
      answer: 'يمكنك إضافة إعلان جديد عن طريق الضغط على زر "+" في الشاشة الرئيسية، ثم اختيار "إضافة إعلان" واتباع الخطوات المطلوبة.',
      icon: Icons.directions_car,
    ),
    FAQItem(
      question: 'ما هي مميزات الإعلان المميز؟',
      answer: 'الإعلان المميز يظهر في أعلى نتائج البحث ويحصل على مشاهدات أكثر. كما يتميز بتصميم خاص وإمكانية إضافة المزيد من الصور ومقاطع الفيديو.',
      icon: Icons.workspace_premium,
    ),
    FAQItem(
      question: 'كيف يمكنني التواصل مع الدعم الفني؟',
      answer: 'يمكنك التواصل مع الدعم الفني من خلال المحادثة المباشرة، أو إنشاء تذكرة دعم فني، أو التواصل معنا عبر معلومات الاتصال المتوفرة.',
      icon: Icons.support_agent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: const Text(
          'الأسئلة الشائعة',
          style: TextStyle(
            color: AppColors.brightGold,
            fontSize: 20,
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
              ColorUtils.withOpacity(AppColors.skyBlue, 0.7),
              ColorUtils.withOpacity(AppColors.royalPurple, 0.7),
            ],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _faqItems.length,
          itemBuilder: (context, index) {
            return custom_animations.AnimatedScale(
              onTap: () {},
              child: Container(
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
                    color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(AppColors.royalPurple, 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: AppColors.transparent,
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.brightGold,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: custom_animations.AnimatedGlow(
                      glowColor: AppColors.brightGold,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                          border: Border.all(
                            color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                          ),
                        ),
                        child: Icon(
                          _faqItems[index].icon,
                          color: AppColors.brightGold,
                        ),
                      ),
                    ),
                    title: custom_animations.ShimmerLoading(
                      baseColor: ColorUtils.withOpacity(AppColors.brightGold, 0.5),
                      highlightColor: AppColors.brightGold,
                      child: Text(
                        _faqItems[index].question,
                        style: const TextStyle(
                          color: AppColors.brightGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                              ColorUtils.withOpacity(AppColors.brightGold, 0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          _faqItems[index].answer,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: custom_animations.AnimatedScale(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('سيتم فتح المحادثة المباشرة قريباً'),
              backgroundColor: AppColors.royalPurple,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brightGold,
                ColorUtils.withOpacity(AppColors.brightGold, 0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.chat,
            color: AppColors.royalPurple,
          ),
        ),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;
  final IconData icon;

  FAQItem({
    required this.question,
    required this.answer,
    required this.icon,
  });
} 