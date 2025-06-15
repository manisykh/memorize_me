// services/database_service.dart

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
      'CREATE TABLE wordbooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, spreadsheetId TEXT, sheetName TEXT, dbFileName TEXT)',
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
    return Wordbook(
      id: id,
      name: wordbook.name,
      spreadsheetId: wordbook.spreadsheetId,
      sheetName: wordbook.sheetName,
      dbFileName: wordbook.dbFileName,
    );
  }

  Future<void> deleteWordbook(int id, String dbFileName) async {
    final db = await _metaDatabase;
    await db.delete('wordbooks', where: 'id = ?', whereArgs: [id]);

    // 실제 단어 DB 파일도 삭제
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- 개별 단어 데이터베이스 (단어 관리) ---

  Future<Database> _getWordDatabase(String dbFileName) async {
    // 현재 활성화된 DB가 요청된 DB와 같으면 그대로 반환
    if (_activeWordDb != null &&
        _activeWordDb!.isOpen &&
        p.basename(_activeWordDb!.path) == dbFileName) {
      return _activeWordDb!;
    }

    // 다른 DB가 활성화되어 있었다면 닫기
    await _activeWordDb?.close();

    // 새 DB를 열어서 활성화
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

  // ▼▼▼ 누락되었던 부분 추가 ▼▼▼
  Future<void> updateWord(String dbFileName, Word word) async {
    final db = await _getWordDatabase(dbFileName);
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deleteWord(String dbFileName, int id) async {
    final db = await _getWordDatabase(dbFileName);
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }
  // ▲▲▲ 누락되었던 부분 추가 ▲▲▲

  Future<void> deleteAllWords(String dbFileName) async {
    final db = await _getWordDatabase(dbFileName);
    await db.delete('words');
  }
}
