import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class AppColors {
  // ✳️ هيكل الألوان الجديد (8-10 لون فقط)
  
  // الألوان الأساسية
  static const Color primary = Color(0xFF7C3AED);      // البنفسجي الأساسي
  static const Color primaryDark = Color(0xFF5B21B6);   // ترويسة / نصوص غامقة
  static const Color primaryLight = Color(0xFFEDE9FE);  // خلفيات خفيفة
  static const Color primaryLightLighter = Color(0xFFF3EAFF); // خلفيات فاتحة جداً (للـ Shimmer)
  
  // ألوان النصوص
  static const Color textPrimary = Color(0xFF3F0071);   // نصوص رئيسية داكنة
  static const Color textSecondary = Color(0xFF6B21A8); // نصوص ثانوية (جديد)

  /// لون `ColorScheme.onSurfaceVariant`: أيقونات/تفاصيل ثانوية على بطاقات بيضاء (محايد بدل البنفسجي الثقيل الافتراضي).
  static const Color onSurfaceMuted = Color(0xFF64748B);

  // ألوان الخلفية
  static const Color white = Color(0xFFFFFFFF);         // الخلفيات العامة
  static const Color background = Color(0xFFF9F6FF);    // خلفيات ثانوية بلون مائل للبنفسجي الفاتح
  
  // ألوان الحالات
  static const Color success = Color(0xFF10B981);       // للنجاح فقط (يبقى لأنه لون عالمي)
  static const Color error = Color(0xFFEF4444);         // للأخطاء
  
  // ألوان شفافة
  static const Color transparent = Colors.transparent;
  
  // التدرجات
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Aliases للألوان القديمة (للتوافق مع الكود الموجود)
  // سيتم حذفها تدريجياً عند تحديث جميع الملفات
  @Deprecated('Use primary instead')
  static const Color royalPurple = primary;
  
  @Deprecated('Use primaryDark instead')
  static const Color secondary = primaryDark;
  
  @Deprecated('Use textPrimary instead')
  static const Color accent = textPrimary;
  
  @Deprecated('Use textSecondary (new) instead')
  static const Color textSecondaryOld = textPrimary;
  
  @Deprecated('Use background instead')
  static const Color surface = white;
  
  @Deprecated('Use background instead')
  static const Color backgroundSecondary = background;
  
  @Deprecated('Use background instead')
  static const Color backgroundDark = background;
  
  @Deprecated('Use textPrimary instead')
  static const Color text = textPrimary;
  
  @Deprecated('Use textPrimary instead')
  static const Color textLight = textPrimary;
  
  @Deprecated('Use textPrimary instead')
  static const Color textDisabled = textPrimary;
  
  @Deprecated('Use textPrimary instead')
  static const Color textMuted = textPrimary;
  
  @Deprecated('Use primaryLight instead')
  static const Color warning = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color info = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color disabled = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color border = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color divider = primaryLight;
  
  // Aliases إضافية للتوافق مع الكود الموجود
  @Deprecated('Use primaryLight instead')
  static const Color brightGold = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color skyBlue = primaryLight;
  
  @Deprecated('Use textPrimary instead')
  static const Color darkGray = textPrimary;
  
  @Deprecated('Use primaryLight instead')
  static const Color lightGray = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color lightBlue = primaryLight;
  
  @Deprecated('Use error instead')
  static const Color brightRed = error;
  
  @Deprecated('Use primary instead')
  static const Color deepBlue = primary;
  
  @Deprecated('Use background instead')
  static const Color lightWhite = background;
  
  @Deprecated('Use primaryLight instead')
  static const Color brightPink = primaryLight;
  
  @Deprecated('Use success instead')
  static const Color neonGreen = success;
  
  @Deprecated('Use primaryLight instead')
  static const Color gradientOrange = primaryLight;
  
  @Deprecated('Use primaryLight instead')
  static const Color lightRed = primaryLight;
  
  @Deprecated('Use primaryDark instead')
  static const Color secondaryDark = primaryDark;
  
  @Deprecated('Use primaryLight instead')
  static const Color shadowLight = primaryLight;
  
  @Deprecated('Use primary instead')
  static const Color spotlightBorder = primary;
  
  @Deprecated('Use white instead')
  static const Color spotlightSurface = white;
  
  @Deprecated('Use textPrimary instead')
  static const Color spotlightText = textPrimary;
  
  @Deprecated('Use background instead')
  static const Color spotlightBackground = background;
  
  @Deprecated('Use white instead')
  static const Color pureWhite = white;
  
  @Deprecated('Use primaryLight instead')
  static const Color lightGrey = primaryLight;
  
  @Deprecated('Use textPrimary instead')
  static const Color black = textPrimary;
  
  @Deprecated('Use primaryLight instead')
  static const Color gold = primaryLight;
  
  @Deprecated('Use white instead')
  static const Color white70 = Color(0xB3FFFFFF);
  
  // ألوان الرسوم البيانية
  @Deprecated('Use primary instead')
  static const Color chartBlue = primary;
  
  @Deprecated('Use success instead')
  static const Color chartGreen = success;
  
  @Deprecated('Use primaryLight instead')
  static const Color chartOrange = primaryLight;
  
  @Deprecated('Use primaryDark instead')
  static const Color chartPurple = primaryDark;
  
  @Deprecated('Use error instead')
  static const Color chartRed = error;
  
  // التدرجات
  @Deprecated('Use gradientPrimary instead')
  static const LinearGradient primaryGradient = gradientPrimary;
  
  @Deprecated('Use gradientPrimary instead')
  static const LinearGradient secondaryGradient = gradientPrimary;
  
  @Deprecated('Use gradientPrimary instead')
  static const LinearGradient royalMetallicGradient = gradientPrimary;
  
  @Deprecated('Use gradientPrimary instead')
  static const LinearGradient goldRoyalGradient = gradientPrimary;
  
  // الظلال
  static Color shadow = ColorUtils.withOpacity(primary, 0.10);
  static Color shadowDark = ColorUtils.withOpacity(primary, 0.18);
  static List<BoxShadow> get defaultShadow => [
    BoxShadow(
      color: shadow,
      blurRadius: 12,
      offset: const Offset(0, 4), // تم التحديث من 6 إلى 4 حسب المواصفات
    ),
  ];
  
  static List<BoxShadow> get largeShadow => [
    BoxShadow(
      color: shadowDark,
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Getters للتوافق
  static Color get primaryColor => primary;
  static Color get primaryColorLight => ColorUtils.withOpacity(primary, 0.1);
  static Color get primaryColorDark => ColorUtils.withOpacity(primary, 0.8);
}
