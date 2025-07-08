import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';

// 백그라운드 Isolate에서 단어를 가져올 최상위 함수
Future<List<Word>> _getAllWordsInBackground(Map<String, dynamic> params) async {
  final String dbFileName = params['dbFileName'];
  final RootIsolateToken rootIsolateToken = params['token'];

  // 전달받은 토큰으로 백그라운드 스레드의 통신을 초기화합니다.
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String path = p.join(documentsDirectory.path, dbFileName);

  final db = await openDatabase(path);
  final List<Map<String, dynamic>> maps = await db.query('words', orderBy: 'id DESC');
  await db.close();

  return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
}

class DatabaseService {
  Database? _metaDb;

  Future<Database> get _metaDatabase async {
    if (_metaDb != null) return _metaDb!;
    _metaDb = await _initMetaDB();
    return _metaDb!;
  }

  Future<Database> _initMetaDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, "meta.db");

    return await openDatabase(path, version: 3, onCreate: _createMetaDB, onUpgrade: _onUpgrade);
  }

  Future<void> _createMetaDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE wordbooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, spreadsheetId TEXT, sheetName TEXT, dbFileName TEXT, source TEXT)',
    );
    await db.execute(
      'CREATE TABLE incorrect_words(id INTEGER PRIMARY KEY AUTOINCREMENT, wordbookName TEXT, word TEXT, meaning TEXT)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      await _runUpgrade(db, version);
    }
  }

  Future<void> _runUpgrade(Database db, int version) async {
    switch (version) {
      case 2:
        await db.execute(
          'CREATE TABLE incorrect_words(id INTEGER PRIMARY KEY, word TEXT, meaning TEXT, UNIQUE(word, meaning))',
        );
        break;
      case 3:
        try {
          await db.execute(
            'ALTER TABLE incorrect_words ADD COLUMN wordbookName TEXT DEFAULT "오답노트"',
          );
        } catch (e) {
          // ignore: avoid_print
          print("Error adding column: $e");
        }
        break;
    }
  }

  Future<List<Wordbook>> getWordbooks() async {
    final db = await _metaDatabase;
    final List<Map<String, dynamic>> maps = await db.query('wordbooks', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Wordbook.fromMap(maps[i]));
  }

  Future<Wordbook> addWordbook(Wordbook wordbook) async {
    final db = await _metaDatabase;
    final id = await db.insert(
      'wordbooks',
      wordbook.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return wordbook.copyWith(id: id);
  }

  Future<void> deleteWordbook(int id, String dbFileName) async {
    final db = await _metaDatabase;
    await db.delete('wordbooks', where: 'id = ?', whereArgs: [id]);

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> addIncorrectWords(String wordbookName, List<Word> words) async {
    if (words.isEmpty) return;
    final db = await _metaDatabase;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final word in words) {
        batch.insert('incorrect_words', {
          'wordbookName': wordbookName,
          'word': word.word,
          'meaning': word.meaning,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> getIncorrectWordbookNames() async {
    final db = await _metaDatabase;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT wordbookName FROM incorrect_words ORDER BY wordbookName',
    );
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) => maps[i]['wordbookName'] as String);
  }

  Future<List<Word>> getIncorrectWords(String wordbookName) async {
    final db = await _metaDatabase;
    final List<Map<String, dynamic>> maps = await db.query(
      'incorrect_words',
      where: 'wordbookName = ?',
      whereArgs: [wordbookName],
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  Future<void> deleteIncorrectWordbook(String wordbookName) async {
    final db = await _metaDatabase;
    await db.delete('incorrect_words', where: 'wordbookName = ?', whereArgs: [wordbookName]);
  }

  Future<Database> _openWordDB(String dbFileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    return await openDatabase(
      path,
      version: 2, // 버전을 1에서 2로 올립니다.
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, meaning TEXT NOT NULL, exampleSentence TEXT)', // 생성 시에도 컬럼 추가
        );
      },
      // ▼▼▼ [추가] 기존 DB를 업그레이드하는 로직 ▼▼▼
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE words ADD COLUMN exampleSentence TEXT');
        }
      },
    );
  }

  Future<List<Word>> getAllWords(String dbFileName) async {
    final token = RootIsolateToken.instance;
    if (token == null) {
      // This is a fallback for rare cases where the token might not be available.
      // It runs the operation on the main thread, which could cause a freeze,
      // but prevents a crash.
      return _getAllWordsInBackground({
        'dbFileName': dbFileName,
        'token': RootIsolateToken.instance,
      });
    }

    final params = {'dbFileName': dbFileName, 'token': token};
    return compute(_getAllWordsInBackground, params);
  }

  Future<void> addWord(String dbFileName, Word word) async {
    final db = await _openWordDB(dbFileName);
    await db.insert('words', word.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.close();
  }

  Future<void> addWordsInBatch(String dbFileName, List<Word> words) async {
    if (words.isEmpty) return;
    final db = await _openWordDB(dbFileName);
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final word in words) {
        batch.insert('words', word.toMapForInsert(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    await db.close();
  }

  Future<void> updateWord(String dbFileName, Word word) async {
    final db = await _openWordDB(dbFileName);
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
    await db.close();
  }

  Future<void> deleteWord(String dbFileName, int id) async {
    final db = await _openWordDB(dbFileName);
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
    await db.close();
  }

  Future<void> deleteAllWords(String dbFileName) async {
    final db = await _openWordDB(dbFileName);
    await db.delete('words');
    await db.close();
  }
}
