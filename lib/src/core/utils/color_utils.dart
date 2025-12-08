import 'package:flutter/material.dart';

/// Utility class for color operations
class ColorUtils {
  /// Safely applies opacity to a color using withAlpha
  /// This is a replacement for the deprecated withOpacity method
  static Color withOpacity(Color color, double opacity) {
    return color.withAlpha((opacity * 255).round());
  }
} 