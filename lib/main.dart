import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

// =======================================================================
// PART 1: 테마 및 스타일 (Theme & Styles)
// =======================================================================
class AppTheme {
  static const Color primaryBlue = Color(0xFF6366F1);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF0F172A);
  static const Color textDark = Color(0xFFE2E8F0);
  static const Color subTextLight = Color(0xFF64748B);
  static const Color subTextDark = Color(0xFF94A3B8);

  static final Color lightShadowLight = Colors.white.withOpacity(0.9);
  static final Color darkShadowLight = const Color(0xFFA3B1C6).withOpacity(0.5);
  static final Color lightShadowDark = const Color(0xFF1E293B).withOpacity(0.8);
  static const Color darkShadowDark = Color(0xFF0A0F1A);

  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);

  static final Color glassBlur = Colors.white.withOpacity(0.25);
  static final Color glassBorder = Colors.white.withOpacity(0.18);
}

// =======================================================================
// PART 2: 데이터 모델 (Data Model)
// =======================================================================
class Word {
  final int? id;
  final String word;
  final String meaning;
  Word({this.id, required this.word, required this.meaning});
  Map<String, dynamic> toMap() => {'id': id, 'word': word, 'meaning': meaning};
  factory Word.fromMap(Map<String, dynamic> map) =>
      Word(id: map['id'], word: map['word'], meaning: map['meaning']);
}

// =======================================================================
// PART 3: 서비스 (Services)
// =======================================================================
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
        debugPrint("Could not load initial words from assets: $e");
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

enum ImportOption { append, replace }

class CsvService {
  final DatabaseService _dbService;
  CsvService(this._dbService);

  Future<bool> importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      final path = result.files.single.path!;
      final csvString = await File(path).readAsString();
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (context.mounted) {
        final option = await showDialog<ImportOption>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('가져오기 옵션'),
                content: const Text('기존 단어장을 어떻게 처리할까요?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(ImportOption.append),
                    child: const Text('추가하기'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(ImportOption.replace),
                    child: const Text('새로 교체하기'),
                  ),
                ],
              ),
        );
        if (option != null) {
          if (option == ImportOption.replace) {
            await _dbService.deleteAllWords();
          }
          final words =
              csvTable
                  .skip(1)
                  .map((row) {
                    if (row.length >= 2) {
                      return Word(word: row[0].toString(), meaning: row[1].toString());
                    }
                    return null;
                  })
                  .where((word) => word != null)
                  .cast<Word>()
                  .toList();

          for (final word in words) {
            await _dbService.addWord(word);
          }
          return true;
        }
      }
    }
    return false;
  }

  Future<void> exportCsv() async {
    final words = await _dbService.getAllWords();
    if (words.isEmpty) {
      return;
    }
    final List<List<dynamic>> data = [
      ['word', 'meaning'],
      ...words.map((w) => [w.word, w.meaning]),
    ];
    final String csvString = const ListToCsvConverter().convert(data);
    final path = '${(await getTemporaryDirectory()).path}/words_export.csv';
    await File(path).writeAsString(csvString);
    await Share.shareXFiles([XFile(path)], text: '내보낸 단어장');
  }
}

class TestSheetService {
  String _getQuestionText(Word word, TestType type) {
    if (type == TestType.wordToMeaning) {
      return word.word;
    } else if (type == TestType.meaningToWord) {
      return word.meaning;
    } else if (type == TestType.meaningToWordWithHint) {
      final hint = word.word.isNotEmpty ? '${word.word[0]}${'_' * (word.word.length - 1)}' : '';
      return '${word.meaning} ($hint)';
    }
    return '';
  }

  String _getAnswerText(Word word, TestType type) {
    return (type == TestType.wordToMeaning) ? word.meaning : word.word;
  }

  List<Map<String, String>> _prepareTestData(List<Word> allWords, AppSettings settings) {
    if (allWords.isEmpty) {
      return [];
    }
    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    final sessionWords = words.take(wordCount).toList();
    final random = Random();

    List<Map<String, String>> testData = [];
    for (final word in sessionWords) {
      TestType currentType = settings.testType;
      if (currentType == TestType.random) {
        currentType = TestType.values[random.nextInt(3)];
      }
      testData.add({
        'question': _getQuestionText(word, currentType),
        'answer': _getAnswerText(word, currentType),
      });
    }
    return testData;
  }

