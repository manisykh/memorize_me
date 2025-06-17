// app_theme.dart (수정 후)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- 기본 테마 색상 ---
  static const Color primaryBlue = Color(0xFF6366F1);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color textPrimaryDark = Color(0xFF1E2A3B);
  static const Color textSecondaryDark = Color(0xFF475569);

  // --- 시력 보호 테마 (이미지 기준) ---
  static const Color primaryMutedBlue = Color(0xFF7B8BDB);
  static const Color backgroundSepiaLevel1 = Color(0xFFFAF8F1); // 가장 연하게
  static const Color backgroundSepiaLevel2 = Color(0xFFFBF5E9); // 중간
  static const Color backgroundSepiaLevel3 = Color(0xFFF8EEDF); // 가장 진하게
  static const Color backgroundSepia = Color(0xFFFAF8F1);
  static const Color textCharcoal = Color(0xFF363636);

  // --- 공용 색상 ---
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);

  // --- 테마 1: 기본 테마 ---
  static final ThemeData defaultTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    primaryColor: primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      secondary: accentGreen,
      primary: primaryBlue,
      onPrimary: Colors.white,
    ),
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineSmall: const TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
      bodyLarge: const TextStyle(color: textPrimaryDark),
      bodyMedium: const TextStyle(color: textSecondaryDark),
      bodySmall: TextStyle(color: textSecondaryDark, fontSize: 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundLight,
      elevation: 0,
      foregroundColor: textPrimaryDark,
      titleTextStyle: GoogleFonts.poppins(
        color: textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // --- 테마 2: 시력 보호 테마 (소프트 세피아) ---
  static final ThemeData eyeCareTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundSepia,
    primaryColor: primaryMutedBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryMutedBlue,
      brightness: Brightness.light,
      secondary: accentGreen,
      primary: primaryMutedBlue,
      onPrimary: Colors.white,
    ),
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme()
        .apply(bodyColor: textCharcoal, displayColor: textCharcoal)
        .copyWith(
          headlineSmall: const TextStyle(color: textCharcoal, fontWeight: FontWeight.bold),
          titleLarge: const TextStyle(color: textCharcoal, fontWeight: FontWeight.bold),
          bodyLarge: const TextStyle(color: textCharcoal),
          bodyMedium: TextStyle(color: textCharcoal.withOpacity(0.8)),
          bodySmall: TextStyle(color: textCharcoal.withOpacity(0.8), fontSize: 12),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: textCharcoal,
      titleTextStyle: GoogleFonts.poppins(
        color: textCharcoal,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
