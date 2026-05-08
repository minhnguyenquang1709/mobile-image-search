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

abstract class CustomColors {
  static const Color primary = Color(
    0xFF6366F1,
  ); // brand color, appears the most, used for important buttons, checked states, floating action buttons
  static const Color onPrimary = Color(
    0xFFFFFFFF,
  ); // for content on top of primary color, e.g. text/icons ("Login" in a primary button)
  static const Color surface = Color(
    0xFFFFFFFF,
  ); // main background, e.g. background of a scaffold, navigation bar
  static const Color surfaceContainer = Color(
    0xFFF8FAFC,
  ); // separate surfaces containing content from the background, e.g. background of cards, dialogs, filled textfield
  static const Color textPrimary = Color(
    0xFF0F172A,
  ); // text/icons on top of surface, e.g. title of card, important text content
  static const Color textSecondary = Color(
    0xFF64748B,
  ); // less important text/icons, subtitles, decorative icons, placeholder text
  static const Color divider = Color(0xFFE2E8F0); //
  static const Color error = Color(0xFFEF4444);
}

abstract class CustomTextStyles {
  static const String fontFamily = 'Inter';
}
