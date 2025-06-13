import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../themes/app_theme.dart';

class EnhancedGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const EnhancedGlassCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GlassmorphicContainer(
      width: double.infinity,
      height: 300,
      borderRadius: 25,
      blur: 15,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.glassBlur.withOpacity(0.5), AppTheme.glassBlur.withOpacity(0.2)],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.glassBorder, AppTheme.glassBorder.withOpacity(0.1)],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDarkMode ? AppTheme.primaryPurple : AppTheme.primaryBlue).withOpacity(0.15),
              (isDarkMode ? AppTheme.gradientEnd : AppTheme.gradientStart).withOpacity(0.05),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            splashColor: AppTheme.primaryBlue.withOpacity(0.2),
            highlightColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
