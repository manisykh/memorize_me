import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:csv/csv.dart';
import '../models/word_model.dart'; // Word 클래스를 import

class DatabaseService {
  Database? _database;
  static const String _dbName = "word_test.db";
  static const String _tableName = "words";
  static const String _prefsKey = "isDbInitialized";

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB();
    return _database!;
  }

  Future<void> _initInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_prefsKey) ?? false;
    if (!isInitialized) {
      try {
        final csvString = await rootBundle.loadString("assets/initial_words.csv");
        List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
        final db = await database;
        Batch batch = db.batch();
        for (var i = 1; i < csvTable.length; i++) {
          var row = csvTable[i];
          if (row.length >= 2) {
            batch.insert(_tableName, {'word': row[0].toString(), 'meaning': row[1].toString()});
          }
        }
        await batch.commit(noResult: true);
        await prefs.setBool(_prefsKey, true);
      } catch (e) {
        print("Could not load initial words from assets: $e");
      }
    }
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, _dbName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE $_tableName(id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL, meaning TEXT NOT NULL)',
    );
  }

  Future<List<Word>> getAllWords() async {
    await _initInitialData();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  Future<void> addWord(Word word) async {
    final db = await database;
    await db.insert(_tableName, word.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateWord(Word word) async {
    final db = await database;
    await db.update(_tableName, word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deleteWord(int id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllWords() async {
    final db = await database;
    await db.delete(_tableName);
  }
}
