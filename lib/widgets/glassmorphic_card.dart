import 'package:flutter/material.dart';
import '../themes/memorize_identity.dart';

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
    this.borderRadius = MemorizeIdentity.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final isDark = theme.brightness == Brightness.dark;
    final shadows = <BoxShadow>[
      if (!isDark)
        BoxShadow(
          color: identity.ink.withValues(alpha: 0.035),
          blurRadius: 12,
          spreadRadius: -10,
          offset: const Offset(0, 6),
        ),
    ];

    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            // Paint on Material so child tiles and tap effects stay visible.
            child: Ink(
              padding: padding,
              decoration: BoxDecoration(
                color: isActive ? identity.softInfo : identity.surface,
                borderRadius: radius,
                border: Border.all(
                  color: isActive ? identity.primaryAction : identity.border,
                  width: isActive ? 1.5 : 1.0,
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
