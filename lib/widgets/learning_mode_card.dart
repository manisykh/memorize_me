import 'package:flutter/material.dart';
import 'scale_button.dart';

class LearningModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String heroTag;
  final Color? accentColor;

  const LearningModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.heroTag,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = accentColor ?? theme.colorScheme.primary;
    final color =
        theme.brightness == Brightness.dark ? Color.lerp(baseColor, Colors.white, 0.26)! : baseColor;

    return ScaleButton(
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            constraints: const BoxConstraints(minHeight: 138),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha:
                      theme.brightness == Brightness.dark ? 0.22 : 0.06,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
