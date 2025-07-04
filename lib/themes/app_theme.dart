// lib/themes/app_theme.dart (Full Code)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- 테마에서 사용할 기본 색상 (그라데이션 테마용) ---
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color primaryAccent = Color(0xFF8EC5FC);

  // --- 시력 보호 테마용 색상 ---
  static const Color primaryMutedBlue = Color(0xFF7B8BDB);
  static const Color backgroundSepia = Color(0xFFFAF8F1);
  static const Color backgroundSepiaLevel1 = Color(0xFFFAF8F1);
  static const Color backgroundSepiaLevel2 = Color(0xFFFBF5E9);
  static const Color backgroundSepiaLevel3 = Color(0xFFF8EEDF);
  static const Color textCharcoal = Color(0xFF363636);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);

  // --- 테마 1: 기본 그라데이션 테마 ---
  static final ThemeData defaultTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: primaryAccent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryAccent,
      brightness: Brightness.dark,
      primary: primaryAccent,
      secondary: Colors.white,
      error: accentRed, // 에러 색상 지정
    ),
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineSmall: const TextStyle(color: primaryText, fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(color: primaryText, fontWeight: FontWeight.bold),
      bodyLarge: const TextStyle(color: primaryText),
      bodyMedium: const TextStyle(color: secondaryText),
      bodySmall: const TextStyle(color: secondaryText, fontSize: 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: primaryText,
      titleTextStyle: GoogleFonts.poppins(
        color: primaryText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    iconTheme: const IconThemeData(color: primaryText),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
    ),
  );

  // --- 테마 2: 시력 보호 테마 (기존 버전으로 복원) ---
  static final ThemeData eyeCareTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundSepia, // 세피아 배경색 적용
    primaryColor: primaryMutedBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryMutedBlue,
      brightness: Brightness.light,
      secondary: accentGreen,
      primary: primaryMutedBlue,
      onPrimary: Colors.white,
      error: accentRed,
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
      foregroundColor: textCharcoal, // 어두운 전경색
      titleTextStyle: GoogleFonts.poppins(
        color: textCharcoal,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
