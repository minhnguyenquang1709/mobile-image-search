import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF6366F1), // Primary/Base
    onPrimary: Color(0xFFFFFFFF), // Primary/On-Primary
    surface: Color(0xFFFFFFFF), // Background/Screen
    surfaceContainer: Color(0xFFF8FAFC), // Surface/Card
    onSurface: Color(0xFF0F172A), // Text/Primary
    onSurfaceVariant: Color(0xFF64748B), // Text/Secondary
    outlineVariant: Color(0xFFE2E8F0), // Border/Divider
    error: Color(0xFFEF4444), // Semantic/Danger
  ),
);

abstract class CustomTextStyles {
  static const String fontFamily = 'Inter';
}
