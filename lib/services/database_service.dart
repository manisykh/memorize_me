// lib/services/database_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';

Future<List<Word>> _getAllWordsInBackground(Map<String, dynamic> params) async {
  final String dbFileName = params['dbFileName'];
  final RootIsolateToken rootIsolateToken = params['token'];
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String path = p.join(documentsDirectory.path, dbFileName);
  final db = await openDatabase(path, singleInstance: false);
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
    return await openDatabase(path, version: 6, onCreate: _createMetaDB, onUpgrade: _onUpgrade);
  }

  Future<void> _createMetaDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE wordbooks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, spreadsheetId TEXT, sheetName TEXT, dbFileName TEXT, source TEXT)',
    );
    await db.execute(
      "CREATE TABLE incorrect_words(id INTEGER PRIMARY KEY AUTOINCREMENT, wordbookName TEXT, word TEXT, meaning TEXT, additionalMeanings TEXT NOT NULL DEFAULT '[]')",
    );
    await _createStudyPlansTable(db);
    await _addFlexiblePlanColumns(db);
    await _createStudyHistoryTables(db);
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
          debugPrint("Error adding column: $e");
        }
        break;
      case 4:
        await _createStudyPlansTable(db);
        break;
      case 5:
        await db.execute(
          "ALTER TABLE incorrect_words ADD COLUMN additionalMeanings TEXT NOT NULL DEFAULT '[]'",
        );
        break;
      case 6:
        await _addFlexiblePlanColumns(db);
        await _createStudyHistoryTables(db);
        break;
    }
  }

  Future<void> _createStudyPlansTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS study_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wordbookId INTEGER,
        dbFileName TEXT NOT NULL UNIQUE,
        wordbookName TEXT NOT NULL,
        totalWords INTEGER NOT NULL DEFAULT 0,
        chunkSize INTEGER NOT NULL DEFAULT 20,
        dailyNewTarget INTEGER NOT NULL DEFAULT 20,
        startDate TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        createdAt TEXT NOT NULL
      )''');
  }

  Future<void> _addFlexiblePlanColumns(Database db) async {
    await db.execute("ALTER TABLE study_plans ADD COLUMN mode TEXT NOT NULL DEFAULT 'scheduled'");
    await db.execute('ALTER TABLE study_plans ADD COLUMN bundleCount INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE study_plans ADD COLUMN selectedBundle INTEGER NOT NULL DEFAULT 1');
    await db.execute('ALTER TABLE study_plans ADD COLUMN revision INTEGER NOT NULL DEFAULT 1');
    await db.execute("ALTER TABLE study_plans ADD COLUMN wordOrder TEXT NOT NULL DEFAULT '[]'");
    await db.execute('ALTER TABLE study_plans ADD COLUMN scheduleWordKeys TEXT');
  }

  Future<void> _createStudyHistoryTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS study_sessions(
      sessionId TEXT PRIMARY KEY, dbFileName TEXT NOT NULL,
      startedAt TEXT NOT NULL, data TEXT NOT NULL)''');
    await db.execute('CREATE INDEX IF NOT EXISTS study_sessions_book_date ON study_sessions(dbFileName, startedAt)');
    await db.execute('''CREATE TABLE IF NOT EXISTS study_plan_versions(
      dbFileName TEXT NOT NULL, revision INTEGER NOT NULL,
      effectiveFrom TEXT NOT NULL, data TEXT NOT NULL,
      PRIMARY KEY(dbFileName, revision))''');
  }

  Future<List<Map<String, dynamic>>> getStudySessions() async {
    final db = await _metaDatabase;
    final rows = await db.query('study_sessions', orderBy: 'startedAt');
    return rows.map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> saveStudySession(Map<String, dynamic> data) async {
    final db = await _metaDatabase;
    await db.insert('study_sessions', {
      'sessionId': data['id'], 'dbFileName': data['dbFileName'],
      'startedAt': data['startedAt'], 'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getStudyPlanVersions() async {
    final db = await _metaDatabase;
    return db.query('study_plan_versions', orderBy: 'effectiveFrom');
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
    await db.delete('study_plans', where: 'dbFileName = ?', whereArgs: [dbFileName]);
    await db.delete('study_sessions', where: 'dbFileName = ?', whereArgs: [dbFileName]);
    await db.delete('study_plan_versions', where: 'dbFileName = ?', whereArgs: [dbFileName]);
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
          'additionalMeanings': word.toMap()['additionalMeanings'],
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

  Future<List<StudyPlan>> getStudyPlans() async {
    final db = await _metaDatabase;
    final maps = await db.query('study_plans', orderBy: 'createdAt DESC');
    final plans = <StudyPlan>[];
    for (final map in maps) {
      var plan = StudyPlan.fromMap(map);
      if (plan.wordOrder.isEmpty && plan.totalWords > 0) {
        // Freeze legacy ordering once, without loading all word content at startup.
        final wordDb = await _openWordDB(plan.dbFileName);
        late final List<Map<String, dynamic>> rows;
        try {
          rows = await wordDb.query('words', columns: ['id'], orderBy: 'id ASC');
        } finally {
          await wordDb.close();
        }
        final keys = rows.map((row) => '${row['id']}').toList();
        plan = plan.copyWith(wordOrder: keys, scheduleWordKeys: keys);
        final frozen = plan;
        await db.transaction((txn) async {
          await txn.update('study_plans', {
            'wordOrder': jsonEncode(keys), 'scheduleWordKeys': jsonEncode(keys),
          }, where: 'id = ?', whereArgs: [frozen.id]);
          await txn.insert('study_plan_versions', {
            'dbFileName': frozen.dbFileName, 'revision': frozen.revision,
            'effectiveFrom': frozen.startDate, 'data': jsonEncode(frozen.toMap()),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        });
      }
      plans.add(plan);
    }
    return plans;
  }

  Future<int> nextStudyPlanRevision(String dbFileName) async {
    final db = await _metaDatabase;
    final rows = await db.rawQuery(
      'SELECT MAX(revision) AS revision FROM study_plan_versions WHERE dbFileName = ?', [dbFileName]);
    return ((rows.first['revision'] as int?) ?? 0) + 1;
  }

  Future<StudyPlan> saveStudyPlan(StudyPlan plan) async {
    final db = await _metaDatabase;
    final map = plan.toMap();
    map.remove('id');
    final id = await db.transaction((txn) async {
      final previous = await txn.query('study_plans', where: 'dbFileName = ?', whereArgs: [plan.dbFileName]);
      if (previous.isNotEmpty) {
        final old = StudyPlan.fromMap(previous.first);
        await txn.insert('study_plan_versions', {
          'dbFileName': old.dbFileName, 'revision': old.revision,
          'effectiveFrom': old.startDate, 'data': jsonEncode(old.toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.insert('study_plan_versions', {
        'dbFileName': plan.dbFileName, 'revision': plan.revision,
        'effectiveFrom': studyDateKey(DateTime.now()), 'data': jsonEncode(plan.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (previous.isNotEmpty) {
        final existingId = previous.first['id'] as int;
        await txn.update('study_plans', map, where: 'id = ?', whereArgs: [existingId]);
        return existingId;
      }
      return txn.insert('study_plans', map);
    });
    return plan.copyWith(id: id);
  }

  Future<void> deleteStudyPlan(int id) async {
    final db = await _metaDatabase;
    final rows = await db.query('study_plans', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final old = StudyPlan.fromMap(rows.first);
      await saveStudyPlan(old.copyWith(status: StudyPlanStatus.paused, revision: old.revision + 1));
    }
    await db.delete('study_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<Database> _openWordDB(String dbFileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, dbFileName);
    return await openDatabase(
      path,
      singleInstance: false,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE words(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            meaning TEXT NOT NULL,
            additionalMeanings TEXT NOT NULL DEFAULT '[]',
            exampleSentence TEXT,
            exampleSentenceTranslation TEXT, -- ▼▼▼ [추가]
            srsLevel INTEGER NOT NULL DEFAULT 0,
            nextReviewDate TEXT,
            lastReviewedAt TEXT,
            incorrectCount INTEGER NOT NULL DEFAULT 0,
            correctStreak INTEGER NOT NULL DEFAULT 0,
            pendingMcqReview INTEGER NOT NULL DEFAULT 0,
            pendingSpellingReview INTEGER NOT NULL DEFAULT 0
          )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          await _upgradeWordDB(db, v);
        }
      },
    );
  }

  Future<void> _upgradeWordDB(Database db, int version) async {
    try {
      if (version == 2) {
        await db.execute('ALTER TABLE words ADD COLUMN srsLevel INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE words ADD COLUMN nextReviewDate TEXT');
      }
      if (version == 4) {
        await db.execute('ALTER TABLE words ADD COLUMN incorrectCount INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE words ADD COLUMN correctStreak INTEGER NOT NULL DEFAULT 0');
      }
      if (version == 5) {
        // ▼▼▼ [추가] 버전 5에 대한 스키마 업그레이드
        await db.execute('ALTER TABLE words ADD COLUMN exampleSentenceTranslation TEXT');
      }
      if (version == 6) {
        await db.execute('ALTER TABLE words ADD COLUMN lastReviewedAt TEXT');
      }
      if (version == 7) {
        await db.execute(
          'ALTER TABLE words ADD COLUMN pendingMcqReview INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE words ADD COLUMN pendingSpellingReview INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (version == 8) {
        await db.execute(
          "ALTER TABLE words ADD COLUMN additionalMeanings TEXT NOT NULL DEFAULT '[]'",
        );
      }
    } catch (e) {
      debugPrint("Error upgrading WordDB to v$version: $e. It might already exist.");
    }
  }

  Future<List<Word>> getAllWords(String dbFileName) async {
    final token = RootIsolateToken.instance;
    if (token == null) {
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

  Future<void> updateWordSrsBatch(String dbFileName, List<Word> words) async {
    if (words.isEmpty) return;
    final db = await _openWordDB(dbFileName);
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final word in words) {
        batch.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
      }
      await batch.commit(noResult: true);
    });
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

  Future<List<Word>> searchWordsInWordbook(String dbFileName, String query) async {
    if (query.isEmpty) return [];

    final db = await _openWordDB(dbFileName);
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'word LIKE ? OR meaning LIKE ? OR additionalMeanings LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    await db.close();

    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }
}
