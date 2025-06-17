import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF6366F1);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);

  static const Color textPrimaryDark = Color(0xFF1E2A3B);
  static const Color textSecondaryDark = Color(0xFF475569);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppTheme.backgroundLight,
    primaryColor: AppTheme.primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primaryBlue,
      brightness: Brightness.light,
      secondary: AppTheme.accentGreen,
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
      backgroundColor: AppTheme.backgroundLight,
      elevation: 0,
      foregroundColor: textPrimaryDark,
      titleTextStyle: GoogleFonts.poppins(
        color: textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: AppTheme.primaryPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primaryPurple,
      brightness: Brightness.dark,
      secondary: AppTheme.accentGreen,
    ),
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme()
        .apply(bodyColor: Colors.white.withOpacity(0.9), displayColor: Colors.white)
        .copyWith(
          headlineSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.white.withOpacity(0.9)),
          bodyMedium: TextStyle(color: Colors.white.withOpacity(0.7)),
          bodySmall: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
