import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:memorize_app/models/wordbook_model.dart';
import 'package:memorize_app/providers/word_list_provider.dart';
import 'package:memorize_app/providers/wordbook_manager.dart';
import 'package:memorize_app/services/database_service.dart';
import 'package:memorize_app/widgets/wordbook_selection_dialog.dart';

class _SelectionManager extends WordbookManager {
  _SelectionManager(super.db, super.notifier, this.books);

  final List<Wordbook> books;

  @override
  List<Wordbook> get wordbooks => books;

  @override
  Wordbook? get activeWordbook => books.first;
}

void main() {
  late WordListNotifier notifier;
  late _SelectionManager manager;

  setUp(() {
    final db = DatabaseService();
    notifier = WordListNotifier(db);
    manager = _SelectionManager(db, notifier, [
      for (var id = 1; id <= 2; id++)
        Wordbook(
          id: id,
          name: 'Book $id',
          dbFileName: 'book_$id.db',
          source: WordbookSource.localCsv,
        ),
    ]);
  });

  tearDown(() {
    manager.dispose();
    notifier.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> openSelector(
    WidgetTester tester,
    ValueChanged<Wordbook?> onSelected,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<WordbookManager>.value(
        value: manager,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  onSelected(await showWordbookSelectionDialog(context));
                },
                child: const Text('Open selector'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open selector'));
    await settle(tester);
  }

  testWidgets('radio selection keeps the active book and returns another book', (tester) async {
    Wordbook? selected;
    await openSelector(tester, (book) => selected = book);

    expect(tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue, 1);
    await tester.tap(find.text('Book 1'));
    await settle(tester);
    expect(selected, isNull);
    expect(find.byType(RadioGroup<int>), findsOneWidget);

    await tester.tap(find.text('Book 2'));
    await settle(tester);
    expect(selected, same(manager.books[1]));
    expect(find.byType(RadioGroup<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the selector does not choose a book', (tester) async {
    var completed = false;
    Wordbook? selected;
    await openSelector(tester, (book) {
      completed = true;
      selected = book;
    });

    final context = tester.element(find.byType(RadioGroup<int>));
    Navigator.of(context).pop();
    await settle(tester);

    expect(completed, isTrue);
    expect(selected, isNull);
    expect(manager.activeWordbook, same(manager.books.first));
    expect(tester.takeException(), isNull);
  });
}