  Future<Uint8List> _generatePdfBytes(List<Word> allWords, AppSettings settings) async {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) {
      throw Exception("시험지를 생성할 단어가 없습니다.");
    }

    final pdfDoc = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final date = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());

    if (settings.exportOption != ExportOption.answersOnly) {
      pdfDoc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(30),
            theme: pw.ThemeData.withFont(base: ttf),
          ),
          header:
              (context) => pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('단어 시험지', style: const pw.TextStyle(fontSize: 20)),
                    pw.Text(date, style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          build:
              (context) => [
                pw.SizedBox(height: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: List.generate(testData.length, (index) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: pw.Text(
                        '${index + 1}. ${testData[index]['question']}  →  _________________________',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ),
              ],
        ),
      );
    }

    if (settings.exportOption != ExportOption.testOnly) {
      pdfDoc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(30),
            theme: pw.ThemeData.withFont(base: ttf),
          ),
          header:
              (context) =>
                  pw.Header(level: 0, text: '정답지', textStyle: const pw.TextStyle(fontSize: 20)),
          build:
              (context) => [
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  // ▼▼▼ 여기에 font: ttf 추가 ▼▼▼
                  headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
                  // ▲▲▲ 여기까지 수정 ▲▲▲
                  cellStyle: pw.TextStyle(font: ttf),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: <List<String>>[
                    <String>['번호', '정답'],
                    ...testData.asMap().entries.map(
                      (entry) => ['${entry.key + 1}', entry.value['answer']!],
                    ),
                  ],
                ),
              ],
        ),
      );
    }
    return pdfDoc.save();
  }

  List<int>? _generateExcelBytes(List<Word> allWords, AppSettings settings) {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) {
      throw Exception("시험지를 생성할 단어가 없습니다.");
    }

    var excel = Excel.createExcel();
    CellStyle headerStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);

    if (settings.exportOption != ExportOption.answersOnly) {
      Sheet testSheet = excel['시험지'];
      testSheet.appendRow([
        TextCellValue('번호'),
        TextCellValue('문제'),
        TextCellValue('답란'),
      ]); // [오류 수정] const 제거
      for (var i = 0; i < 3; i++) {
        testSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle =
            headerStyle;
      }
      for (int i = 0; i < testData.length; i++) {
        testSheet.appendRow([IntCellValue(i + 1), TextCellValue(testData[i]['question']!)]);
      }
      testSheet.setColumnWidth(0, 5);
      testSheet.setColumnWidth(1, 40);
      testSheet.setColumnWidth(2, 40);
    }

    if (settings.exportOption != ExportOption.testOnly) {
      Sheet answerSheet = excel['답안지'];
      answerSheet.appendRow([TextCellValue('번호'), TextCellValue('정답')]); // [오류 수정] const 제거
      for (var i = 0; i < 2; i++) {
        answerSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle =
            headerStyle;
      }
      for (int i = 0; i < testData.length; i++) {
        answerSheet.appendRow([IntCellValue(i + 1), TextCellValue(testData[i]['answer']!)]);
      }
      answerSheet.setColumnWidth(0, 5);
      answerSheet.setColumnWidth(1, 40);
    }

    excel.delete('Sheet1');
    if (excel.sheets.keys.isNotEmpty) {
      excel.setDefaultSheet(excel.sheets.keys.first);
    }
    return excel.save();
  }

  Future<void> saveFile(String fileName, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await OpenFilex.open(path);
  }

  Future<void> shareFile(String fileName, List<int> bytes, String subject) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path)], text: subject);
  }

  Future<void> exportPdf(List<Word> allWords, AppSettings settings, {required bool share}) async {
    final bytes = await _generatePdfBytes(allWords, settings);
    if (share) {
      await shareFile('word_test.pdf', bytes, '단어 시험지');
    } else {
      await saveFile('word_test.pdf', bytes);
    }
  }

  Future<void> exportExcel(List<Word> allWords, AppSettings settings, {required bool share}) async {
    final bytes = _generateExcelBytes(allWords, settings);
    if (bytes != null) {
      if (share) {
        await shareFile('word_test.xlsx', bytes, '단어 시험지');
      } else {
        await saveFile('word_test.xlsx', bytes);
      }
    }
  }
}

