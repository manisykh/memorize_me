import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/study_plan_model.dart';
import 'package:memorize_app/services/study_history_service.dart';
import 'package:memorize_app/widgets/bundle_history_panel.dart';

void main() {
  testWidgets('bundle history starts with the whole book and browsing does not change the learning bundle', (tester) async {
    const plan = StudyPlan(wordbookId: 1, dbFileName: 'bundle-test.db', wordbookName: 'Book',
      totalWords: 8, chunkSize: 4, dailyNewTarget: 4, startDate: '2026-09-03',
      createdAt: '2026-09-03', mode: StudyPlanMode.free, bundleCount: 2);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Padding(padding: EdgeInsets.all(16), child: BundleHistoryPanel(
        plan: plan, overallHistory: WordbookStudyHistory()))))));
    expect(find.text('전체 단어장'), findsOneWidget);
    expect(find.text('묶음별'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.text('묶음별'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2번 묶음').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>)).initialValue, 2);
    expect(plan.currentChunk(), 1);
    await tester.tap(find.text('전체 단어장'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
