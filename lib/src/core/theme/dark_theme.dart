import 'package:flutter/material.dart';

class DarkTheme {
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF1E3A8A), // Royal Blue
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1E3A8A),      // Royal Blue
      secondary: Color(0xFF455A64),     // Metallic Grey
      surface: Color(0xFF1A1A2E),    // Deep dark blue
      error: Color(0xFFEF4444),         // Red
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    cardColor: const Color(0xFF1A1A2E),
    dividerColor: const Color(0xFFE2E8F0),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF0F172A)),
      headlineMedium: TextStyle(color: Color(0xFF0F172A)),
      headlineSmall: TextStyle(color: Color(0xFF0F172A)),
      titleLarge: TextStyle(color: Color(0xFF0F172A)),
      titleMedium: TextStyle(color: Color(0xFF475569)),
      titleSmall: TextStyle(color: Color(0xFF475569)),
      bodyLarge: TextStyle(color: Color(0xFF0F172A)),
      bodyMedium: TextStyle(color: Color(0xFF475569)),
      bodySmall: TextStyle(color: Color(0xFF64748B)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF64748B),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFF1E3A8A),
      disabledColor: Color(0xFFCBD5E1),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A2E),
      elevation: 0,
      shadowColor: const Color(0xFF1E3A8A).withAlpha((0.18 * 255).round()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
  );
} 