// =======================================================================
// PART 4: 상태 관리 (State Management)
// =======================================================================
class WordListNotifier extends ChangeNotifier {
  final DatabaseService _dbService;
  List<Word> _words = [];
  List<Word> get words => _words;

  WordListNotifier(this._dbService) {
    loadWords();
  }
  Future<void> loadWords() async {
    _words = await _dbService.getAllWords();
    notifyListeners();
  }

  Future<void> addWord(Word word) async {
    await _dbService.addWord(word);
    await loadWords();
  }

  Future<void> updateWord(Word word) async {
    await _dbService.updateWord(word);
    await loadWords();
  }

  Future<void> deleteWord(int id) async {
    await _dbService.deleteWord(id);
    await loadWords();
  }

  Future<void> importFromCsv(BuildContext context, CsvService csvService) async {
    bool success = await csvService.importCsv(context);
    if (success) {
      await loadWords();
    }
  }
}

enum TestType { wordToMeaning, meaningToWord, meaningToWordWithHint, random }

enum ExportOption { testOnly, answersOnly, both }

class AppSettings {
  final int wordCount;
  final TestType testType;
  final ExportOption exportOption;

  AppSettings({
    this.wordCount = 20,
    this.testType = TestType.random,
    this.exportOption = ExportOption.both,
  });

  AppSettings copyWith({int? wordCount, TestType? testType, ExportOption? exportOption}) =>
      AppSettings(
        wordCount: wordCount ?? this.wordCount,
        testType: testType ?? this.testType,
        exportOption: exportOption ?? this.exportOption,
      );
}

class SettingsNotifier extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;
  void setWordCount(int count) {
    _settings = _settings.copyWith(wordCount: count);
    notifyListeners();
  }

  void setTestType(TestType type) {
    _settings = _settings.copyWith(testType: type);
    notifyListeners();
  }

  void setExportOption(ExportOption option) {
    _settings = _settings.copyWith(exportOption: option);
    notifyListeners();
  }
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}

// =======================================================================
// PART 5: 커스텀 위젯 (Custom Widgets)
// =======================================================================
class EnhancedNeumorphicContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final BoxShape shape;

  const EnhancedNeumorphicContainer({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 15.0,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<EnhancedNeumorphicContainer> createState() => _EnhancedNeumorphicContainerState();
}

class _EnhancedNeumorphicContainerState extends State<EnhancedNeumorphicContainer> {
  bool _isPressed = false;
  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isPressed = false);
        }
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isPressed = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius:
              widget.shape == BoxShape.rectangle
                  ? BorderRadius.circular(widget.borderRadius)
                  : null,
          shape: widget.shape,
          gradient:
              _isPressed
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDarkMode
                            ? [
                              AppTheme.gradientStart.withOpacity(0.3),
                              AppTheme.gradientEnd.withOpacity(0.3),
                            ]
                            : [
                              AppTheme.gradientStart.withOpacity(0.1),
                              AppTheme.gradientEnd.withOpacity(0.1),
                            ],
                  )
                  : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDarkMode ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                      isDarkMode ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                    ],
                  ),
          boxShadow:
              _isPressed
                  ? [
                    BoxShadow(
                      color: (isDarkMode ? AppTheme.primaryPurple : AppTheme.primaryBlue)
                          .withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: isDarkMode ? AppTheme.darkShadowDark : AppTheme.darkShadowLight,
                      offset: const Offset(8, 8),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: isDarkMode ? AppTheme.lightShadowDark : AppTheme.lightShadowLight,
                      offset: const Offset(-8, -8),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
        ),
        child: widget.child,
      ),
    );
  }
}

class EnhancedGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const EnhancedGlassCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GlassmorphicContainer(
      width: double.infinity,
      height: 300,
      borderRadius: 25,
      blur: 15,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.glassBlur.withOpacity(0.5), AppTheme.glassBlur.withOpacity(0.2)],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.glassBorder, AppTheme.glassBorder.withOpacity(0.1)],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDarkMode ? AppTheme.primaryPurple : AppTheme.primaryBlue).withOpacity(0.15),
              (isDarkMode ? AppTheme.gradientEnd : AppTheme.gradientStart).withOpacity(0.05),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            splashColor: AppTheme.primaryBlue.withOpacity(0.2),
            highlightColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// PART 6: 앱 화면 (Screens)
