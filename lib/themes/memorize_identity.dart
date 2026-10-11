import 'package:flutter/material.dart';

/// Memorize Me의 화면별 리빌딩에서 공통으로 사용할 시각 언어입니다.
///
/// 홈 탭을 기준으로 색상, 간격, 모서리와 터치 크기를 한곳에 모아
/// 이후 복습·통계·달력·AI·설정 탭이 같은 정체성을 공유할 수 있게 합니다.
@immutable
class MemorizeIdentity {
  final Color canvas;
  final Color surface;
  final Color ink;
  final Color mutedInk;
  final Color primaryAction;
  final Color success;
  final Color review;
  final Color scheduled;
  final Color softContext;
  final Color softSuccess;
  final Color softReview;
  final Color softScheduled;
  final Color softInfo;
  final Color border;

  const MemorizeIdentity({
    required this.canvas,
    required this.surface,
    required this.ink,
    required this.mutedInk,
    required this.primaryAction,
    required this.success,
    required this.review,
    required this.scheduled,
    required this.softContext,
    required this.softSuccess,
    required this.softReview,
    required this.softScheduled,
    required this.softInfo,
    required this.border,
  });

  static const double pagePadding = 20;
  static const double sectionGap = 24;
  static const double cardRadius = 14;
  static const double contextRadius = 12;
  static const double minimumTapTarget = 44;

  factory MemorizeIdentity.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isVision = theme.primaryColor == const Color(0xFFC76E40);

    if (isDark) {
      return MemorizeIdentity(
        canvas: theme.scaffoldBackgroundColor,
        surface: scheme.surface,
        ink: scheme.onSurface,
        mutedInk: scheme.onSurfaceVariant,
        primaryAction: const Color(0xFF4F8FFF),
        success: const Color(0xFF38C98B),
        review: const Color(0xFFFF756E),
        scheduled: const Color(0xFF9B8CFF),
        softContext: const Color(0xFF2D3B48),
        softSuccess: const Color(0xFF243D35),
        softReview: const Color(0xFF462E2D),
        softScheduled: const Color(0xFF342F52),
        softInfo: const Color(0xFF2B3852),
        border: scheme.outline,
      );
    }

    if (isVision) {
      return MemorizeIdentity(
        canvas: theme.scaffoldBackgroundColor,
        surface: scheme.surface,
        ink: scheme.onSurface,
        mutedInk: scheme.onSurfaceVariant,
        primaryAction: const Color(0xFFC76E40),
        success: const Color(0xFF5C8A6E),
        review: const Color(0xFFE08A52),
        scheduled: const Color(0xFF7D67C7),
        softContext: const Color(0xFFF2E6D3),
        softSuccess: const Color(0xFFE3EBD9),
        softReview: const Color(0xFFF5E0CF),
        softScheduled: const Color(0xFFECE6F7),
        softInfo: const Color(0xFFE8DDCF),
        border: scheme.outline,
      );
    }

    return const MemorizeIdentity(
      canvas: Color(0xFFF8FAFD),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF09255A),
      mutedInk: Color(0xFF5F6F8D),
      primaryAction: Color(0xFF1E73F7),
      success: Color(0xFF00B875),
      review: Color(0xFFFF5B55),
      scheduled: Color(0xFF6D5CE7),
      softContext: Color(0xFFEAF4FF),
      softSuccess: Color(0xFFE8F8F0),
      softReview: Color(0xFFFFEEEC),
      softScheduled: Color(0xFFF0EDFF),
      softInfo: Color(0xFFEAF2FF),
      border: Color(0xFFD9E2F0),
    );
  }
}
