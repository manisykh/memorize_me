// widgets/glassmorphic_card.dart (수정 후)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isActive;
  final EdgeInsetsGeometry padding;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.isActive = false,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    // 현재 테마 상태를 가져옵니다.
    final themeNotifier = context.watch<ThemeNotifier>();
    final theme = Theme.of(context);

    // 테마에 따라 그라데이션 색상을 결정합니다.
    final List<Color> gradientColors;
    if (themeNotifier.currentTheme == AppThemeType.eyeCare) {
      // '시력 보호 테마'일 경우, primaryColor를 연하게 사용
      gradientColors = [theme.primaryColor.withOpacity(0.15), theme.primaryColor.withOpacity(0.05)];
    } else {
      // '기본 테마'일 경우, 기존의 흰색 그라데이션 사용
      gradientColors = [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)];
    }

    // 테마에 맞는 테두리 색상을 결정합니다.
    final borderColor =
        themeNotifier.currentTheme == AppThemeType.eyeCare
            ? theme.primaryColor.withOpacity(0.6)
            : Colors.white.withOpacity(0.4);

    final activeBorderColor =
        themeNotifier.currentTheme == AppThemeType.eyeCare
            ? theme.primaryColor
            : Colors.white.withOpacity(0.8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors, // 동적으로 결정된 색상 적용
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
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
