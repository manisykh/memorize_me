import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF6366F1);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF0F172A);
  static const Color textDark = Color(0xFFE2E8F0);
  static const Color subTextLight = Color(0xFF64748B);
  static const Color subTextDark = Color(0xFF94A3B8);

  static final Color lightShadowLight = Colors.white.withOpacity(0.9);
  static final Color darkShadowLight = const Color(0xFFA3B1C6).withOpacity(0.5);
  static final Color lightShadowDark = const Color(0xFF1E293B).withOpacity(0.8);
  static const Color darkShadowDark = Color(0xFF0A0F1A);

  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);

  static final Color glassBlur = Colors.white.withOpacity(0.25);
  static final Color glassBorder = Colors.white.withOpacity(0.18);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppTheme.backgroundLight,
    primaryColor: AppTheme.primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primaryBlue,
      brightness: Brightness.light,
      secondary: AppTheme.accentGreen,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppTheme.textLight, fontSize: 16),
      bodyMedium: TextStyle(color: AppTheme.textLight),
      titleLarge: TextStyle(color: AppTheme.textLight, fontSize: 22, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppTheme.backgroundLight,
      elevation: 0,
      foregroundColor: AppTheme.textLight,
      titleTextStyle: TextStyle(
        color: AppTheme.textLight,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'NanumGothic',
      ),
    ),
    fontFamily: 'NanumGothic',
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppTheme.backgroundDark,
    primaryColor: AppTheme.primaryPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primaryPurple,
      brightness: Brightness.dark,
      secondary: AppTheme.accentGreen,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppTheme.textDark, fontSize: 16),
      bodyMedium: TextStyle(color: AppTheme.textDark),
      titleLarge: TextStyle(color: AppTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppTheme.backgroundDark,
      elevation: 0,
      foregroundColor: AppTheme.textDark,
      titleTextStyle: TextStyle(
        color: AppTheme.textDark,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'NanumGothic',
      ),
    ),
    fontFamily: 'NanumGothic',
  );
}
