import 'package:flutter/material.dart';
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
    this.borderRadius = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isVision = theme.primaryColor == const Color(0xFFC76E40);

    final Color fillColor;
    final Color borderColor;
    final Color activeBorderColor;
    final List<BoxShadow> shadows;

    if (isDark) {
      fillColor = theme.colorScheme.surface;
      borderColor = Colors.white.withValues(alpha: 0.16);
      activeBorderColor = theme.colorScheme.primary;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 18,
          spreadRadius: -12,
          offset: const Offset(0, 8),
        ),
      ];
    } else if (isVision) {
      fillColor = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outline;
      activeBorderColor = theme.colorScheme.primary;
      shadows = [
        BoxShadow(
          color: const Color(0xFF7F5431).withValues(alpha: 0.10),
          blurRadius: 16,
          spreadRadius: -12,
          offset: const Offset(0, 7),
        ),
      ];
    } else {
      fillColor = const Color(0xFFFFFCF7);
      borderColor = const Color(0xFFE5D8C8);
      activeBorderColor = AppTheme.accentCoral;
      shadows = [
        BoxShadow(
          color: AppTheme.ink.withValues(alpha: 0.075),
          blurRadius: 18,
          spreadRadius: -14,
          offset: const Offset(0, 10),
        ),
      ];
    }

    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
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
                  width: isActive ? 1.4 : 1.0,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
