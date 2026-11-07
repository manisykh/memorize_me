import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/providers/word_list_provider.dart';
import 'package:memorize_app/services/database_service.dart';

class _ControlledDatabaseService extends DatabaseService {
  final Map<String, List<Completer<List<Word>>>> requests = {};

  @override
  Future<List<Word>> getAllWords(String dbFileName) {
    final completer = Completer<List<Word>>();
    requests.putIfAbsent(dbFileName, () => []).add(completer);
    return completer.future;
  }
}

Word _word(int id, String text) => Word(id: id, word: text, meaning: text);

void main() {
  test('같은 단어장의 동시 로딩은 진행 중인 요청을 공유한다', () async {
    final database = _ControlledDatabaseService();
    final notifier = WordListNotifier(database);

    final first = notifier.loadWords('a.db');
    final second = notifier.loadWords('a.db');

    expect(database.requests['a.db'], hasLength(1));
    database.requests['a.db']!.single.complete([_word(1, 'one')]);
    await Future.wait([first, second]);

    expect(notifier.activeDbFileName, 'a.db');
    expect(notifier.words.single.word, 'one');
  });

  test('늦게 끝난 이전 단어장 요청은 현재 단어장을 덮어쓰지 않는다', () async {
    final database = _ControlledDatabaseService();
    final notifier = WordListNotifier(database);

    final first = notifier.loadWords('a.db');
    final second = notifier.loadWords('b.db');

    database.requests['b.db']!.single.complete([_word(2, 'two')]);
    await second;
    database.requests['a.db']!.single.complete([_word(1, 'one')]);
    await first;

    expect(notifier.activeDbFileName, 'b.db');
    expect(notifier.words.single.word, 'two');
  });

  test('저장된 학습 결과는 전체 재조회 없이 메모리 목록에 반영된다', () async {
    final database = _ControlledDatabaseService();
    final notifier = WordListNotifier(database);

    final load = notifier.loadWords('a.db');
    database.requests['a.db']!.single.complete([
      _word(1, 'one'),
      _word(2, 'two'),
    ]);
    await load;

    notifier.applyUpdatedWords('a.db', [_word(2, 'updated')]);

    expect(database.requests['a.db'], hasLength(1));
    expect(notifier.words.map((word) => word.word), ['one', 'updated']);
  });
}
