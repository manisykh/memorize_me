import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType { lightGreen, dark, visionProtection }

class AppTheme {
  static const Color ink = Color(0xFF172026);
  static const Color mutedInk = Color(0xFF667085);
  static const Color primaryGreen = Color(0xFF1F6B5F);
  static const Color accentCoral = Color(0xFFD46A5D);
  static const Color softMint = Color(0xFFE6F0EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color appBackground = Color(0xFFF6F7F2);

  static const LinearGradient lightGreenGradient = LinearGradient(
    colors: [Color(0xFFF6F7F2), Color(0xFFEAF2ED), Color(0xFFFBF4EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final List<Color> visionProtectionColors = [
    const Color(0xFFF8F2E6),
    const Color(0xFFF4EADD),
    const Color(0xFFEFE4D2),
    const Color(0xFFE9DCC8),
    const Color(0xFFE2D6C2),
  ];

  static TextTheme _koreanTextTheme({TextTheme? base, required Color color}) {
    final textTheme = GoogleFonts.notoSansKrTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );

    TextStyle? tuned(
      TextStyle? style,
      double size,
      FontWeight weight,
      double height,
    ) {
      return style?.copyWith(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );
    }

    return textTheme.copyWith(
      displayLarge: tuned(textTheme.displayLarge, 34, FontWeight.w800, 1.18),
      displayMedium: tuned(textTheme.displayMedium, 32, FontWeight.w800, 1.2),
      displaySmall: tuned(textTheme.displaySmall, 30, FontWeight.w800, 1.22),
      headlineLarge: tuned(textTheme.headlineLarge, 26, FontWeight.w800, 1.24),
      headlineMedium: tuned(textTheme.headlineMedium, 24, FontWeight.w800, 1.24),
      headlineSmall: tuned(textTheme.headlineSmall, 22, FontWeight.w800, 1.26),
      titleLarge: tuned(textTheme.titleLarge, 20, FontWeight.w800, 1.3),
      titleMedium: tuned(textTheme.titleMedium, 17, FontWeight.w700, 1.35),
      titleSmall: tuned(textTheme.titleSmall, 15, FontWeight.w700, 1.35),
      bodyLarge: tuned(textTheme.bodyLarge, 15, FontWeight.w400, 1.48),
      bodyMedium: tuned(textTheme.bodyMedium, 14, FontWeight.w400, 1.48),
      bodySmall: tuned(textTheme.bodySmall, 13, FontWeight.w400, 1.45),
      labelLarge: tuned(textTheme.labelLarge, 14, FontWeight.w700, 1.25),
      labelMedium: tuned(textTheme.labelMedium, 12, FontWeight.w700, 1.25),
      labelSmall: tuned(textTheme.labelSmall, 11, FontWeight.w700, 1.2),
    );
  }

  static DialogThemeData _dialogTheme({
    required Color surfaceColor,
    required Color onSurfaceColor,
    required Color outlineColor,
    required Color shadowColor,
    required Color barrierColor,
  }) {
    return DialogThemeData(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: shadowColor.withValues(alpha: 0.16),
      barrierColor: barrierColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: outlineColor),
      ),
      titleTextStyle: GoogleFonts.notoSansKr(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      contentTextStyle: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.48,
        letterSpacing: 0,
        color: onSurfaceColor.withValues(alpha: 0.82),
      ),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme({
    required Color surfaceColor,
    required Color shadowColor,
    required Color barrierColor,
  }) {
    return BottomSheetThemeData(
      backgroundColor: surfaceColor,
      modalBackgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadowColor.withValues(alpha: 0.16),
      modalBarrierColor: barrierColor,
      elevation: 0,
      modalElevation: 14,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  static PopupMenuThemeData _popupMenuTheme({
    required Color surfaceColor,
    required Color onSurfaceColor,
    required Color outlineColor,
    required Color shadowColor,
  }) {
    return PopupMenuThemeData(
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadowColor.withValues(alpha: 0.14),
      elevation: 10,
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outlineColor),
      ),
      textStyle: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      iconColor: onSurfaceColor.withValues(alpha: 0.74),
      iconSize: 20,
    );
  }

  static SnackBarThemeData _snackBarTheme({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color actionColor,
  }) {
    return SnackBarThemeData(
      backgroundColor: backgroundColor,
      actionTextColor: actionColor,
      closeIconColor: foregroundColor.withValues(alpha: 0.86),
      behavior: SnackBarBehavior.floating,
      elevation: 10,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentTextStyle: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: 0,
        color: foregroundColor,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color foregroundColor) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: const Size(56, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }

  static final ThemeData lightGreenTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    cardColor: surface,
    canvasColor: appBackground,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
      primary: primaryGreen,
      secondary: accentCoral,
      surface: surface,
    ),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    textTheme: _koreanTextTheme(color: ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: _dialogTheme(
      surfaceColor: surface,
      onSurfaceColor: ink,
      outlineColor: const Color(0xFFDFE4DA),
      shadowColor: ink,
      barrierColor: ink.withValues(alpha: 0.36),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      surfaceColor: surface,
      shadowColor: ink,
      barrierColor: ink.withValues(alpha: 0.36),
    ),
    popupMenuTheme: _popupMenuTheme(
      surfaceColor: surface,
      onSurfaceColor: ink,
      outlineColor: const Color(0xFFDFE4DA),
      shadowColor: ink,
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      actionColor: const Color(0xFFA7E0D4),
    ),
    cardTheme: CardTheme(
      elevation: 1.5,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: ink.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDFE4DA)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFDFE4DA),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: _textButtonTheme(primaryGreen),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xFFDFE4DA)),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE1E7DE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryGreen, width: 1.4),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF82D5C7),
    cardColor: const Color(0xFF17201E),
    canvasColor: const Color(0xFF0F1514),
    scaffoldBackgroundColor: const Color(0xFF0F1514),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF82D5C7),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF82D5C7),
      onPrimary: const Color(0xFF06201C),
      secondary: const Color(0xFFE07868),
      onSecondary: const Color(0xFF35110D),
      surface: const Color(0xFF17201E),
      onSurface: const Color(0xFFEAF2EF),
      surfaceContainerHighest: const Color(0xFF22302D),
      onSurfaceVariant: const Color(0xFFB8C8C3),
      outline: const Color(0xFF40514D),
      shadow: const Color(0xFF000000),
    ),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    textTheme: _koreanTextTheme(
      base: ThemeData.dark().textTheme,
      color: const Color(0xFFEAF2EF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFEAF2EF),
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: _dialogTheme(
      surfaceColor: const Color(0xFF17201E),
      onSurfaceColor: const Color(0xFFEAF2EF),
      outlineColor: const Color(0xFF2A3A36),
      shadowColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.58),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      surfaceColor: const Color(0xFF17201E),
      shadowColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.58),
    ),
    popupMenuTheme: _popupMenuTheme(
      surfaceColor: const Color(0xFF17201E),
      onSurfaceColor: const Color(0xFFEAF2EF),
      outlineColor: const Color(0xFF2A3A36),
      shadowColor: Colors.black,
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: const Color(0xFFEAF2EF),
      foregroundColor: const Color(0xFF0F1514),
      actionColor: const Color(0xFF1F6B5F),
    ),
    cardTheme: CardTheme(
      elevation: 1.0,
      color: const Color(0xFF17201E),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2A3A36)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A3A36),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF82D5C7),
        foregroundColor: const Color(0xFF06201C),
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: _textButtonTheme(const Color(0xFF82D5C7)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF82D5C7),
        foregroundColor: const Color(0xFF06201C),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEAF2EF),
        side: const BorderSide(color: Color(0xFF40514D)),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF22302D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF40514D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF82D5C7), width: 1.4),
      ),
    ),
  );

  static final ThemeData visionProtectionTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF6C6048),
    cardColor: const Color(0xFFFEFAF1),
    scaffoldBackgroundColor: visionProtectionColors[0],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C6048),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF6C6048),
      onPrimary: Colors.white,
      secondary: const Color(0xFFB56557),
      onSecondary: Colors.white,
      surface: const Color(0xFFFEFAF1),
      onSurface: const Color(0xFF4F4634),
      surfaceContainerHighest: const Color(0xFFEFE4D2),
      onSurfaceVariant: const Color(0xFF6C6048),
      outline: const Color(0xFFE2D6C2),
      shadow: Colors.black,
    ),
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    textTheme: _koreanTextTheme(color: const Color(0xFF4F4634)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF4F4634),
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: _dialogTheme(
      surfaceColor: const Color(0xFFFEFAF1),
      onSurfaceColor: const Color(0xFF4F4634),
      outlineColor: const Color(0xFFE2D6C2),
      shadowColor: const Color(0xFF4F4634),
      barrierColor: const Color(0xFF4F4634).withValues(alpha: 0.34),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      surfaceColor: const Color(0xFFFEFAF1),
      shadowColor: const Color(0xFF4F4634),
      barrierColor: const Color(0xFF4F4634).withValues(alpha: 0.34),
    ),
    popupMenuTheme: _popupMenuTheme(
      surfaceColor: const Color(0xFFFEFAF1),
      onSurfaceColor: const Color(0xFF4F4634),
      outlineColor: const Color(0xFFE2D6C2),
      shadowColor: const Color(0xFF4F4634),
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: const Color(0xFF4F4634),
      foregroundColor: const Color(0xFFFFF8EC),
      actionColor: const Color(0xFFF3D1A7),
    ),
    cardTheme: CardTheme(
      elevation: 1.0,
      color: const Color(0xFFFEFAF1),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0xFF4F4634).withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2D6C2)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2D6C2),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C6048),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: _textButtonTheme(const Color(0xFF6C6048)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF6C6048),
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4F4634),
        side: const BorderSide(color: Color(0xFFE2D6C2)),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFEFAF1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2D6C2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6C6048), width: 1.4),
      ),
    ),
  );

  static final Map<AppThemeType, ThemeData> appThemes = {
    AppThemeType.lightGreen: lightGreenTheme,
    AppThemeType.dark: darkTheme,
    AppThemeType.visionProtection: visionProtectionTheme,
  };
}
