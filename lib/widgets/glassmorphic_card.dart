import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isActive;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.isActive = false,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final theme = Theme.of(context);

    final Color fillColor;
    final Color borderColor;
    final Color activeBorderColor;
    final List<BoxShadow> shadows;
    final double blur;

    switch (themeNotifier.currentTheme) {
      case AppThemeType.lightGreen:
        fillColor = Colors.white.withValues(alpha: 0.96);
        borderColor = const Color(0xFFDCE8E2);
        activeBorderColor = AppTheme.primaryGreen;
        shadows = [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ];
        blur = 0.0;
        break;
      case AppThemeType.dark:
        fillColor = theme.colorScheme.surface;
        borderColor = theme.colorScheme.outline.withValues(alpha: 0.82);
        activeBorderColor = theme.colorScheme.primary;
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ];
        blur = 15.0;
        break;
      case AppThemeType.visionProtection:
        fillColor = theme.colorScheme.surface;
        borderColor = theme.colorScheme.outline;
        activeBorderColor = theme.colorScheme.primary;
        shadows = [
          BoxShadow(
            color: const Color(0xFF5B4628).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ];
        blur = 0.0;
        break;
    }

    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: radius,
                  border: Border.all(
                    color: isActive ? activeBorderColor : borderColor,
                    width: isActive ? 2.0 : 1.0,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
