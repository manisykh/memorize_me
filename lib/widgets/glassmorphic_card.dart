// widgets/glassmorphic_card.dart (최종 수정)

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
    final themeNotifier = context.watch<ThemeNotifier>();
    final theme = Theme.of(context);

    final List<Color> gradientColors;
    final Color borderColor;
    final Color activeBorderColor;

    if (themeNotifier.currentTheme == AppThemeType.eyeCare) {
      // '시력 보호 테마'일 경우, 배경색과 비슷한 계열의 반투명 그라데이션 사용
      gradientColors = [
        theme.scaffoldBackgroundColor.withOpacity(0.3),
        theme.scaffoldBackgroundColor.withOpacity(0.1),
      ];
      borderColor = theme.primaryColor.withOpacity(0.3);
      activeBorderColor = theme.primaryColor;
    } else {
      // '기본 테마'일 경우, 기존보다 더 밝고 불투명한 흰색 그라데이션을 사용
      gradientColors = [
        Colors.white.withOpacity(0.3), // 0.3 -> 0.6
        Colors.white.withOpacity(0.1), // 0.1 -> 0.4
      ];
      borderColor = Colors.white.withOpacity(0.4);
      activeBorderColor = Colors.white.withOpacity(0.8);
    }

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
                colors: gradientColors,
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
