import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart'; // AppSettings를 위해 import
import 'package:share_plus/share_plus.dart';

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
