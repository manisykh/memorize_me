import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memorize_app/themes/app_theme.dart';
import 'package:memorize_app/widgets/glassmorphic_card.dart';

void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.lightGreenTheme,
    'dark': AppTheme.darkTheme,
    'vision': AppTheme.visionProtectionTheme,
  };

  for (final entry in themes.entries) {
    testWidgets('card supports ListTile ink in ${entry.key} theme', (
      tester,
    ) async {
      var tileTaps = 0;
      var cardTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Scaffold(
            body: GlassmorphicCard(
              onTap: () => cardTaps++,
              child: ListTile(
                title: const Text('Choose book'),
                selected: true,
                selectedTileColor: Colors.green,
                onTap: () => tileTaps++,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Choose book'));
      await tester.pumpAndSettle();
      expect(tileTaps, 1);
      expect(cardTaps, 0);
      expect(tester.takeException(), isNull);

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(GlassmorphicCard),
          matching: find.byType(Ink),
        ).first,
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(
        decoration.color,
        entry.key == 'light'
            ? const Color(0xFFFFFCF7)
            : entry.value.colorScheme.surface,
      );
    });
  }

  testWidgets('card preserves border, spacing and padded tap area', (
    tester,
  ) async {
    const contentKey = Key('content');
    var taps = 0;

    for (final active in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightGreenTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: GlassmorphicCard(
                  isActive: active,
                  onTap: () => taps++,
                  child: const SizedBox(key: contentKey, height: 40),
                ),
              ),
            ),
          ),
        ),
      );

      final borderWidth = active ? 1.4 : 1.0;
      final cardRect = tester.getRect(find.byType(GlassmorphicCard));
      final contentRect = tester.getRect(find.byKey(contentKey));
      expect(contentRect.left - cardRect.left, closeTo(16 + borderWidth, 0.001));
      expect(contentRect.top - cardRect.top, closeTo(16 + borderWidth, 0.001));
      expect(cardRect.height, closeTo(40 + 2 * (16 + borderWidth), 0.001));

      final decoration =
          tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
      expect(
        decoration.border,
        Border.all(
          color: active ? AppTheme.accentCoral : const Color(0xFFE5D8C8),
          width: borderWidth,
        ),
      );

      await tester.tapAt(Offset(cardRect.center.dx, cardRect.top + 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
  });
}
