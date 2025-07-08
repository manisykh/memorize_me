import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType { lightGreen, dark, visionProtection }

class AppTheme {
  // ▼▼▼ [수정] 그라데이션 색상을 더 밝고 화사하게 변경 ▼▼▼
  static const LinearGradient lightGreenGradient = LinearGradient(
    colors: [Color(0xFFDCE775), Color(0xFF8BC34A)], // 라임색 -> 녹색
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final List<Color> visionProtectionColors = [
    const Color(0xFFFBF5E9),
    const Color(0xFFF8EEDF),
    const Color(0xFFF5E7D5),
    const Color(0xFFF2E0CB),
    const Color(0xFFEFE0B9),
  ];

  static final ThemeData lightGreenTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.green.shade600,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFBB86FC),
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFBB86FC),
      brightness: Brightness.dark,
    ),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );

  static final ThemeData visionProtectionTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFFB8860B),
    scaffoldBackgroundColor: visionProtectionColors[0],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFB8860B),
      brightness: Brightness.light,
    ),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    textTheme: ThemeData.light().textTheme.apply(
      fontFamily: GoogleFonts.notoSansKr().fontFamily,
      bodyColor: const Color(0xFF5B4628),
      displayColor: const Color(0xFF5B4628),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF5B4628),
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: const Color(0xFFFFF8E1).withOpacity(0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );

  static final Map<AppThemeType, ThemeData> appThemes = {
    AppThemeType.lightGreen: lightGreenTheme,
    AppThemeType.dark: darkTheme,
    AppThemeType.visionProtection: visionProtectionTheme,
  };
}
