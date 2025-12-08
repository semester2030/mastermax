import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class AppColors {
  // الألوان الأساسية الفاخرة
  static const Color primary = Color(0xFF1E3A8A);      // Royal Blue
  static const Color primaryDark = Color(0xFF172554);  // Royal Blue Dark
  static const Color primaryLight = Color(0xFF2563EB); // Royal Blue Light
  static const Color secondary = Color(0xFF455A64);    // Metallic Grey
  static const Color accent = Color(0xFFF59E0B);       // Gold

  // ألوان شفافة
  static const Color transparent = Colors.transparent;

  // ألوان الخلفية
  static const Color background = Color(0xFFF8FAFC);        // Very light white
  static const Color backgroundDark = Color(0xFF1A1A2E);    // Deep dark blue
  static const Color backgroundSecondary = Color(0xFFE2E8F0); // Light grey
  static const Color surface = Color(0xFFFFFFFF);           // Pure white

  // ألوان النصوص
  static const Color text = Color(0xFF1E293B);         // Dark grey for text
  static const Color textPrimary = Color(0xFF0F172A);  // Shiny black for headings
  static const Color textSecondary = Color(0xFF475569);// Grey for secondary text
  static const Color textLight = Color(0xFF64748B);    // Light grey for text
  static const Color textDisabled = Color(0xFF94A3B8); // Disabled text
  static const Color textMuted = Color(0xFFCBD5E1);    // Muted text

  // ألوان الحالات
  static const Color success = Color(0xFF10B981);  // Green
  static const Color warning = Color(0xFFF59E0B);  // Gold/Orange
  static const Color error = Color(0xFFEF4444);    // Red
  static const Color info = Color(0xFF2563EB);     // Blue
  static const Color disabled = Color(0xFFCBD5E1); // Muted grey

  // ألوان الحدود والظلال
  static const Color border = Color(0xFFE2E8F0);   // Light border
  static const Color divider = Color(0xFFE2E8F0);  // Light divider
  static Color shadow = ColorUtils.withOpacity(const Color(0xFF1E3A8A), 0.10);
  static Color shadowDark = ColorUtils.withOpacity(const Color(0xFF1E3A8A), 0.18);
  static const Color shadowLight = Color(0x0D000000);

  // ألوان الرسوم البيانية
  static const Color chartBlue = Color(0xFF2563EB);
  static const Color chartGreen = Color(0xFF10B981);
  static const Color chartOrange = Color(0xFFF59E0B);
  static const Color chartPurple = Color(0xFF7C3AED);
  static const Color chartRed = Color(0xFFEF4444);

  // ألوان إضافية
  static const Color brightGold = Color(0xFFF59E0B);  // Gold
  static const Color royalPurple = Color(0xFF7C3AED); // Royal Purple
  static const Color skyBlue = Color(0xFF0EA5E9);     // Sky Blue
  static const Color white = Color(0xFFFFFFFF);       // White
  static const Color darkGray = Color(0xFF334155);    // Dark grey
  static const Color lightGray = Color(0xFFCBD5E1);   // Light grey
  static const Color lightBlue = Color(0xFFBFDBFE);   // Light blue
  static const Color brightRed = Color(0xFFEF4444);   // Bright red
  static const Color deepBlue = Color(0xFF1E3A8A);    // Deep blue
  static const Color lightWhite = Color(0xFFF8FAFC);  // Very light white
  static const Color brightPink = Color(0xFFEC4899);  // Pink
  static const Color neonGreen = Color(0xFF10B981);   // Neon green
  static const Color gradientOrange = Color(0xFFF97316); // Orange
  static const Color lightRed = Color(0xFFFEE2E2);    // Light red
  static const Color white70 = Color(0xB3FFFFFF);     // White 70%
  static const Color black = Color(0xFF000000);       // Black

  // ألوان التصنيفات
  static const Color categoryReal = Color(0xFFF8FAFC);    // Very light white
  static const Color categoryCars = Color(0xFFF8FAFC);    // Very light white
  static const Color categoryServices = Color(0xFFF8FAFC);// Very light white

  // ألوان سبوت لايت
  static const Color spotlightBackground = Color(0xFFF8FAFC);
  static const Color spotlightSurface = Color(0xFFFFFFFF);
  static const Color spotlightBorder = Color(0xFF1E3A8A);
  static const Color spotlightText = Color(0xFF1E293B);
  static const Color spotlightTitle = Color(0xFF0F172A);
  static const Color profileBackground = Color(0xFFF8FAFC);

  // التدرجات
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient royalMetallicGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldRoyalGradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // الظلال
  static List<BoxShadow> get defaultShadow => [
    BoxShadow(
      color: shadow,
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get largeShadow => [
    BoxShadow(
      color: shadowDark,
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  // زخارف
  static BoxDecoration get glassCardDecoration => BoxDecoration(
    color: white.withOpacity(0.18),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: border, width: 1.5),
    boxShadow: defaultShadow,
  );

  static BoxDecoration get goldButtonDecoration => BoxDecoration(
    color: accent,
    borderRadius: BorderRadius.circular(12),
    boxShadow: defaultShadow,
  );

  // ألوان إضافية للتطبيق
  static const Color gold = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFF97316);
  static const Color chartYellow = Color(0xFFF59E0B);
  static const Color goldenYellow = Color(0xFFF59E0B);

  // ألوان خاصة بالخرائط
  static const Color mapMarker = primary;
  static const Color mapRoute = secondary;
  static const Color mapArea = accent;

  // ألوان خاصة بالرسوم البيانية
  static const Color chartSecondary = secondary;
  static const Color chartAccent = accent;

  // ألوان إضافية للتطبيق
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color secondaryDark = Color(0xFF172554);

  // ألوان الرسوم البيانية
  static const List<Color> chartColors = [
    chartBlue,
    chartGreen,
    chartOrange,
    chartPurple,
    chartRed,
    chartYellow,
    chartSecondary,
    chartAccent,
  ];

  static const Color lightGrey = Color(0xFFF1F5F9);

  static Color get primaryColor => primary;
  static Color get primaryColorLight => ColorUtils.withOpacity(primary, 0.1);
  static Color get primaryColorDark => ColorUtils.withOpacity(primary, 0.8);
}