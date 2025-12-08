import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/color_utils.dart';

class AppTheme {
  // الألوان الثابتة للاستخدام في const widgets
  static const colors = {
    'primary': AppColors.primary,
    'secondary': AppColors.secondary,
    'accent': AppColors.accent,
    'error': AppColors.error,
    'success': AppColors.success,
    'warning': AppColors.warning,
    'info': AppColors.info,
    'textPrimary': AppColors.textPrimary,
    'textSecondary': AppColors.textSecondary,
    'textDisabled': AppColors.textDisabled,
    'surface': AppColors.surface,
    'background': AppColors.background,
    'border': AppColors.border,
  };

  // الألوان الديناميكية (غير ثابتة)
  static Color get primary => AppColors.primary;
  static Color get secondary => AppColors.secondary;
  static Color get accent => AppColors.accent;

  // ألوان الحالة
  static Color get success => AppColors.success;
  static Color get error => AppColors.error;
  static Color get warning => AppColors.warning;
  static Color get info => AppColors.info;

  // ألوان النص
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textDisabled => AppColors.textDisabled;

  // ألوان الخلفية
  static Color get surface => AppColors.surface;
  static Color get background => AppColors.background;
  static Color get backgroundDark => AppColors.backgroundDark;
  static Color get border => AppColors.border;

  // التدرجات
  static Gradient get primaryGradient => AppColors.primaryGradient;
  static Gradient get secondaryGradient => AppColors.secondaryGradient;

  // الظلال
  static List<BoxShadow> get defaultShadow => AppColors.defaultShadow;
  static List<BoxShadow> get largeShadow => AppColors.largeShadow;

  // ألوان إضافية
  static Color get brightGold => AppColors.brightGold;
  static Color get royalPurple => AppColors.royalPurple;
  static Color get skyBlue => AppColors.skyBlue;
  static Color get white => AppColors.white;
  static Color get darkGray => AppColors.darkGray;
  static Color get lightGray => AppColors.lightGray;
  static Color get lightBlue => AppColors.lightBlue;
  static Color get brightRed => AppColors.brightRed;
  static Color get deepBlue => AppColors.deepBlue;
  static Color get lightWhite => AppColors.lightWhite;

  // ألوان إضافية للتطبيق
  static Color get brightPink => AppColors.brightPink;
  static Color get neonGreen => AppColors.neonGreen;
  static Color get gradientOrange => AppColors.gradientOrange;
  static Color get lightRed => AppColors.lightRed;

  // ألوان الظل
  static Color get shadow => AppColors.shadow;
  static Color get shadowDark => AppColors.shadowDark;
  static Color get shadowLight => AppColors.shadowLight;

  // ألوان سبوت لايت
  static Color get spotlightPrimaryGold => AppColors.spotlightBorder;
  static Color get spotlightCardPurple => AppColors.spotlightSurface;
  static Color get spotlightTextGold => AppColors.spotlightText;
  static Color get spotlightDarkBackground => AppColors.spotlightBackground;
  static Color get spotlightDarkSurface => AppColors.spotlightSurface;

  // الثيم الرئيسي
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    primaryColorDark: AppColors.primaryDark,
    primaryColorLight: AppColors.primaryLight,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textDisabled),
      errorStyle: TextStyle(color: AppColors.error, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: AppColors.shadow,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.backgroundSecondary,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.secondary,
      labelStyle: TextStyle(color: AppColors.textPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
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
          return ColorUtils.withOpacity(AppColors.primary, 0.5);
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
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
      linearTrackColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
      circularTrackColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
      thumbColor: AppColors.primary,
      overlayColor: ColorUtils.withOpacity(AppColors.primary, 0.2),
      valueIndicatorColor: AppColors.primary,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
    splashColor: AppColors.primary.withOpacity(0.08),
    highlightColor: AppColors.primary.withOpacity(0.04),
    hoverColor: AppColors.primary.withOpacity(0.08),
    focusColor: AppColors.primary.withOpacity(0.08),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: primary,
      primaryColorDark: AppColors.primaryDark,
      primaryColorLight: AppColors.primaryLight,
      scaffoldBackgroundColor: ColorUtils.withOpacity(Colors.black, 0.95),
      colorScheme: ColorScheme(
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error, width: 2),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primary,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
          shadowColor: shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: primary),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundDark,
        selectedColor: primary,
        secondarySelectedColor: secondary,
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        brightness: Brightness.dark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return AppColors.disabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorUtils.withOpacity(primary, 0.5);
          }
          return ColorUtils.withOpacity(AppColors.disabled, 0.5);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return border;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return border;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: ColorUtils.withOpacity(primary, 0.2),
        circularTrackColor: ColorUtils.withOpacity(primary, 0.2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: ColorUtils.withOpacity(primary, 0.2),
        thumbColor: primary,
        overlayColor: ColorUtils.withOpacity(primary, 0.2),
        valueIndicatorColor: primary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        scrimColor: ColorUtils.withOpacity(Colors.black, 0.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: TextStyle(color: textPrimary),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: primary),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: primary),
        ),
      ),
    );
  }
} 
