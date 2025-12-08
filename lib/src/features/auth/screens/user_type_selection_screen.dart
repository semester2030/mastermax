import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_type.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  UserType? _selectedType;
  final Map<UserType, bool> _hoveredStates = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    for (var type in UserType.values) {
      _hoveredStates[type] = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToRegister(BuildContext context, UserType userType) async {
    setState(() => _selectedType = userType);
    await _controller.forward();
    if (!mounted) return;
    Navigator.pushNamed(context, '/register', arguments: userType);
    _controller.reset();
    setState(() => _selectedType = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Center(
                child: custom_animations.AnimatedGlow(
                  glowColor: colorScheme.primary.withOpacity(0.15),
                  maxRadius: 30,
                  duration: const Duration(seconds: 2),
                  child: Container(
                    height: 180,
                    width: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.outline.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logos/master_max_logo.svg',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر نوع الحساب',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_selectedType == null)
                Column(
                  children: [
                    _buildTypeButton(
                      title: 'معرض سيارات',
                      icon: Icons.directions_car,
                      userType: UserType.carDealer,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _buildTypeButton(
                      title: 'شركة عقارية',
                      icon: Icons.business,
                      userType: UserType.realEstateCompany,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _buildTypeButton(
                      title: 'وسيط عقاري',
                      icon: Icons.real_estate_agent,
                      userType: UserType.realEstateAgent,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _buildTypeButton(
                      title: 'تاجر سيارات',
                      icon: Icons.car_rental,
                      userType: UserType.carTrader,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 16),
                    _buildTypeButton(
                      title: 'حساب فردي',
                      icon: Icons.person,
                      userType: UserType.individual,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String title,
    required IconData icon,
    required UserType userType,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final isHovered = _hoveredStates[userType] ?? false;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredStates[userType] = true),
      onExit: (_) => setState(() => _hoveredStates[userType] = false),
      child: custom_animations.AnimatedScale(
        scale: isHovered ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isHovered ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
              width: isHovered ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.outline.withOpacity(0.1),
                blurRadius: isHovered ? 8 : 4,
                spreadRadius: isHovered ? 2 : 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToRegister(context, userType),
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      icon,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 