import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class EnhancedNeumorphicContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final BoxShape shape;

  const EnhancedNeumorphicContainer({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 15.0,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<EnhancedNeumorphicContainer> createState() => _EnhancedNeumorphicContainerState();
}

class _EnhancedNeumorphicContainerState extends State<EnhancedNeumorphicContainer> {
  bool _isPressed = false;
  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isPressed = false);
        }
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isPressed = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius:
              widget.shape == BoxShape.rectangle
                  ? BorderRadius.circular(widget.borderRadius)
                  : null,
          shape: widget.shape,
          gradient:
              _isPressed
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDarkMode
                            ? [
                              AppTheme.gradientStart.withOpacity(0.3),
                              AppTheme.gradientEnd.withOpacity(0.3),
                            ]
                            : [
                              AppTheme.gradientStart.withOpacity(0.1),
                              AppTheme.gradientEnd.withOpacity(0.1),
                            ],
                  )
                  : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDarkMode ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                      isDarkMode ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                    ],
                  ),
          boxShadow:
              _isPressed
                  ? [
                    BoxShadow(
                      color: (isDarkMode ? AppTheme.primaryPurple : AppTheme.primaryBlue)
                          .withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: isDarkMode ? AppTheme.darkShadowDark : AppTheme.darkShadowLight,
                      offset: const Offset(8, 8),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: isDarkMode ? AppTheme.lightShadowDark : AppTheme.lightShadowLight,
                      offset: const Offset(-8, -8),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
        ),
        child: widget.child,
      ),
    );
  }
}
