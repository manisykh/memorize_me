// services/database_service.dart (수정 후)

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';

class DatabaseService {
  Database? _metaDb;

  // --- 메타 데이터베이스 (단어장 목록 및 오답노트 관리) ---
  Future<Database> get _metaDatabase async {
    if (_metaDb != null) return _metaDb!;
    _metaDb = await _initMetaDB();
    return _metaDb!;
  }

  Future<Database> _initMetaDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, "meta.db");

    return await openDatabase(
      path,
      version: 2, // 버전은 2로 유지합니다.
      // onCreate는 DB 파일이 없을 때만 호출됩니다.
      onCreate: _createMetaDB,

      // onUpgrade는 기존 사용자의 DB 버전이 낮을 때만 호출됩니다.
      onUpgrade: (db, oldVersion, newVersion) async {
        // 버전 1 -> 2로 업데이트하는 사용자는 incorrect_words 테이블이 없으므로 생성해줍니다.
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE incorrect_words(id INTEGER PRIMARY KEY AUTOINCREMENT, wordbookName TEXT, word TEXT, meaning TEXT, UNIQUE(wordbookName, word))',
          );
        }
      },
    );
  }

  Future<void> _createMetaDB(Database db, int version) async {
    // 앱을 처음 설치할 때 생성될 테이블들을 정의합니다.
    // wordbooks 테이블 생성
    await db.execute(
      'CREATE TABLE wordbooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, spreadsheetId TEXT, sheetName TEXT, dbFileName TEXT, source TEXT)',
    );
    // incorrect_words 테이블 생성
    await db.execute(
      'CREATE TABLE incorrect_words(id INTEGER PRIMARY KEY AUTOINCREMENT, wordbookName TEXT, word TEXT, meaning TEXT, UNIQUE(wordbookName, word))',
    );
  }

  // --- 오답노트 관련 메소드들 ---

  // 오답 단어 추가 (중복 방지)
  Future<void> addIncorrectWords(String wordbookName, List<Word> words) async {
    if (words.isEmpty) return;
    final db = await _metaDatabase;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final word in words) {
        batch.insert(
          'incorrect_words',
          {'wordbookName': wordbookName, 'word': word.word, 'meaning': word.meaning},
          conflictAlgorithm: ConflictAlgorithm.ignore, // 중복된 단어는 무시
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // 오답노트 목록 가져오기 (예: ["Day1", "Day2"])
  Future<List<String>> getIncorrectWordbookNames() async {
    final db = await _metaDatabase;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT wordbookName FROM incorrect_words ORDER BY wordbookName',
    );
    return List.generate(maps.length, (i) => maps[i]['wordbookName'] as String);
  }

  // 특정 오답노트의 단어들 가져오기
  Future<List<Word>> getIncorrectWords(String wordbookName) async {
    final db = await _metaDatabase;
    final List<Map<String, dynamic>> maps = await db.query(
      'incorrect_words',
      where: 'wordbookName = ?',
      whereArgs: [wordbookName],
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // 특정 오답노트 삭제
  Future<void> deleteIncorrectWordbook(String wordbookName) async {
    final db = await _metaDatabase;
    await db.delete('incorrect_words', where: 'wordbookName = ?', whereArgs: [wordbookName]);
  }

  // --- 기존 단어장 관련 메소드들 (수정 없음) ---
  Database? _activeWordDb;

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
    return Wordbook(
      id: id,
      name: wordbook.name,
      spreadsheetId: wordbook.spreadsheetId,
      sheetName: wordbook.sheetName,
      dbFileName: wordbook.dbFileName,
      source: wordbook.source,
    );
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

  Future<Database> _getWordDatabase(String dbFileName) async {
    if (_activeWordDb != null &&
        _activeWordDb!.isOpen &&
        p.basename(_activeWordDb!.path) == dbFileName) {
      return _activeWordDb!;
    }
    await _activeWordDb?.close();
    _activeWordDb = await _initWordDB(dbFileName);
    return _activeWordDb!;
  }

  Future<Database> _initWordDB(String dbFileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    return await openDatabase(path, version: 1, onCreate: _createWordDB);
  }

  Future<void> _createWordDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE words(id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, meaning TEXT NOT NULL)',
    );
  }

  Future<List<Word>> getAllWords(String dbFileName) async {
    final db = await _getWordDatabase(dbFileName);
    final List<Map<String, dynamic>> maps = await db.query('words', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  Future<void> addWord(String dbFileName, Word word) async {
    final db = await _getWordDatabase(dbFileName);
    await db.insert('words', word.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateWord(String dbFileName, Word word) async {
    final db = await _getWordDatabase(dbFileName);
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deleteWord(String dbFileName, int id) async {
    final db = await _getWordDatabase(dbFileName);
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllWords(String dbFileName) async {
    final db = await _getWordDatabase(dbFileName);
    await db.delete('words');
  }

  Future<void> addWordsInBatch(String dbFileName, List<Word> words) async {
    if (words.isEmpty) return;

    final db = await _getWordDatabase(dbFileName);
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final word in words) {
        batch.insert('words', word.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }
}
