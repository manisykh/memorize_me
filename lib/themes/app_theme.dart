import 'package:flutter/material.dart';

enum AppThemeType { lightGreen, dark, visionProtection }

class AppTheme {
  static const Color ink = Color(0xFF1F2024);
  static const Color mutedInk = Color(0xFF7A7B80);
  static const Color brandBrown = Color(0xFF8B4A32);
  static const Color primaryGreen = Color(0xFF5C8A6E);
  static const Color accentCoral = Color(0xFFC8612C);
  static const Color primaryGlow = Color(0xFFE37E3F);
  static const Color softMint = Color(0xFFCFE3C4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color appBackground = Color(0xFFF7F7F7);

  static const List<String> systemFontFallback = [
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Noto Sans CJK KR',
    'Noto Sans',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const LinearGradient lightGreenGradient = LinearGradient(
    colors: [Color(0xFFF7F7F7), Color(0xFFFBFBFB), Color(0xFFF4F1EC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final List<Color> visionProtectionColors = [
    const Color(0xFFF9F2E5),
    const Color(0xFFF6ECD9),
    const Color(0xFFF2E6D3),
    const Color(0xFFEDDDC4),
    const Color(0xFFE8D4B7),
  ];

  static TextTheme _koreanTextTheme({TextTheme? base, required Color color}) {
    final textTheme = (base ?? ThemeData.light().textTheme).apply(
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
        fontFamilyFallback: systemFontFallback,
      );
    }

    return textTheme.copyWith(
      displayLarge: tuned(textTheme.displayLarge, 36, FontWeight.w800, 1.12),
      displayMedium: tuned(textTheme.displayMedium, 32, FontWeight.w800, 1.14),
      displaySmall: tuned(textTheme.displaySmall, 30, FontWeight.w800, 1.18),
      headlineLarge: tuned(textTheme.headlineLarge, 24, FontWeight.w800, 1.22),
      headlineMedium: tuned(textTheme.headlineMedium, 22, FontWeight.w800, 1.24),
      headlineSmall: tuned(textTheme.headlineSmall, 20, FontWeight.w800, 1.26),
      titleLarge: tuned(textTheme.titleLarge, 18, FontWeight.w800, 1.32),
      titleMedium: tuned(textTheme.titleMedium, 16, FontWeight.w700, 1.34),
      titleSmall: tuned(textTheme.titleSmall, 14, FontWeight.w700, 1.36),
      bodyLarge: tuned(textTheme.bodyLarge, 15, FontWeight.w400, 1.48),
      bodyMedium: tuned(textTheme.bodyMedium, 14, FontWeight.w400, 1.48),
      bodySmall: tuned(textTheme.bodySmall, 12, FontWeight.w400, 1.45),
      labelLarge: tuned(textTheme.labelLarge, 14, FontWeight.w700, 1.25),
      labelMedium: tuned(textTheme.labelMedium, 12, FontWeight.w700, 1.25),
      labelSmall: tuned(textTheme.labelSmall, 10, FontWeight.w700, 1.2),
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
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: 0,
        fontFamilyFallback: systemFontFallback,
        color: onSurfaceColor,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.48,
        letterSpacing: 0,
        fontFamilyFallback: systemFontFallback,
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
      textStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 0,
        fontFamilyFallback: systemFontFallback,
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
      contentTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: 0,
        fontFamilyFallback: systemFontFallback,
        color: foregroundColor,
      ),
    );
  }

  static NavigationBarThemeData _navigationBarTheme({
    required Color backgroundColor,
    required Color indicatorColor,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return NavigationBarThemeData(
      backgroundColor: backgroundColor,
      indicatorColor: indicatorColor,
      elevation: 10,
      surfaceTintColor: Colors.transparent,
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          height: 1.1,
          letterSpacing: 0,
          fontFamilyFallback: systemFontFallback,
          color: selected ? selectedColor : unselectedColor,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: selected ? 24 : 22,
          color: selected ? selectedColor : unselectedColor,
        );
      }),
    );
  }

  static AppBarTheme _appBarTheme(Color foregroundColor) {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: foregroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: 0,
        fontFamilyFallback: systemFontFallback,
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
    primaryColor: accentCoral,
    cardColor: surface,
    canvasColor: appBackground,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentCoral,
      brightness: Brightness.light,
      primary: accentCoral,
      secondary: primaryGlow,
      surface: surface,
    ).copyWith(
      onPrimary: Colors.white,
      onSecondary: ink,
      tertiary: primaryGreen,
      onTertiary: Colors.white,
      tertiaryContainer: softMint,
      onTertiaryContainer: primaryGreen,
      surfaceContainerHighest: const Color(0xFFF0F0F2),
      onSurface: ink,
      onSurfaceVariant: mutedInk,
      outline: const Color(0xFFDCDCE0),
      shadow: ink,
    ),
    textTheme: _koreanTextTheme(color: ink),
    appBarTheme: _appBarTheme(ink),
    dialogTheme: _dialogTheme(
      surfaceColor: surface,
      onSurfaceColor: ink,
      outlineColor: const Color(0xFFDCDCE0),
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
      outlineColor: const Color(0xFFDCDCE0),
      shadowColor: ink,
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      actionColor: const Color(0xFFF1B19C),
    ),
    navigationBarTheme: _navigationBarTheme(
      backgroundColor: Colors.white,
      indicatorColor: accentCoral.withValues(alpha: 0.16),
      selectedColor: accentCoral,
      unselectedColor: mutedInk,
    ),
    cardTheme: CardTheme(
      elevation: 1.5,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: ink.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFDCDCE0)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFDCDCE0),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentCoral,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: _textButtonTheme(brandBrown),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentCoral,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: Color(0xFFAFC9A7), width: 1.4),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFDCDCE0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: accentCoral, width: 1.4),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFF0A866),
    cardColor: const Color(0xFF3A2E24),
    canvasColor: const Color(0xFF231C16),
    scaffoldBackgroundColor: const Color(0xFF231C16),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFF0A866),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFF0A866),
      onPrimary: const Color(0xFF2B2118),
      secondary: const Color(0xFFFAB97A),
      onSecondary: const Color(0xFF2B2118),
      tertiary: const Color(0xFF7BBF8E),
      onTertiary: const Color(0xFF172012),
      tertiaryContainer: const Color(0xFF314532),
      onTertiaryContainer: const Color(0xFFCFE8D5),
      surface: const Color(0xFF3A2E24),
      onSurface: const Color(0xFFF4ECDD),
      surfaceContainerHighest: const Color(0xFF49392B),
      onSurfaceVariant: const Color(0xFFBFA68A),
      outline: const Color(0xFF604A35),
      shadow: const Color(0xFF000000),
    ),
    textTheme: _koreanTextTheme(
      base: ThemeData.dark().textTheme,
      color: const Color(0xFFF4ECDD),
    ),
    appBarTheme: _appBarTheme(const Color(0xFFF4ECDD)),
    dialogTheme: _dialogTheme(
      surfaceColor: const Color(0xFF3A2E24),
      onSurfaceColor: const Color(0xFFF4ECDD),
      outlineColor: const Color(0xFF604A35),
      shadowColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.58),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      surfaceColor: const Color(0xFF3A2E24),
      shadowColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.58),
    ),
    popupMenuTheme: _popupMenuTheme(
      surfaceColor: const Color(0xFF3A2E24),
      onSurfaceColor: const Color(0xFFF4ECDD),
      outlineColor: const Color(0xFF604A35),
      shadowColor: Colors.black,
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: const Color(0xFFF4ECDD),
      foregroundColor: const Color(0xFF231C16),
      actionColor: const Color(0xFFC8612C),
    ),
    navigationBarTheme: _navigationBarTheme(
      backgroundColor: const Color(0xFF3A2E24),
      indicatorColor: const Color(0xFF604A35),
      selectedColor: const Color(0xFFF0A866),
      unselectedColor: const Color(0xFFBFA68A),
    ),
    cardTheme: CardTheme(
      elevation: 1.0,
      color: const Color(0xFF3A2E24),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF604A35)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF604A35),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF0A866),
        foregroundColor: const Color(0xFF2B2118),
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: _textButtonTheme(const Color(0xFFF0A866)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF0A866),
        foregroundColor: const Color(0xFF2B2118),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7BBF8E),
        side: const BorderSide(color: Color(0xFF7BBF8E), width: 1.4),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF49392B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF604A35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF0A866), width: 1.4),
      ),
    ),
  );

  static final ThemeData visionProtectionTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFFC76E40),
    cardColor: const Color(0xFFFBF6EC),
    scaffoldBackgroundColor: visionProtectionColors[0],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFC76E40),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFFC76E40),
      onPrimary: const Color(0xFFFBF6EC),
      secondary: const Color(0xFFE08A52),
      onSecondary: const Color(0xFF3F2E22),
      tertiary: const Color(0xFF5C8A6E),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFDDE8D5),
      onTertiaryContainer: const Color(0xFF3F604B),
      surface: const Color(0xFFFBF6EC),
      onSurface: const Color(0xFF3F2E22),
      surfaceContainerHighest: const Color(0xFFF2E6D3),
      onSurfaceVariant: const Color(0xFF7B5F45),
      outline: const Color(0xFFE5D6BD),
      shadow: Colors.black,
    ),
    textTheme: _koreanTextTheme(color: const Color(0xFF3F2E22)),
    appBarTheme: _appBarTheme(const Color(0xFF3F2E22)),
    dialogTheme: _dialogTheme(
      surfaceColor: const Color(0xFFFBF6EC),
      onSurfaceColor: const Color(0xFF3F2E22),
      outlineColor: const Color(0xFFE5D6BD),
      shadowColor: const Color(0xFF3F2E22),
      barrierColor: const Color(0xFF3F2E22).withValues(alpha: 0.34),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      surfaceColor: const Color(0xFFFBF6EC),
      shadowColor: const Color(0xFF3F2E22),
      barrierColor: const Color(0xFF3F2E22).withValues(alpha: 0.34),
    ),
    popupMenuTheme: _popupMenuTheme(
      surfaceColor: const Color(0xFFFBF6EC),
      onSurfaceColor: const Color(0xFF3F2E22),
      outlineColor: const Color(0xFFE5D6BD),
      shadowColor: const Color(0xFF3F2E22),
    ),
    snackBarTheme: _snackBarTheme(
      backgroundColor: const Color(0xFF3F2E22),
      foregroundColor: const Color(0xFFFBF6EC),
      actionColor: const Color(0xFFE08A52),
    ),
    navigationBarTheme: _navigationBarTheme(
      backgroundColor: const Color(0xFFFBF6EC),
      indicatorColor: const Color(0xFFF0E2CC),
      selectedColor: const Color(0xFFC76E40),
      unselectedColor: const Color(0xFF7B5F45),
    ),
    cardTheme: CardTheme(
      elevation: 1.0,
      color: const Color(0xFFFBF6EC),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0xFF7F5431).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE5D6BD)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5D6BD),
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC76E40),
        foregroundColor: const Color(0xFFFBF6EC),
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: _textButtonTheme(const Color(0xFFC76E40)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFC76E40),
        foregroundColor: const Color(0xFFFBF6EC),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF5C8A6E),
        side: const BorderSide(color: Color(0xFFC8D7BE), width: 1.4),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFBF6EC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5D6BD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFC76E40), width: 1.4),
      ),
    ),
  );

  static final Map<AppThemeType, ThemeData> appThemes = {
    AppThemeType.lightGreen: lightGreenTheme,
    AppThemeType.dark: darkTheme,
    AppThemeType.visionProtection: visionProtectionTheme,
  };
}
