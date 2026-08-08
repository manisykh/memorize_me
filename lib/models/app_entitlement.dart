enum AppPlan { free, pro, founding }

enum AppFeature {
  googleSheetsImport,
  csvImport,
  basicWordbooks,
  flashcards,
  srsReview,
  basicQuiz,
  basicStatistics,
  pdfExport,
  advancedAiOptions,
  customPrompts,
  automaticModelFallback,
  unlimitedWordbooks,
  detailedStatistics,
  wordbookMerge,
  cloudSync,
  adFree,
}

extension AppFeatureAccess on AppFeature {
  bool get isAlwaysFree {
    return const {
      AppFeature.googleSheetsImport,
      AppFeature.csvImport,
      AppFeature.basicWordbooks,
      AppFeature.flashcards,
      AppFeature.srsReview,
      AppFeature.basicQuiz,
      AppFeature.basicStatistics,
    }.contains(this);
  }
}

class EntitlementSnapshot {
  const EntitlementSnapshot({
    this.plan = AppPlan.free,
    this.foundingMember = false,
    this.claimedAt,
    this.isServerConfirmed = false,
  });

  final AppPlan plan;
  final bool foundingMember;
  final DateTime? claimedAt;
  final bool isServerConfirmed;

  bool get hasFullAccess => plan == AppPlan.pro || plan == AppPlan.founding;

  static AppPlan parsePlan(Object? value) {
    return AppPlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => AppPlan.free,
    );
  }
}
