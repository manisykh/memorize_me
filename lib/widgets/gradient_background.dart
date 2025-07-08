import 'package:flutter/material.dart';
import '../themes/app_theme.dart'; // ▼▼▼ [수정] 새로운 테마를 가져오기 위해 import

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // ▼▼▼ [수정] 하드코딩된 색상 대신 AppTheme에 정의된 그라데이션을 사용합니다.
        gradient: AppTheme.lightGreenGradient,
      ),
      child: child,
    );
  }
}
