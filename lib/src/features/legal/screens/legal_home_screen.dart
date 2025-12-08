import 'package:flutter/material.dart';
import '../widgets/legal_card_widget.dart';
import '../services/legal_navigation_service.dart';
import '../../../core/utils/color_utils.dart';

class LegalHomeScreen extends StatelessWidget {
  const LegalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السياسات والشروط'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(Theme.of(context).primaryColor, 0.05),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'مرحباً بك في مركز السياسات والشروط',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'يمكنك الاطلاع على جميع السياسات والشروط الخاصة بالمنصة',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LegalCardWidget(
                title: 'سياسة الخصوصية',
                subtitle: 'تعرف على كيفية حماية بياناتك وخصوصيتك',
                icon: Icons.privacy_tip_outlined,
                onTap: () => LegalNavigationService.navigateToPrivacyPolicy(context),
              ),
              LegalCardWidget(
                title: 'حقوق الملكية الفكرية',
                subtitle: 'معلومات عن حقوق الملكية والعلامات التجارية',
                icon: Icons.copyright_outlined,
                onTap: () => LegalNavigationService.navigateToIntellectualProperty(context),
              ),
              LegalCardWidget(
                title: 'شروط الاستخدام',
                subtitle: 'الشروط والأحكام العامة لاستخدام المنصة',
                icon: Icons.description_outlined,
                onTap: () => LegalNavigationService.navigateToTermsOfUse(context),
              ),
              LegalCardWidget(
                title: 'آلية الشكاوى',
                subtitle: 'كيفية تقديم وحل الشكاوى',
                icon: Icons.support_agent_outlined,
                onTap: () => LegalNavigationService.navigateToComplaints(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 