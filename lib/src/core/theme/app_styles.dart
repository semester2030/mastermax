import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppStyles {
  static final containerDecoration = BoxDecoration(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppTheme.defaultShadow,
  );

  static final titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppTheme.primary,
  );

  static final subtitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTheme.secondary,
  );

  static final bodyStyle = TextStyle(
    fontSize: 16,
    color: AppTheme.textPrimary,
  );

  static final valueStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppTheme.accent,
  );

  static final glassCardDecoration = BoxDecoration(
    color: AppTheme.white.withAlpha(46),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppTheme.border, width: 1.5),
    boxShadow: AppTheme.defaultShadow,
  );

  static final goldButtonDecoration = BoxDecoration(
    color: AppTheme.accent,
    borderRadius: BorderRadius.circular(16),
    boxShadow: AppTheme.defaultShadow,
  );
} 