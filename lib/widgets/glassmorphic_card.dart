import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart'; // ▼▼▼ [추가] AppThemeType을 사용하기 위해 import

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isActive;
  final EdgeInsetsGeometry padding;
  final double borderRadius; // borderRadius를 파라미터로 받도록 수정

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.isActive = false,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 20.0, // 기본값 설정
  });

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final theme = Theme.of(context);

    final List<Color> gradientColors;
    final Color borderColor;
    final Color activeBorderColor;
    final double blur;

    // 현재 테마에 따라 다른 스타일 적용
    switch (themeNotifier.currentTheme) {
      case AppThemeType.lightGreen:
        gradientColors = [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.2)];
        borderColor = Colors.white.withOpacity(0.5);
        activeBorderColor = Colors.white;
        blur = 10.0;
        break;
      case AppThemeType.dark:
        gradientColors = [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)];
        borderColor = Colors.white.withOpacity(0.2);
        activeBorderColor = Colors.white.withOpacity(0.8);
        blur = 15.0;
        break;
      case AppThemeType.visionProtection:
        // 시력 보호 모드에서는 블러 효과 대신 단색 배경 사용
        gradientColors = [theme.cardTheme.color!, theme.cardTheme.color!];
        borderColor = Colors.black.withOpacity(0.1);
        activeBorderColor = theme.primaryColor;
        blur = 0.0; // 블러 효과 없음
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isActive ? activeBorderColor : borderColor,
                width: isActive ? 2.0 : 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
