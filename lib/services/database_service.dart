import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';

class DatabaseService {
  Database? _metaDb;

  // --- 메타 데이터베이스 (단어장 목록, 오답노트 등) ---
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
          print("Error adding column: $e");
        }
        break;
    }
  }

  // --- 단어장 목록 관련 메서드 ---
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

  // --- 오답노트 관련 메서드 ---
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

  // --- 개별 단어장 DB 접근 메서드 (구조 개선) ---

  Future<Database> _openWordDB(String dbFileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, meaning TEXT NOT NULL)',
        );
      },
    );
  }

  Future<List<Word>> getAllWords(String dbFileName) async {
    final db = await _openWordDB(dbFileName);
    final List<Map<String, dynamic>> maps = await db.query('words', orderBy: 'id DESC');
    await db.close();
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
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
        // toMap() 대신 toMapForInsert()를 사용하여 id를 제외하고 insert
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
