import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';

class DatabaseService {
  Database? _metaDb;
  Database? _activeWordDb;

  // --- 메타 데이터베이스 (단어장 목록 관리) ---

  Future<Database> get _metaDatabase async {
    if (_metaDb != null) return _metaDb!;
    _metaDb = await _initMetaDB();
    return _metaDb!;
  }

  Future<Database> _initMetaDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, "meta.db");
    return await openDatabase(path, version: 1, onCreate: _createMetaDB);
  }

  Future<void> _createMetaDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE wordbooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, spreadsheetId TEXT, sheetName TEXT, dbFileName TEXT, source TEXT)',
    );
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
    // ▼▼▼ 수정된 부분 ▼▼▼
    // 반환하는 Wordbook 객체에 'source'를 포함시킵니다.
    return Wordbook(
      id: id,
      name: wordbook.name,
      spreadsheetId: wordbook.spreadsheetId,
      sheetName: wordbook.sheetName,
      dbFileName: wordbook.dbFileName,
      source: wordbook.source, // 누락되었던 source 추가
    );
    // ▲▲▲ 수정된 부분 ▲▲▲
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

  // --- 개별 단어 데이터베이스 (단어 관리) ---

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
