import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  // --- 단어장 기반 시험지 생성 ---

  String _getQuestionText(Word word, SelfTestType type) {
    if (type == SelfTestType.wordToMeaning) return word.word;
    if (type == SelfTestType.meaningToWord) return word.meaning;
    if (type == SelfTestType.sentenceCompletion) {
      if (word.exampleSentence == null || word.exampleSentence!.isEmpty) return word.meaning;
      return word.exampleSentence!.replaceAll(RegExp(word.word, caseSensitive: false), '_________');
    }
    return '';
  }

  String _getAnswerText(Word word, SelfTestType type) {
    if (type == SelfTestType.wordToMeaning) return word.meaning;
    if (type == SelfTestType.meaningToWord) return word.word;
    if (type == SelfTestType.sentenceCompletion) return word.word;
    return '';
  }

  List<Map<String, dynamic>> _prepareTestData(List<Word> allWords, AppSettings settings) {
    if (allWords.isEmpty) return [];

    final sourceCopy = List<Word>.from(allWords);
    final random = Random();
    final sessionWords = <Word>[];
    final wordCount = settings.wordCount.clamp(1, allWords.length);

    for (int i = 0; i < wordCount; i++) {
      if (sourceCopy.isEmpty) break;
      final randomIndex = random.nextInt(sourceCopy.length);
      sessionWords.add(sourceCopy.removeAt(randomIndex));
    }

    List<Map<String, dynamic>> testData = [];
    for (final word in sessionWords) {
      final availableTypes = List<SelfTestType>.from(settings.testTypes);

      if (availableTypes.contains(SelfTestType.sentenceCompletion) &&
          (word.exampleSentence == null || word.exampleSentence!.isEmpty)) {
        availableTypes.remove(SelfTestType.sentenceCompletion);
      }

      if (availableTypes.isEmpty) {
        availableTypes.add(SelfTestType.meaningToWord);
      }

      final currentType = availableTypes[random.nextInt(availableTypes.length)];

      testData.add({
        'question': _getQuestionText(word, currentType),
        'answer': _getAnswerText(word, currentType),
        'type': currentType,
      });
    }
    return testData;
  }

  Future<void> exportPdf({
    required List<Word> allWords,
    required AppSettings settings,
    required String title,
    required bool share,
    String? savePath,
  }) async {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) throw Exception("시험지를 생성할 단어가 없습니다.");

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Bold.ttf"));

    final baseFileName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final double fontSize = settings.fontSize;

    if (settings.exportOption == ExportOption.both) {
      final questionsBytes = await _generateSingleWordTestPdf(
        title,
        testData,
        font,
        boldFont,
        isAnswerSheet: false,
        fontSize: fontSize,
      );
      final answersBytes = await _generateSingleWordTestPdf(
        '$title - 정답',
        testData,
        font,
        boldFont,
        isAnswerSheet: true,
        fontSize: fontSize,
      );
      final questionFileName = '$baseFileName.pdf';
      final answerFileName = '${baseFileName}_answers.pdf';

      if (share) {
        await _shareFiles(
          [questionFileName, answerFileName],
          [questionsBytes, answersBytes],
          title,
        );
      } else {
        assert(savePath != null, 'Save path must be provided when not sharing.');
        await _saveFileToPath('$savePath/$questionFileName', questionsBytes);
        await _saveFileToPath('$savePath/$answerFileName', answersBytes);
        OpenFilex.open('$savePath/$questionFileName');
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
        fontSize: fontSize,
      );
      final fileName = '$baseFileName.pdf';

      if (share) {
        await _shareFile(fileName, bytes, title);
      } else {
        assert(savePath != null, 'Save path must be provided when not sharing.');
        final fullPath = '$savePath/$fileName';
        await _saveFileToPath(fullPath, bytes);
        OpenFilex.open(fullPath);
      }
    }
  }

  Future<void> exportExcel(
    List<Word> allWords,
    AppSettings settings, {
    required bool share,
    String? savePath,
  }) async {
    final bytes = _generateExcelBytes(allWords, settings);
    if (bytes != null) {
      const fileName = 'word_test.xlsx';
      if (share) {
        await _shareFile(fileName, bytes, '단어 시험지');
      } else {
        assert(savePath != null, 'Save path must be provided when not sharing.');
        final fullPath = '$savePath/$fileName';
        await _saveFileToPath(fullPath, bytes);
        OpenFilex.open(fullPath);
      }
    }
  }

  Future<Uint8List> _generateSingleWordTestPdf(
    String docTitle,
    List<Map<String, dynamic>> testData,
    pw.Font font,
    pw.Font boldFont, {
    required bool isAnswerSheet,
    required double fontSize,
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
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize + 6),
                  ),
                  if (!isAnswerSheet) pw.Text(date, style: pw.TextStyle(fontSize: fontSize - 2)),
                ],
              ),
            ),
        build: (context) {
          if (isAnswerSheet) {
            return [
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
                cellStyle: pw.TextStyle(fontSize: fontSize),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['번호', '정답'],
                  ...testData.asMap().entries.map(
                    (entry) => ['${entry.key + 1}', entry.value['answer']! as String],
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
                  final questionData = testData[index];
                  final type = questionData['type'] as SelfTestType;
                  final questionText = questionData['question'] as String;

                  final questionContent =
                      type == SelfTestType.sentenceCompletion
                          ? questionText
                          : '$questionText  →  _________________________';

                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 35,
                        child: pw.Text('${index + 1}.', style: pw.TextStyle(fontSize: fontSize)),
                      ),
                      pw.Expanded(
                        child: pw.Text(questionContent, style: pw.TextStyle(fontSize: fontSize)),
                      ),
                    ],
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

  List<int>? _generateExcelBytes(List<Word> allWords, AppSettings settings) {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) throw Exception("시험지를 생성할 단어가 없습니다.");
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
        testSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(testData[i]['question']! as String),
        ]);
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
        answerSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(testData[i]['answer']! as String),
        ]);
      }
      answerSheet.setColumnWidth(0, 5);
      answerSheet.setColumnWidth(1, 40);
    }
    excel.delete('Sheet1');
    if (excel.sheets.keys.isNotEmpty) excel.setDefaultSheet(excel.sheets.keys.first);
    return excel.save();
  }

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
        await _shareFiles(
          [questionFileName, answerFileName],
          [questionsBytes, answersBytes],
          title,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        await _saveFileToPath('${directory.path}/$questionFileName', questionsBytes);
        await _saveFileToPath('${directory.path}/$answerFileName', answersBytes);
        OpenFilex.open('${directory.path}/$questionFileName');
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
        await _shareFile(fileName, questionsBytes, title);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fullPath = '${directory.path}/$fileName';
        await _saveFileToPath(fullPath, questionsBytes);
        OpenFilex.open(fullPath);
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
    int questionCounter = 0;
    return pw.ListView.separated(
      itemCount: questions.length,
      separatorBuilder: (context, index) => pw.Divider(height: 20, color: PdfColors.grey400),
      itemBuilder: (context, index) {
        final q = questions[index];
        if (q.type == 'reading_section') {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (q.passage != null)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(q.passage!),
                ),
              pw.SizedBox(height: 12),
              ...?q.questions?.map((subQ) {
                questionCounter++;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$questionCounter. ${subQ.question}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children:
                          subQ.options.asMap().entries.map((optEntry) {
                            final isCorrect = optEntry.value == subQ.answer;
                            return pw.Row(
                              children: [
                                pw.Text('${optEntry.key + 1}) ${optEntry.value}'),
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
                    if (isAnswerSheet && subQ.explanation != null && subQ.explanation!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4, left: 12),
                        child: pw.Text(
                          '└ 해설: ${subQ.explanation}',
                          style: const pw.TextStyle(color: PdfColors.blueGrey, fontSize: 9),
                        ),
                      ),
                    if (!isAnswerSheet)
                      pw.Container(
                        padding: const pw.EdgeInsets.only(top: 8),
                        child: pw.Text('정답: ________________'),
                      ),
                    pw.SizedBox(height: 12),
                  ],
                );
              }),
            ],
          );
        } else {
          questionCounter++;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (q.script != null)
                pw.Text('듣기 지문: ${q.script!}', style: const pw.TextStyle(color: PdfColors.grey600)),
              if (q.question != null) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  '$questionCounter. ${q.question!}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
              if (q.options != null) ...[
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children:
                      q.options!.asMap().entries.map((entry) {
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
              ],
              if (isAnswerSheet && q.explanation != null && q.explanation!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, left: 12),
                  child: pw.Text(
                    '└ 해설: ${q.explanation}',
                    style: const pw.TextStyle(color: PdfColors.blueGrey, fontSize: 9),
                  ),
                ),
              if (!isAnswerSheet && q.question != null)
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text('정답: ________________'),
                ),
            ],
          );
        }
      },
    );
  }

  Future<void> _saveFileToPath(String fullPath, List<int> bytes) async {
    final file = File(fullPath);
    await file.writeAsBytes(bytes);
  }

  Future<void> _shareFiles(
    List<String> fileNames,
    List<Uint8List> bytesList,
    String subject,
  ) async {
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

  Future<void> _shareFile(String fileName, List<int> bytes, String subject) async {
    await _shareFiles([fileName], [Uint8List.fromList(bytes)], subject);
  }
}
