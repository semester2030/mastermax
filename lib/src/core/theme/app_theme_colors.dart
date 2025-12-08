import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/color_utils.dart';

class AppThemeColors {
  // الألوان الأساسية
  static const Color primary = Color(0xFF000B3B);  // Glossy navy blue
  static const Color secondary = Color(0xFF000B3B);
  static const Color accent = Color(0xFF000B3B);

  // ألوان الخلفية
  static const Color background = Color(0xFFFFFFFF);  // Pure white
  static const Color backgroundDark = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  // ألوان النصوص
  static const Color textPrimary = Color(0xFF000000);  // Glossy black for headers
  static const Color textSecondary = Color(0xFF1A1A1A);  // Slightly lighter black
  static const Color textLight = Color(0xFF333333);

  // ألوان الحالات المختلفة
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFACC15);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ألوان الظلال والحدود
  static const Color border = Color(0xFF000B3B);  // Glossy navy blue
  static Color shadow = ColorUtils.withOpacity(const Color(0xFF000B3B), 0.1);
  static Color shadowDark = ColorUtils.withOpacity(const Color(0xFF000B3B), 0.2);

  // تدرجات الألوان
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF000B3B), Color(0xFF001463)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF000728), Color(0xFF000B3B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // الألوان الرئيسية للعلامة التجارية
  static const brand = {
    'primaryBlue': Color(0xFF000B3B),    // Glossy navy blue
    'primaryIndigo': Color(0xFF000728),   // Darker navy
    'darkNavy': Color(0xFF000514),        // Darkest navy
  };

  // ألوان واجهة المستخدم
  static const interface = {
    'surface': Color(0xFFFFFFFF),      // Pure white
    'surfaceLight': Color(0xFFFFFFFF), // Pure white
    'lightGray': Color(0xFFFFFFFF),    // Pure white
    'mediumGray': Color(0xFF000B3B),   // Glossy navy blue for borders
    'darkGray': Color(0xFF000000),     // Glossy black for text
  };

  // ألوان التصنيفات
  static const categories = {
    'realEstate': Color(0xFF0EA5E9),  // قسم العقارات
    'cars': Color(0xFF475569),        // قسم السيارات
  };

  // ألوان الإجراءات
  static const actions = {
    'success': Color(0xFF10B981),   // نجاح - أخضر
    'error': Color(0xFFEF4444),     // خطأ - أحمر
    'warning': Color(0xFFF59E0B),   // تحذير - برتقالي
    'info': Color(0xFF3B82F6),      // معلومات - أزرق
  };

  // الشفافيات
  static final overlays = {
    'light': ColorUtils.withOpacity(Colors.white, 0.1),
    'medium': ColorUtils.withOpacity(Colors.white, 0.3),
    'dark': ColorUtils.withOpacity(Colors.black, 0.5),
  };

  // ألوان خاصة بالميزات المميزة
  static const spotlight = {
    'gold': Color(0xFFFFD700),      // ذهبي للميزات المميزة
    'purple': Color(0xFF7B1FA2),    // بنفسجي للميزات المميزة
    'blue': Color(0xFF1976D2),      // أزرق للميزات المميزة
  };

  // ألوان الرسوم البيانية
  static const charts = {
    'blue': Color(0xFF2196F3),
    'green': Color(0xFF4CAF50),
    'orange': Color(0xFFFF9800),
    'purple': Color(0xFF9C27B0),
    'red': Color(0xFFE53935),
  };

  // التدرجات اللونية
  static final gradients = {
    'primary': LinearGradient(
      colors: [
        brand['primaryBlue']!,
        ColorUtils.withOpacity(brand['primaryBlue']!, 0.8),
      ],
    ),
    'secondary': LinearGradient(
      colors: [
        brand['darkNavy']!,
        ColorUtils.withOpacity(brand['darkNavy']!, 0.8),
      ],
    ),
    'realEstate': LinearGradient(
      colors: [
        categories['realEstate']!,
        ColorUtils.withOpacity(categories['realEstate']!, 0.8),
      ],
    ),
    'cars': LinearGradient(
      colors: [
        categories['cars']!,
        ColorUtils.withOpacity(categories['cars']!, 0.8),
      ],
    ),
  };

  // للوصول المباشر إلى الألوان الأكثر استخداماً
  static Color get primaryBlue => brand['primaryBlue']!;
  static Color get primaryIndigo => brand['primaryIndigo']!;
  static Color get darkNavy => brand['darkNavy']!;
  static Color get surfaceLight => interface['surfaceLight']!;
  static Color get lightGray => interface['lightGray']!;
  static Color get mediumGray => interface['mediumGray']!;
  static Color get darkGray => interface['darkGray']!;

  static final ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primary,
    primaryColorDark: AppColors.primaryDark,
    primaryColorLight: AppColors.primaryLight,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.text,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelLarge: TextStyle(color: AppColors.text),
      labelMedium: TextStyle(color: AppColors.text),
      labelSmall: TextStyle(color: AppColors.textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.shadow,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: AppColors.backgroundSecondary,
      filled: true,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.backgroundSecondary,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(color: AppColors.text),
      secondaryLabelStyle: TextStyle(color: Colors.white),
      brightness: Brightness.light,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.disabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorUtils.withOpacity(AppColors.primaryLight, 0.5);
        }
        return ColorUtils.withOpacity(AppColors.disabled, 0.5);
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.border;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.border;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: ColorUtils.withOpacity(AppColors.primaryLight, 0.2),
      circularTrackColor: ColorUtils.withOpacity(AppColors.primaryLight, 0.2),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: ColorUtils.withOpacity(AppColors.primaryLight, 0.2),
      thumbColor: AppColors.primary,
      overlayColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
      valueIndicatorColor: AppColors.primary,
    ),
  );
} 