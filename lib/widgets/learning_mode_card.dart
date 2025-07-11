// widgets/learning_mode_card.dart (새 파일)

import 'package:flutter/material.dart';
import 'glassmorphic_card.dart'; // 기존에 만든 GlassmorphicCard 재활용

class LearningModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String heroTag; // Hero 애니메이션을 위한 태그

  const LearningModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Hero(
      tag: heroTag,
      child: Material(
        type: MaterialType.transparency, // Hero 애니메이션을 위해 필요
        child: GlassmorphicCard(
          onTap: onTap,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7)),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
