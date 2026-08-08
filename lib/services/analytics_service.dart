import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> setPlan(String plan) => _safe(
    () => _analytics.setUserProperty(name: 'app_plan', value: plan),
  );

  Future<void> logOnboardingCompleted() => _log('onboarding_completed');

  Future<void> logFoundingRegistrationCompleted() =>
      _log('founding_registration_completed');

  Future<void> logWordbookImported({
    required String source,
    required int wordbookCount,
  }) => _log(
    'wordbook_import_completed',
    parameters: {'source': source, 'wordbook_count': wordbookCount},
  );

  Future<void> logStudyStarted({required String mode, required int wordCount}) => _log(
    'study_session_started',
    parameters: {'mode': mode, 'word_count': wordCount},
  );

  Future<void> logStudyCompleted({
    required String mode,
    required int wordCount,
  }) => _log(
    'study_session_completed',
    parameters: {'mode': mode, 'word_count': wordCount},
  );

  Future<void> logQuizCompleted({required String mode, required int questionCount}) => _log(
    'quiz_completed',
    parameters: {'mode': mode, 'question_count': questionCount},
  );

  Future<void> logAiGenerationStarted({
    required String generationType,
    required int requestedCount,
  }) => _log(
    'ai_generation_started',
    parameters: {'generation_type': generationType, 'requested_count': requestedCount},
  );

  Future<void> logAiGenerationCompleted({
    required String generationType,
    required int generatedCount,
    required bool usedFallback,
  }) => _log(
    'ai_generation_completed',
    parameters: {
      'generation_type': generationType,
      'generated_count': generatedCount,
      'used_fallback': usedFallback ? 1 : 0,
    },
  );

  Future<void> logExportCompleted({required String format, required String source}) => _log(
    'study_material_exported',
    parameters: {'format': format, 'source': source},
  );

  Future<void> logTabViewed(String tab) => _log(
    'main_tab_viewed',
    parameters: {'tab': tab},
  );

  Future<void> _log(String name, {Map<String, Object>? parameters}) {
    return _safe(() => _analytics.logEvent(name: name, parameters: parameters));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('AnalyticsService: event skipped: $error');
    }
  }
}