// =======================================================================
void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<CsvService>(create: (context) => CsvService(context.read<DatabaseService>())),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        ChangeNotifierProvider<WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
        ),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: '단어 학습 앱',
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.backgroundLight,
        primaryColor: AppTheme.primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryBlue,
          brightness: Brightness.light,
          secondary: AppTheme.accentGreen,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppTheme.textLight, fontSize: 16),
          bodyMedium: TextStyle(color: AppTheme.textLight),
          titleLarge: TextStyle(
            color: AppTheme.textLight,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: AppTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.backgroundLight,
          elevation: 0,
          foregroundColor: AppTheme.textLight,
          titleTextStyle: TextStyle(
            color: AppTheme.textLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansKR',
          ),
        ),
        fontFamily: 'NotoSansKR',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.backgroundDark,
        primaryColor: AppTheme.primaryPurple,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryPurple,
          brightness: Brightness.dark,
          secondary: AppTheme.accentGreen,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppTheme.textDark),
          bodyMedium: TextStyle(color: AppTheme.textDark),
          titleLarge: TextStyle(
            color: AppTheme.textDark,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: AppTheme.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.backgroundDark,
          elevation: 0,
          foregroundColor: AppTheme.textDark,
          titleTextStyle: TextStyle(
            color: AppTheme.textDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NanumGothic',
          ),
        ),
        fontFamily: 'NanumGothic',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 단어장'),
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(icon: Icon(CupertinoIcons.settings), text: '설정'),
              Tab(icon: Icon(CupertinoIcons.square_stack_3d_down_right), text: '플래시카드'),
              Tab(icon: Icon(CupertinoIcons.question_diamond), text: '퀴즈'),
            ],
          ),
        ),
        body: const TabBarView(children: [SettingsScreen(), FlashcardScreen(), QuizScreen()]),
        floatingActionButton: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: FloatingActionButton.extended(
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ManageWordsScreen())),
            backgroundColor: theme.primaryColor,
            icon: const Icon(CupertinoIcons.book_fill, color: Colors.white),
            label: const Text('단어장', style: TextStyle(color: Colors.white)),
            elevation: 8,
            highlightElevation: 12,
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;

  void _showExportOptions() {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시험지 내보내기', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              _buildExportRow('PDF', exportType: 'pdf'),
              const Divider(height: 30),
              _buildExportRow('Excel', exportType: 'excel'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportRow(String format, {required String exportType}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(format, style: theme.textTheme.titleMedium),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _handleExport(type: exportType, share: false);
              },
              icon: const Icon(Icons.save_alt, size: 20),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _handleExport(type: exportType, share: true);
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('공유'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleExport({required String type, required bool share}) async {
    setState(() => _isExporting = true);
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    final service = context.read<TestSheetService>();

    try {
      if (type == 'pdf') {
        await service.exportPdf(allWords, settings, share: share);
      } else {
        await service.exportExcel(allWords, settings, share: share);
      }
    } catch (e, s) {
      debugPrint('파일 생성/공유 중 오류: $e');
      debugPrint('Stack trace: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final themeNotifier = context.watch<ThemeNotifier>();
    final settings = settingsNotifier.settings;
    final double minValue = 1.0;
    final double maxValue = allWords.isEmpty ? 1.0 : allWords.length.toDouble();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('학습/시험 설정', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('단어 수', style: theme.textTheme.bodyLarge),
                  Row(
                    children: [
                      Text(
                        '${settings.wordCount.clamp(minValue, maxValue).toInt()}',
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 150,
                        child: Slider(
                          value: settings.wordCount.toDouble().clamp(minValue, maxValue),
                          min: minValue,
                          max: maxValue,
                          divisions:
                              allWords.isEmpty
                                  ? 1
                                  : (maxValue > minValue ? (maxValue - minValue).toInt() : 1),
                          onChanged: (value) => settingsNotifier.setWordCount(value.toInt()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: DropdownButton<TestType>(
                value: settings.testType,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: theme.scaffoldBackgroundColor,
                items: [
                  DropdownMenuItem(
                    value: TestType.random,
                    child: Text('랜덤', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.wordToMeaning,
                    child: Text('단어 → 뜻', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.meaningToWord,
                    child: Text('뜻 → 단어', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.meaningToWordWithHint,
                    child: Text('뜻 → 단어 (첫 글자 힌트)', style: theme.textTheme.bodyMedium),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setTestType(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text('내보내기', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: DropdownButton<ExportOption>(
                value: settings.exportOption,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: theme.scaffoldBackgroundColor,
                items: [
                  DropdownMenuItem(
                    value: ExportOption.both,
                    child: Text('시험지와 답안지 모두', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: ExportOption.testOnly,
                    child: Text('시험지만', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: ExportOption.answersOnly,
                    child: Text('답안지만', style: theme.textTheme.bodyMedium),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setExportOption(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _isExporting
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
              : EnhancedNeumorphicContainer(
                padding: const EdgeInsets.all(4),
                onTap: _showExportOptions,
                child: SizedBox(
                  height: 50,
                  child: Center(child: Text('시험지 내보내기', style: theme.textTheme.titleMedium)),
                ),
              ),
          const SizedBox(height: 30),
          Text('앱 설정', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('다크 모드', style: theme.textTheme.bodyLarge),
                  Switch(
                    value: themeNotifier.themeMode == ThemeMode.dark,
                    onChanged:
                        (value) =>
                            themeNotifier.setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              '총 ${allWords.length}개의 단어가 저장되어 있습니다.',
              style: TextStyle(
                color:
                    theme.brightness == Brightness.light
                        ? AppTheme.subTextLight
                        : AppTheme.subTextDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<QuizItem> _sessionItems = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _sessionActive = false;

  void _startSession() {
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
      return;
    }

    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    final sessionWords = words.take(wordCount).toList();

    final random = Random();
    _sessionItems =
        sessionWords.map((word) {
          TestType type = settings.testType;
          if (type == TestType.random) {
            type = TestType.values[random.nextInt(3)];
          }
          return QuizItem(word: word, questionType: type);
        }).toList();

    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _sessionActive = true;
    });
  }

  void _flipCard() => setState(() => _isFlipped = !_isFlipped);
  void _nextCard() {
    if (_sessionItems.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _sessionItems.length;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_sessionItems.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _sessionItems.length) % _sessionItems.length;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_sessionActive || _sessionItems.isEmpty) {
      return Center(
        child: EnhancedNeumorphicContainer(
          onTap: _startSession,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text('플래시카드 시작', style: theme.textTheme.titleMedium),
        ),
      );
    }

    final quizItem = _sessionItems[_currentIndex];
    final String frontText = getQuestionText(quizItem.word, quizItem.questionType);
    final String backText = getAnswerText(quizItem.word, quizItem.questionType);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EnhancedGlassCard(
            onTap: _flipCard,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
                return AnimatedBuilder(
                  animation: rotateAnim,
                  child: child,
                  builder: (context, child) {
                    final isUnder = (ValueKey(_isFlipped) != child?.key);
                    var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                    tilt *= isUnder ? -1.0 : 1.0;
                    final value = min(rotateAnim.value, pi / 2);
                    return Transform(
                      transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                );
              },
              child: Text(
                _isFlipped ? backText : frontText,
                key: ValueKey(_isFlipped),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${_currentIndex + 1} / ${_sessionItems.length}',
            style: TextStyle(
              color:
                  theme.brightness == Brightness.light
                      ? AppTheme.subTextLight
                      : AppTheme.subTextDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              EnhancedNeumorphicContainer(
                onTap: _prevCard,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_left),
              ),
              EnhancedNeumorphicContainer(
                onTap: _startSession,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
              EnhancedNeumorphicContainer(
                onTap: _nextCard,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuizItem {
  final Word word;
  final TestType questionType;
  QuizItem({required this.word, required this.questionType});
}

String getQuestionText(Word word, TestType type) {
  if (type == TestType.wordToMeaning) {
    return word.word;
  }
  if (type == TestType.meaningToWord) {
    return word.meaning;
  }
  if (type == TestType.meaningToWordWithHint) {
    final hint = word.word.isNotEmpty ? '${word.word[0]}${'_' * (word.word.length - 1)}' : '';
    return '${word.meaning} ($hint)';
  }
  return '';
}

String getAnswerText(Word word, TestType type) {
  return type == TestType.wordToMeaning ? word.meaning : word.word;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizItem> _sessionItems = [];
  int _currentIndex = 0;
  bool _answerShown = false;
  bool _sessionActive = false;

  void _startSession() {
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
      return;
    }

    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    final sessionWords = words.take(wordCount).toList();

    final random = Random();
    _sessionItems =
        sessionWords.map((word) {
          TestType type = settings.testType;
          if (type == TestType.random) {
            type = TestType.values[random.nextInt(3)];
          }
          return QuizItem(word: word, questionType: type);
        }).toList();

    setState(() {
      _currentIndex = 0;
      _answerShown = false;
      _sessionActive = true;
    });
  }

  void _handleAction() {
    if (_answerShown) {
      _nextQuestion();
    } else {
      setState(() {
        _answerShown = true;
      });
    }
  }

  void _nextQuestion() {
    setState(() {
      _answerShown = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (_currentIndex < _sessionItems.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          showCupertinoDialog(
            context: context,
            builder:
                (context) => CupertinoAlertDialog(
                  title: const Text('퀴즈 종료!'),
                  content: const Text('모든 문제를 다 풀었습니다.'),
                  actions: [
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      child: const Text('확인'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
          );
          setState(() {
            _sessionActive = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_sessionActive || _sessionItems.isEmpty) {
      return Center(
        child: EnhancedNeumorphicContainer(
          onTap: _startSession,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text('퀴즈 시작', style: theme.textTheme.titleMedium),
        ),
      );
    }

    final quizItem = _sessionItems[_currentIndex];
    final String questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final String answerText = getAnswerText(quizItem.word, quizItem.questionType);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_currentIndex + 1} / ${_sessionItems.length}',
            style: TextStyle(
              color:
                  theme.brightness == Brightness.light
                      ? AppTheme.subTextLight
                      : AppTheme.subTextDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          EnhancedGlassCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    questionText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
                  ),
                ),
                const Divider(indent: 40, endIndent: 40),
                AnimatedOpacity(
                  opacity: _answerShown ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      answerText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          EnhancedNeumorphicContainer(
            onTap: _handleAction,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(_answerShown ? '다음 문제' : '정답 확인', style: theme.textTheme.titleMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class ManageWordsScreen extends StatelessWidget {
  const ManageWordsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 관리'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_down_doc),
            onPressed:
                () async => await context.read<WordListNotifier>().importFromCsv(
                  context,
                  context.read<CsvService>(),
                ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_up_doc),
            onPressed: () async => await context.read<CsvService>().exportCsv(),
          ),
        ],
      ),
      body: Consumer<WordListNotifier>(
        builder: (context, notifier, child) {
          if (notifier.words.isEmpty) {
            return const Center(child: Text('저장된 단어가 없습니다.\n우측 하단 버튼으로 추가해보세요.'));
          }
          return ListView.builder(
            itemCount: notifier.words.length,
            itemBuilder: (context, index) {
              final word = notifier.words[index];
              return Slidable(
                key: ValueKey(word.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => context.read<WordListNotifier>().deleteWord(word.id!),
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '삭제',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(word.word, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    word.meaning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.brightness == Brightness.light
                              ? AppTheme.subTextLight
                              : AppTheme.subTextDark,
                    ),
                  ),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => AddEditWordScreen(word: word))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddEditWordScreen())),
          backgroundColor: theme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class AddEditWordScreen extends StatefulWidget {
  final Word? word;
  const AddEditWordScreen({super.key, this.word});
  @override
  State<AddEditWordScreen> createState() => _AddEditWordScreenState();
}

class _AddEditWordScreenState extends State<AddEditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _meaningController;
  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _meaningController = TextEditingController(text: widget.word?.meaning ?? '');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  void _saveWord() {
    if (_formKey.currentState!.validate()) {
      final notifier = context.read<WordListNotifier>();
      final newWord = Word(
        id: widget.word?.id,
        word: _wordController.text,
        meaning: _meaningController.text,
      );
      if (widget.word == null) {
        notifier.addWord(newWord);
      } else {
        notifier.updateWord(newWord);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.word == null ? '새 단어 추가' : '단어 수정')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: '단어'),
                validator: (value) => (value == null || value.isEmpty) ? '단어를 입력하세요' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _meaningController,
                decoration: const InputDecoration(labelText: '뜻'),
                validator: (value) => (value == null || value.isEmpty) ? '뜻을 입력하세요' : null,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveWord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
