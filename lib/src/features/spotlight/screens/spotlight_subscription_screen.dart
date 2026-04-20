import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../models/spotlight_plan.dart';
import 'package:mastermax_2030/src/core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  final _subscriptionService = SubscriptionService();
  bool _isLoading = false;
  SpotlightPlan? _selectedPlan;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubscription(SpotlightPlan plan) async {
    try {
      setState(() {
        _isLoading = true;
        _selectedPlan = plan;
      });
      
      final paymentMethod = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const Text(
                'اختر طريقة الدفع',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.credit_card, color: AppColors.accent),
                title: const Text(
                  'الدفع ببطاقة مدى',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 16,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'mada'),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.account_balance, color: AppColors.accent),
                title: const Text(
                  'تحويل بنكي',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 16,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'bank'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (paymentMethod == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final result = await _subscriptionService.subscribe(
        planId: plan.id,
        paymentMethod: paymentMethod,
        amount: plan.price,
      );
      
      if (!mounted) return;
      
      if (result.success) {
        if (paymentMethod == 'bank') {
          _showBankDetails(plan);
        } else if (paymentMethod == 'mada') {
          Navigator.of(context).pushReplacementNamed(
            '/spotlight/payments/mada',
            arguments: plan
          );
        }
      } else {
        _showErrorDialog(result.message ?? 'حدث خطأ');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('حدث خطأ أثناء الاشتراك');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.spotlightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: const Text(
          'باقات الاشتراك',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.spotlightBorder,
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.star,
                    color: AppColors.accent,
                    size: 60,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'اختر الباقة المناسبة لك',
                    style: TextStyle(
                      color: AppColors.spotlightText,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'استمتع بجميع المميزات مع باقاتنا المتنوعة',
                    style: TextStyle(
                      color: AppColors.spotlightText,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ...SpotlightPlan.plans.map((plan) => _buildSubscriptionCard(plan)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(SpotlightPlan plan) {
    final isSelected = _selectedPlan == plan;
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.spotlightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : () => _handleSubscription(plan),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: AppColors.spotlightText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ColorUtils.withOpacity(AppColors.accent, 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${plan.price} ريال',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...plan.features.map((feature) => _buildFeatureItem(feature)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleSubscription(plan),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'جاري المعالجة...' : 'اشترك الآن',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                color: AppColors.spotlightText,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text(
          'خطأ',
          style: TextStyle(color: AppColors.accent),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.spotlightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showBankDetails(SpotlightPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.accent, 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تفاصيل التحويل البنكي',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildBankDetailItem('اسم البنك', 'البنك الأهلي السعودي'),
                  _buildBankDetailItem('اسم الحساب', 'شركة ماستر ماكس'),
                  _buildBankDetailItem('رقم الحساب', 'SA1234567890123456789012'),
                  _buildBankDetailItem('المبلغ المطلوب', '${plan.price} ريال'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'بعد إتمام التحويل، يرجى إرسال صورة من إيصال التحويل عبر الواتساب على الرقم: 0500000000',
                style: TextStyle(
                  color: AppColors.spotlightText,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacementNamed(
                    '/spotlight/payments/confirmation',
                    arguments: {
                      'plan': plan,
                      'success': true,
                      'message': 'تم استلام طلب التحويل البنكي'
                    }
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'تم فهم التعليمات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.secondary, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.spotlightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.spotlightText,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 