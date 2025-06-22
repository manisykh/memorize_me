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
import 'package:share_plus/share_plus.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';

enum PdfExportType { questionsOnly, withAnswers }

class TestSheetService {
  // --- 1. 기존 단어장 기반 시험지 생성 기능 ---

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

  Future<void> exportPdf({
    required List<Word> allWords,
    required AppSettings settings,
    required String title,
    required bool share,
  }) async {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) {
      throw Exception("시험지를 생성할 단어가 없습니다.");
    }

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Bold.ttf"));

    final baseFileName = title.replaceAll(' ', '_');

    if (settings.exportOption == ExportOption.both) {
      final questionsBytes = await _generateSingleWordTestPdf(
        title,
        testData,
        font,
        boldFont,
        isAnswerSheet: false,
      );
      final answersBytes = await _generateSingleWordTestPdf(
        '$title - 정답',
        testData,
        font,
        boldFont,
        isAnswerSheet: true,
      );

      final questionFileName = '$baseFileName.pdf';
      final answerFileName = '${baseFileName}_answers.pdf';

      if (share) {
        await shareFiles([questionFileName, answerFileName], [questionsBytes, answersBytes], title);
      } else {
        await saveFile(questionFileName, questionsBytes);
        await saveFile(answerFileName, answersBytes);
      }
    } else {
      final isAnswerOnly = settings.exportOption == ExportOption.answersOnly;
      final docTitle = isAnswerOnly ? '$title - 정답' : title;
      final bytes = await _generateSingleWordTestPdf(
        docTitle,
        testData,
        font,
        boldFont,
        isAnswerSheet: isAnswerOnly,
      );
      final fileName = '$baseFileName.pdf';

      if (share) {
        await shareFile(fileName, bytes, title);
      } else {
        await saveFile(fileName, bytes);
      }
    }
  }

  Future<Uint8List> _generateSingleWordTestPdf(
    String docTitle,
    List<Map<String, String>> testData,
    pw.Font font,
    pw.Font boldFont, {
    required bool isAnswerSheet,
  }) async {
    final pdfDoc = pw.Document();
    final date = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        ),
        header:
            (context) => pw.Header(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    docTitle,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
                  ),
                  if (!isAnswerSheet) pw.Text(date, style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
        build: (context) {
          if (isAnswerSheet) {
            return [
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['번호', '정답'],
                  ...testData.asMap().entries.map(
                    (entry) => ['${entry.key + 1}', entry.value['answer']!],
                  ),
                ],
              ),
            ];
          } else {
            return [
              pw.ListView.separated(
                itemCount: testData.length,
                separatorBuilder: (context, index) => pw.SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return pw.Text(
                    '${index + 1}. ${testData[index]['question']}  →  _________________________',
                  );
                },
              ),
            ];
          }
        },
      ),
    );
    return pdfDoc.save();
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

  List<int>? _generateExcelBytes(List<Word> allWords, AppSettings settings) {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) {
      throw Exception("시험지를 생성할 단어가 없습니다.");
    }

    var excel = Excel.createExcel();
    CellStyle headerStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);

    if (settings.exportOption != ExportOption.answersOnly) {
      Sheet testSheet = excel['시험지'];
      testSheet.appendRow([TextCellValue('번호'), TextCellValue('문제'), TextCellValue('답란')]);
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
      answerSheet.appendRow([TextCellValue('번호'), TextCellValue('정답')]);
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

  // --- 2. AI 퀴즈용 PDF 생성 기능 ---

  Future<void> exportAiQuizAsPdf({
    required List<AiQuestion> questions,
    required String title,
    required PdfExportType exportType,
    required bool share,
  }) async {
    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Bold.ttf"));

    if (exportType == PdfExportType.withAnswers) {
      final questionsBytes = await _generateSingleAiPdf(
        title,
        questions,
        font,
        boldFont,
        isAnswerSheet: false,
      );
      final answersBytes = await _generateSingleAiPdf(
        '$title - 정답',
        questions,
        font,
        boldFont,
        isAnswerSheet: true,
      );

      final questionFileName = '${title.replaceAll(' ', '_')}.pdf';
      final answerFileName = '${title.replaceAll(' ', '_')}_answers.pdf';

      if (share) {
        await shareFiles([questionFileName, answerFileName], [questionsBytes, answersBytes], title);
      } else {
        await saveFile(questionFileName, questionsBytes);
        await saveFile(answerFileName, answersBytes);
      }
    } else {
      final questionsBytes = await _generateSingleAiPdf(
        title,
        questions,
        font,
        boldFont,
        isAnswerSheet: false,
      );
      final fileName = '${title.replaceAll(' ', '_')}.pdf';
      if (share) {
        await shareFile(fileName, questionsBytes, title);
      } else {
        await saveFile(fileName, questionsBytes);
      }
    }
  }

  Future<Uint8List> _generateSingleAiPdf(
    String docTitle,
    List<AiQuestion> questions,
    pw.Font font,
    pw.Font boldFont, {
    required bool isAnswerSheet,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header:
            (context) => pw.Header(
              child: pw.Text(
                docTitle,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
              ),
            ),
        build: (context) => [_buildAiQuizPage(questions, isAnswerSheet: isAnswerSheet)],
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildAiQuizPage(List<AiQuestion> questions, {required bool isAnswerSheet}) {
    return pw.ListView.separated(
      itemCount: questions.length,
      separatorBuilder: (context, index) => pw.Divider(height: 20),
      itemBuilder: (context, index) {
        final q = questions[index];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (q.passage != null)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Text(q.passage!),
              ),
            if (q.script != null)
              pw.Text('듣기 지문: ${q.script!}', style: const pw.TextStyle(color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Text(
              '${index + 1}. ${q.question}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children:
                  q.options.asMap().entries.map((entry) {
                    final isCorrect = entry.value == q.answer;
                    return pw.Row(
                      children: [
                        pw.Text('${entry.key + 1}) ${entry.value}'),
                        if (isAnswerSheet && isCorrect)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(
                              '(정답)',
                              style: pw.TextStyle(
                                color: PdfColors.red,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
            ),
            if (!isAnswerSheet)
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text('정답: ________________'),
              ),
          ],
        );
      },
    );
  }

  // --- 3. 범용 파일 처리 기능 ---

  Future<void> saveFile(String fileName, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await OpenFilex.open(path);
  }

  Future<void> shareFiles(List<String> fileNames, List<Uint8List> bytesList, String subject) async {
    final directory = await getTemporaryDirectory();
    final xFiles = <XFile>[];
    for (int i = 0; i < fileNames.length; i++) {
      final path = '${directory.path}/${fileNames[i]}';
      final file = File(path);
      await file.writeAsBytes(bytesList[i]);
      xFiles.add(XFile(path));
    }
    await Share.shareXFiles(xFiles, text: subject);
  }

  Future<void> shareFile(String fileName, List<int> bytes, String subject) async {
    await shareFiles([fileName], [Uint8List.fromList(bytes)], subject);
  }
}
