// lib/services/test_sheet_service.dart

import 'dart:convert';
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
  final HtmlEscape _htmlEscape = const HtmlEscape();

  String _getQuestionText(Word word, SelfTestType type) {
    if (type == SelfTestType.wordToMeaning) return word.word;
    if (type == SelfTestType.meaningToWord) return word.meaning;
    if (type == SelfTestType.sentenceCompletion) {
      if (word.exampleSentence == null || word.exampleSentence!.isEmpty) return word.meaning;
      final pattern = RegExp(r'\b' + RegExp.escape(word.word) + r'\b', caseSensitive: false);
      return word.exampleSentence!.replaceAll(pattern, '_________');
    }
    return '';
  }

  String _getAnswerText(Word word, SelfTestType type) {
    if (type == SelfTestType.wordToMeaning) return word.meaning;
    if (type == SelfTestType.meaningToWord) return word.word;
    if (type == SelfTestType.sentenceCompletion) return word.word;
    return '';
  }

  bool _canUseSpellingHint(SelfTestType type) {
    return type == SelfTestType.meaningToWord || type == SelfTestType.sentenceCompletion;
  }

  String _buildSpellingHint(String answer) {
    final chars = answer.runes.map((codePoint) => String.fromCharCode(codePoint)).toList();
    final letterIndexes = <int>[];

    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      if (RegExp(r'[A-Za-z가-힣0-9]').hasMatch(char)) {
        letterIndexes.add(i);
      }
    }

    if (letterIndexes.isEmpty) return '';

    final visible = <int>{letterIndexes.first};
    if (letterIndexes.length >= 4) {
      visible.add(letterIndexes.last);
    }

    return chars.asMap().entries.map((entry) {
      final index = entry.key;
      final char = entry.value;
      if (char.trim().isEmpty) return '   ';
      if (!RegExp(r'[A-Za-z가-힣0-9]').hasMatch(char)) return char;
      return visible.contains(index) ? char : '_';
    }).join(' ');
  }

  bool _isSameWord(Word a, Word b) {
    if (a.id != null && b.id != null) return a.id == b.id;
    return identical(a, b) || (a.word == b.word && a.meaning == b.meaning);
  }

  List<String> _buildMultipleChoiceOptions({
    required List<Word> allWords,
    required Word questionWord,
    required SelfTestType type,
    required String answer,
    required Random random,
  }) {
    final normalizedAnswer = answer.trim().toLowerCase();
    if (normalizedAnswer.isEmpty) return const [];

    final distractorSet = <String>{};
    for (final candidate in allWords) {
      if (_isSameWord(candidate, questionWord)) continue;
      final candidateAnswer = _getAnswerText(candidate, type).trim();
      if (candidateAnswer.isEmpty) continue;
      if (candidateAnswer.toLowerCase() == normalizedAnswer) continue;
      distractorSet.add(candidateAnswer);
    }

    final distractors = distractorSet.toList()..shuffle(random);
    final options = <String>[answer.trim(), ...distractors.take(3)]..shuffle(random);
    return options.length > 1 ? options : const [];
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
          (word.exampleSentence == null ||
              word.exampleSentence!.isEmpty ||
              word.exampleSentenceTranslation == null ||
              word.exampleSentenceTranslation!.isEmpty)) {
        availableTypes.remove(SelfTestType.sentenceCompletion);
      }

      if (availableTypes.isEmpty) {
        availableTypes.add(SelfTestType.meaningToWord);
      }

      final currentType = availableTypes[random.nextInt(availableTypes.length)];
      final questionText = _getQuestionText(word, currentType);
      final answerText = _getAnswerText(word, currentType);
      final questionData = <String, dynamic>{
        'question': questionText,
        'answer': answerText,
        'additionalMeanings': word.additionalMeanings,
        'type': currentType,
        'questionFormat': TestQuestionFormat.shortAnswer,
        'translation':
            currentType == SelfTestType.sentenceCompletion ? word.exampleSentenceTranslation : null,
      };

      if (settings.questionFormat == TestQuestionFormat.multipleChoice) {
        final options = _buildMultipleChoiceOptions(
          allWords: allWords,
          questionWord: word,
          type: currentType,
          answer: answerText,
          random: random,
        );
        if (options.isNotEmpty) {
          questionData['questionFormat'] = TestQuestionFormat.multipleChoice;
          questionData['options'] = options;
        }
      }

      if (settings.questionFormat == TestQuestionFormat.shortAnswer &&
          settings.includeSpellingHint &&
          _canUseSpellingHint(currentType)) {
        final hint = _buildSpellingHint(answerText);
        if (hint.isNotEmpty) questionData['hint'] = hint;
      }

      testData.add(questionData);
    }
    return testData;
  }

  String _optionLabel(int index) => '${String.fromCharCode(65 + index)}.';

  List<String> _questionOptions(Map<String, dynamic> questionData) {
    final rawOptions = questionData['options'];
    if (rawOptions is List) {
      return rawOptions.map((option) => option.toString()).toList();
    }
    return const [];
  }

  String _answerTextForDisplay(Map<String, dynamic> questionData) {
    final answer = questionData['answer'] as String? ?? '';
    final options = _questionOptions(questionData);
    final answerIndex = options.indexWhere((option) => option.trim() == answer.trim());
    final primaryAnswer = answerIndex >= 0 ? '${_optionLabel(answerIndex)} $answer' : answer;
    final additionalMeanings = _additionalMeanings(questionData);
    if (additionalMeanings.isEmpty) return primaryAnswer;
    return '$primaryAnswer\n추가 뜻: ${additionalMeanings.join(' · ')}';
  }

  List<String> _additionalMeanings(Map<String, dynamic> questionData) {
    final raw = questionData['additionalMeanings'];
    if (raw is! List) return const [];
    return raw.map((meaning) => meaning.toString().trim()).where((meaning) => meaning.isNotEmpty).toList();
  }

  Future<void> exportPdf({
    required List<Word> allWords,
    required AppSettings settings,
    required String title,
    required bool share,
    String? savePath,
    bool openAfterSave = true,
  }) async {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) throw Exception("시험지를 생성할 단어가 없습니다.");

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansKR-Bold.ttf"));

    final baseFileName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    if (settings.exportOption == ExportOption.both) {
      final questionsBytes = await _generateSingleWordTestPdf(
        title,
        testData,
        font,
        boldFont,
        settings,
        isAnswerSheet: false,
      );
      final answersBytes = await _generateSingleWordTestPdf(
        '$title - 정답',
        testData,
        font,
        boldFont,
        settings,
        isAnswerSheet: true,
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
        if (openAfterSave) OpenFilex.open('$savePath/$questionFileName');
      }
    } else {
      final isAnswerOnly = settings.exportOption == ExportOption.answersOnly;
      final docTitle = isAnswerOnly ? '$title - 정답' : title;
      final bytes = await _generateSingleWordTestPdf(
        docTitle,
        testData,
        font,
        boldFont,
        settings,
        isAnswerSheet: isAnswerOnly,
      );
      final fileName = '$baseFileName.pdf';

      if (share) {
        await _shareFile(fileName, bytes, title);
      } else {
        assert(savePath != null, 'Save path must be provided when not sharing.');
        final fullPath = '$savePath/$fileName';
        await _saveFileToPath(fullPath, bytes);
        if (openAfterSave) OpenFilex.open(fullPath);
      }
    }
  }

  Future<void> exportExcel(
    List<Word> allWords,
    AppSettings settings, {
    required String title,
    required bool share,
    String? savePath,
    bool openAfterSave = true,
  }) async {
    final bytes = _generateExcelBytes(allWords, settings);
    if (bytes != null) {
      final fileName = '${_safeFileName(title)}.xlsx';
      if (share) {
        await _shareFile(fileName, bytes, title);
      } else {
        assert(savePath != null, 'Save path must be provided when not sharing.');
        final fullPath = '$savePath/$fileName';
        await _saveFileToPath(fullPath, bytes);
        if (openAfterSave) OpenFilex.open(fullPath);
      }
    }
  }

  Future<void> exportInteractiveHtml({
    required List<Word> allWords,
    required AppSettings settings,
    required String title,
    required bool share,
    String? savePath,
    bool openAfterSave = true,
  }) async {
    final testData = _prepareTestData(allWords, settings);
    if (testData.isEmpty) throw Exception("시험지를 생성할 단어가 없습니다.");

    final html = _generateWordTestHtml(title, testData, settings);
    final bytes = utf8.encode(html);
    final fileName = '${_safeFileName(title)}.html';

    if (share) {
      await _shareFile(fileName, bytes, title);
    } else {
      assert(savePath != null, 'Save path must be provided when not sharing.');
      final fullPath = '$savePath/$fileName';
      await _saveFileToPath(fullPath, bytes);
      if (openAfterSave) OpenFilex.open(fullPath);
    }
  }

  Future<Uint8List> _generateSingleWordTestPdf(
    String docTitle,
    List<Map<String, dynamic>> testData,
    pw.Font font,
    pw.Font boldFont,
    AppSettings settings, {
    required bool isAnswerSheet,
  }) async {
    final pdfDoc = pw.Document();
    final date = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
    final double fontSize = settings.fontSize;

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
                columnWidths: {0: const pw.FixedColumnWidth(45), 1: const pw.FlexColumnWidth()},
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
                cellStyle: pw.TextStyle(fontSize: fontSize),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['번호', '정답'],
                  ...testData.asMap().entries.map(
                    (entry) => ['${entry.key + 1}', _answerTextForDisplay(entry.value)],
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
                  final translation = questionData['translation'] as String?;
                  final options = _questionOptions(questionData);
                  final hint = questionData['hint'] as String?;

                  final questionContent =
                      options.isNotEmpty || type == SelfTestType.sentenceCompletion
                          ? questionText
                          : '$questionText  →  _________________________';

                  return pw.Table(
                    columnWidths: {0: const pw.FixedColumnWidth(45), 1: const pw.FlexColumnWidth()},
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Text('${index + 1}.', style: pw.TextStyle(fontSize: fontSize)),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(questionContent, style: pw.TextStyle(fontSize: fontSize)),
                              if (options.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 6.0),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children:
                                        options.asMap().entries.map((optionEntry) {
                                          return pw.Padding(
                                            padding: const pw.EdgeInsets.only(bottom: 3.0),
                                            child: pw.Text(
                                              '${_optionLabel(optionEntry.key)} ${optionEntry.value}',
                                              style: pw.TextStyle(fontSize: fontSize - 1),
                                            ),
                                          );
                                    }).toList(),
                                  ),
                                ),
                              if (hint != null && hint.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 5.0),
                                  child: pw.Text(
                                    '힌트: $hint',
                                    style: pw.TextStyle(
                                      fontSize: fontSize - 1,
                                      color: PdfColors.blueGrey700,
                                    ),
                                  ),
                                ),
                              if (settings.includeTranslation &&
                                  translation != null &&
                                  translation.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 4.0),
                                  child: pw.Text(
                                    '(해석: $translation)',
                                    style: pw.TextStyle(
                                      fontSize: fontSize - 2,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
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
    final excelFontSize = settings.fontSize.round().clamp(8, 20).toInt();
    CellStyle headerStyle = CellStyle(
      bold: true,
      fontSize: excelFontSize,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    CellStyle bodyStyle = CellStyle(
      fontSize: excelFontSize,
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );
    if (settings.exportOption != ExportOption.answersOnly) {
      Sheet testSheet = excel['시험지'];
      testSheet.appendRow([
        TextCellValue('번호'),
        TextCellValue('유형'),
        TextCellValue('문제'),
        TextCellValue('힌트'),
        TextCellValue('선택지'),
        TextCellValue('답란'),
      ]);
      for (var i = 0; i < 6; i++) {
        testSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle =
            headerStyle;
      }
      for (int i = 0; i < testData.length; i++) {
        final questionData = testData[i];
        final type = questionData['type'] as SelfTestType;
        final options = _questionOptions(questionData);
        final optionText =
            options.asMap().entries.map((entry) => '${_optionLabel(entry.key)} ${entry.value}').join('\n');
        testSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(_selfTestTypeLabel(type)),
          TextCellValue(questionData['question']! as String),
          TextCellValue(questionData['hint'] as String? ?? ''),
          TextCellValue(optionText),
          TextCellValue(options.isEmpty ? '____________________' : '선택지에서 고르세요'),
        ]);
        for (var column = 0; column < 6; column++) {
          testSheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: i + 1)).cellStyle =
              bodyStyle;
        }
      }
      testSheet.setColumnWidth(0, 5);
      testSheet.setColumnWidth(1, 14);
      testSheet.setColumnWidth(2, 44);
      testSheet.setColumnWidth(3, 28);
      testSheet.setColumnWidth(4, 44);
      testSheet.setColumnWidth(5, 24);
    }
    if (settings.exportOption != ExportOption.testOnly) {
      Sheet answerSheet = excel['답안지'];
      answerSheet.appendRow([TextCellValue('번호'), TextCellValue('유형'), TextCellValue('정답')]);
      for (var i = 0; i < 3; i++) {
        answerSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle =
            headerStyle;
      }
      for (int i = 0; i < testData.length; i++) {
        final questionData = testData[i];
        final type = questionData['type'] as SelfTestType;
        answerSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(_selfTestTypeLabel(type)),
          TextCellValue(_answerTextForDisplay(questionData)),
        ]);
        for (var column = 0; column < 3; column++) {
          answerSheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: i + 1)).cellStyle =
              bodyStyle;
        }
      }
      answerSheet.setColumnWidth(0, 5);
      answerSheet.setColumnWidth(1, 14);
      answerSheet.setColumnWidth(2, 40);
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

    const int questionsPerPdf = 40;
    final List<List<AiQuestion>> questionChunks = [];
    List<AiQuestion> currentChunk = [];
    int currentChunkQuestionCount = 0;

    for (final question in questions) {
      int questionBlockSize =
          (question.type == 'reading_section' && question.questions != null)
              ? question.questions!.length
              : 1;

      if (currentChunk.isNotEmpty &&
          (currentChunkQuestionCount + questionBlockSize > questionsPerPdf)) {
        questionChunks.add(currentChunk);
        currentChunk = [];
        currentChunkQuestionCount = 0;
      }

      currentChunk.add(question);
      currentChunkQuestionCount += questionBlockSize;
    }

    if (currentChunk.isNotEmpty) {
      questionChunks.add(currentChunk);
    }

    final totalParts = questionChunks.length;
    final List<String> fileNames = [];
    final List<Uint8List> fileBytes = [];

    for (int i = 0; i < totalParts; i++) {
      final chunk = questionChunks[i];
      final partNumber = i + 1;
      final docTitle = totalParts > 1 ? '$title ($partNumber/$totalParts)' : title;
      final baseFileName = docTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      if (exportType == PdfExportType.withAnswers) {
        final questionsBytes = await _generateSingleAiPdf(
          docTitle,
          chunk,
          font,
          boldFont,
          isAnswerSheet: false,
        );
        final answersBytes = await _generateSingleAiPdf(
          '$docTitle - 정답',
          chunk,
          font,
          boldFont,
          isAnswerSheet: true,
        );
        fileNames.add('$baseFileName.pdf');
        fileBytes.add(questionsBytes);
        fileNames.add('${baseFileName}_answers.pdf');
        fileBytes.add(answersBytes);
      } else {
        final questionsBytes = await _generateSingleAiPdf(
          docTitle,
          chunk,
          font,
          boldFont,
          isAnswerSheet: false,
        );
        fileNames.add('$baseFileName.pdf');
        fileBytes.add(questionsBytes);
      }
    }

    if (share) {
      await _shareFiles(fileNames, fileBytes, title);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      for (int i = 0; i < fileNames.length; i++) {
        await _saveFileToPath('${directory.path}/${fileNames[i]}', fileBytes[i]);
      }
      OpenFilex.open('${directory.path}/${fileNames.first}');
    }
  }

  Future<void> exportAiQuizAsInteractiveHtml({
    required List<AiQuestion> questions,
    required String title,
    required bool share,
    String? savePath,
  }) async {
    final html = _generateAiQuizHtml(title, questions);
    final bytes = utf8.encode(html);
    final fileName = '${_safeFileName(title)}.html';

    if (share) {
      await _shareFile(fileName, bytes, title);
    } else {
      final directory = savePath ?? (await getApplicationDocumentsDirectory()).path;
      final fullPath = '$directory/$fileName';
      await _saveFileToPath(fullPath, bytes);
      OpenFilex.open(fullPath);
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
        build: (context) {
          final List<pw.Widget> widgets = [];
          int questionCounter = 0;
          for (final q in questions) {
            widgets.add(
              pw.Table(
                children: [
                  pw.TableRow(
                    children: [_buildAiQuizItem(q, questionCounter, isAnswerSheet: isAnswerSheet)],
                  ),
                ],
              ),
            );
            widgets.add(pw.Divider(height: 20, color: PdfColors.grey400));
            if (q.type == 'reading_section' && q.questions != null) {
              questionCounter += q.questions!.length;
            } else {
              questionCounter++;
            }
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildAiQuizItem(
    AiQuestion q,
    int questionCounterOffset, {
    required bool isAnswerSheet,
  }) {
    int questionCounter = questionCounterOffset;

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
  }

  String _generateWordTestHtml(
    String title,
    List<Map<String, dynamic>> testData,
    AppSettings settings,
  ) {
    final questions =
        testData.asMap().entries.map((entry) {
          final item = entry.value;
          final type = item['type'] as SelfTestType;
          final options = _questionOptions(item);
          final isMultipleChoice = options.isNotEmpty;
          final question = <String, dynamic>{
            'number': entry.key + 1,
            'type': _selfTestTypeLabel(type, isMultipleChoice: isMultipleChoice),
            'question': item['question'] as String? ?? '',
            'answer': item['answer'] as String? ?? '',
            'additionalMeanings': _additionalMeanings(item),
            'selfGraded': type == SelfTestType.wordToMeaning && !isMultipleChoice,
            'hint': item['hint'] as String?,
            'translation': settings.includeTranslation ? item['translation'] as String? : null,
          };
          if (options.isNotEmpty) question['options'] = options;
          return question;
        }).toList();

    return _interactiveHtmlShell(
      title: title,
      subtitle: '단어 시험지',
      dataJson: jsonEncode(questions),
      mode: 'word',
    );
  }

  String _generateAiQuizHtml(String title, List<AiQuestion> questions) {
    final items = <Map<String, dynamic>>[];

    for (final q in questions) {
      if (q.type == 'reading_section' && q.questions != null) {
        for (final subQuestion in q.questions!) {
          items.add({
            'type': 'choice',
            'passage': q.passage,
            'script': null,
            'question': subQuestion.question,
            'options': subQuestion.options,
            'answer': subQuestion.answer,
            'explanation': subQuestion.explanation,
          });
        }
      } else {
        items.add({
          'type': (q.options == null || q.options!.isEmpty) ? 'text' : 'choice',
          'passage': null,
          'script': q.script,
          'question': q.question ?? '',
          'options': q.options ?? const <String>[],
          'answer': q.answer ?? '',
          'explanation': q.explanation,
        });
      }
    }

    return _interactiveHtmlShell(
      title: title,
      subtitle: 'AI 인터랙티브 퀴즈',
      dataJson: jsonEncode(items),
      mode: 'ai',
    );
  }

  String _interactiveHtmlShell({
    required String title,
    required String subtitle,
    required String dataJson,
    required String mode,
  }) {
    final safeTitle = _htmlEscape.convert(title);
    final safeSubtitle = _htmlEscape.convert(subtitle);
    final safeDataJson = dataJson.replaceAll('</script>', '<\\/script>');

    return '''
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$safeTitle</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f2;
      --surface: #fffefa;
      --surface-soft: #eef1ea;
      --text: #172026;
      --muted: #64706c;
      --brand: #1f6b5f;
      --accent: #d46a5d;
      --success: #4f8f65;
      --danger: #c94f4f;
      --line: #dfe4da;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans KR", sans-serif;
      background: radial-gradient(circle at top left, #eaf2ed 0, transparent 34rem), var(--bg);
      color: var(--text);
    }
    .app {
      width: min(920px, 100%);
      margin: 0 auto;
      padding: 24px 18px 44px;
    }
    header {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-end;
      margin-bottom: 18px;
    }
    h1 {
      margin: 0;
      font-size: clamp(1.7rem, 4.5vw, 2.7rem);
      line-height: 1.15;
      letter-spacing: 0;
    }
    .subtitle {
      margin-top: 8px;
      color: var(--muted);
      font-size: 0.98rem;
    }
    .score-card {
      min-width: 136px;
      padding: 14px 16px;
      border: 1px solid var(--line);
      border-radius: 18px;
      background: rgba(255, 254, 250, 0.82);
      text-align: right;
      box-shadow: 0 16px 36px rgba(31, 107, 95, 0.08);
    }
    .score {
      font-weight: 800;
      font-size: 1.55rem;
      color: var(--brand);
    }
    .toolbar {
      position: sticky;
      top: 0;
      z-index: 5;
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      padding: 12px 0;
      background: linear-gradient(to bottom, var(--bg) 76%, rgba(246, 247, 242, 0));
    }
    button {
      border: 0;
      border-radius: 999px;
      padding: 11px 16px;
      background: var(--brand);
      color: white;
      font-weight: 800;
      cursor: pointer;
    }
    button.secondary {
      background: var(--surface-soft);
      color: var(--brand);
      border: 1px solid var(--line);
    }
    button.active {
      background: var(--brand);
      color: white;
      border-color: transparent;
    }
    .question {
      margin: 14px 0;
      padding: 18px;
      border: 1px solid var(--line);
      border-radius: 22px;
      background: rgba(255, 254, 250, 0.92);
      box-shadow: 0 20px 45px rgba(31, 107, 95, 0.08);
    }
    .question.correct { border-color: rgba(79, 143, 101, 0.7); }
    .question.wrong { border-color: rgba(201, 79, 79, 0.65); }
    .meta {
      display: flex;
      justify-content: space-between;
      gap: 10px;
      color: var(--muted);
      font-size: 0.9rem;
      margin-bottom: 10px;
    }
    .prompt {
      font-size: 1.08rem;
      font-weight: 750;
      line-height: 1.55;
      margin-bottom: 12px;
      white-space: pre-wrap;
    }
    .passage, .script, .translation, .explanation {
      margin: 10px 0 12px;
      padding: 12px;
      border-radius: 14px;
      background: var(--surface-soft);
      color: #33413d;
      line-height: 1.55;
      white-space: pre-wrap;
    }
    .hint {
      display: inline-flex;
      margin: 0 0 12px;
      padding: 8px 12px;
      border-radius: 999px;
      background: #eef6f2;
      color: var(--brand);
      font-weight: 800;
      letter-spacing: 0.04em;
    }
    input[type="text"] {
      width: 100%;
      padding: 13px 14px;
      border: 1px solid var(--line);
      border-radius: 14px;
      font-size: 1rem;
      outline-color: var(--brand);
      background: white;
    }
    .options {
      display: grid;
      gap: 8px;
    }
    .option {
      display: flex;
      gap: 10px;
      align-items: center;
      padding: 12px 13px;
      border: 1px solid var(--line);
      border-radius: 14px;
      cursor: pointer;
      background: white;
    }
    .option.selected {
      border-color: var(--brand);
      background: #eef6f2;
    }
    .option.correct {
      border-color: var(--success);
      background: #edf7f0;
    }
    .option.wrong {
      border-color: var(--danger);
      background: #fff0ee;
    }
    .feedback {
      display: none;
      margin-top: 12px;
      font-weight: 750;
    }
    .feedback.show { display: block; }
    .feedback.correct { color: var(--success); }
    .feedback.wrong { color: var(--danger); }
    .answer {
      margin-top: 8px;
      color: var(--muted);
      font-size: 0.95rem;
    }
    .self-grade-note {
      margin-top: 8px;
      color: var(--muted);
      font-weight: 600;
      line-height: 1.5;
    }
    .self-grade-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 12px;
    }
    .self-grade-actions button {
      padding: 9px 14px;
    }
    .self-grade-actions .review {
      color: var(--danger);
      background: #fff0ee;
      border: 1px solid rgba(201, 79, 79, 0.35);
    }
    @media (max-width: 640px) {
      header { align-items: stretch; flex-direction: column; }
      .score-card { text-align: left; }
      .toolbar button { flex: 1; }
    }
  </style>
</head>
<body>
  <main class="app">
    <header>
      <div>
        <h1>$safeTitle</h1>
        <div class="subtitle">$safeSubtitle · 브라우저에서 바로 풀고 채점할 수 있습니다.</div>
      </div>
      <section class="score-card">
        <div>점수</div>
        <div class="score"><span id="score">0</span>/<span id="total">0</span></div>
      </section>
    </header>
    <div class="toolbar">
      <button id="gradeButton" class="secondary" onclick="gradeAll()">전체 채점</button>
      <button id="answerButton" class="secondary" onclick="showAnswers()">정답 보기</button>
      <button class="secondary" onclick="resetQuiz()">다시 풀기</button>
    </div>
    <section id="quiz"></section>
  </main>
  <script>
    const quizMode = ${jsonEncode(mode)};
    const questions = $safeDataJson;
    const state = {};
    const gradedResults = {};
    const selfGrades = {};
    const quiz = document.getElementById('quiz');
    const total = document.getElementById('total');
    const score = document.getElementById('score');
    const gradeButton = document.getElementById('gradeButton');
    const answerButton = document.getElementById('answerButton');

    function normalize(value) {
      return String(value || '').trim().toLowerCase().replace(/\\s+/g, ' ');
    }

    function escapeHtml(value) {
      return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    function answerOf(index) {
      const input = document.querySelector('[data-input="' + index + '"]');
      if (input) return input.value;
      return state[index] || '';
    }

    function isSelfGradedQuestion(question) {
      return question.selfGraded === true &&
        !(Array.isArray(question.options) && question.options.length > 0);
    }

    function refreshScore() {
      const correctCount = Object.values(gradedResults).filter(function(value) {
        return value === true;
      }).length;
      score.textContent = correctCount;
    }

    function render() {
      total.textContent = questions.length;
      quiz.innerHTML = questions.map(function(q, index) {
        const number = q.number || index + 1;
        const type = q.type || (q.options && q.options.length ? 'choice' : 'text');
        const hasOptions = Array.isArray(q.options) && q.options.length > 0;
        const passage = q.passage ? '<div class="passage">' + escapeHtml(q.passage) + '</div>' : '';
        const script = q.script ? '<div class="script">' + escapeHtml(q.script) + '</div>' : '';
        const translation = q.translation ? '<div class="translation">해석: ' + escapeHtml(q.translation) + '</div>' : '';
        const hint = q.hint ? '<div class="hint">힌트: ' + escapeHtml(q.hint) + '</div>' : '';
        const options = hasOptions
          ? '<div class="options">' + q.options.map(function(opt, optIndex) {
              return '<label class="option" data-option="' + index + '-' + optIndex + '"><input type="radio" name="q' + index + '" onchange="choose(' + index + ', ' + optIndex + ')"><span>' + escapeHtml(opt) + '</span></label>';
            }).join('') + '</div>'
          : '<input data-input="' + index + '" type="text" placeholder="답을 입력하세요" oninput="markDirty(' + index + ')">';

        return '<article class="question" id="q' + index + '">' +
          '<div class="meta"><span>문제 ' + number + '</span><span>' + escapeHtml(type) + '</span></div>' +
          passage + script +
          '<div class="prompt">' + escapeHtml(q.question || '') + '</div>' +
          translation + hint + options +
          '<div class="feedback" id="f' + index + '"></div>' +
        '</article>';
      }).join('');
    }

    function markDirty(index) {
      gradeButton.classList.remove('active');
      answerButton.classList.remove('active');
      if (Number.isInteger(index)) {
        delete gradedResults[index];
        delete selfGrades[index];
        const card = document.getElementById('q' + index);
        const feedback = document.getElementById('f' + index);
        if (card) card.classList.remove('correct', 'wrong');
        if (feedback) feedback.className = 'feedback';
        refreshScore();
      }
    }

    function choose(index, optIndex) {
      markDirty(index);
      state[index] = questions[index].options[optIndex];
      const labels = document.querySelectorAll('[data-option^="' + index + '-"]');
      labels.forEach(function(label) { label.classList.remove('selected'); });
      const selected = document.querySelector('[data-option="' + index + '-' + optIndex + '"]');
      if (selected) selected.classList.add('selected');
    }

    function gradeQuestion(index, reveal) {
      const q = questions[index];
      const card = document.getElementById('q' + index);
      const feedback = document.getElementById('f' + index);
      const userAnswer = answerOf(index);
      if (isSelfGradedQuestion(q)) {
        const selfGrade = selfGrades[index];
        card.classList.remove('correct', 'wrong');
        if (selfGrade === true) card.classList.add('correct');
        if (selfGrade === false) card.classList.add('wrong');
        feedback.className = 'feedback show' +
          (selfGrade === true ? ' correct' : selfGrade === false ? ' wrong' : '');
        feedback.innerHTML = userAnswer
          ? '<div class="answer">내 답: ' + escapeHtml(userAnswer) + '</div>'
          : '<div class="answer">입력한 답이 없습니다.</div>';
        feedback.innerHTML += '<div class="answer">모범 답안: ' +
          escapeHtml(q.answer) + '</div>';
        if (Array.isArray(q.additionalMeanings) && q.additionalMeanings.length) {
          feedback.innerHTML += '<div class="explanation">함께 인정할 수 있는 뜻: ' +
            q.additionalMeanings.map(escapeHtml).join(' · ') + '</div>';
        }
        feedback.innerHTML += selfGrade === true
          ? '<div class="self-grade-note">정답으로 기록했습니다.</div>'
          : selfGrade === false
          ? '<div class="self-grade-note">다시 볼 문제로 기록했습니다.</div>'
          : '<div class="self-grade-note">표현이 달라도 의미가 같다면 정답으로 선택하세요.</div>';
        feedback.innerHTML += '<div class="self-grade-actions">' +
          '<button type="button" onclick="setSelfGrade(' + index + ', true)">맞게 썼어요</button>' +
          '<button type="button" class="review" onclick="setSelfGrade(' + index + ', false)">다시 볼게요</button>' +
          '</div>';
        return selfGrade === true;
      }
      const correct = normalize(userAnswer) === normalize(q.answer);
      gradedResults[index] = correct;

      card.classList.remove('correct', 'wrong');
      card.classList.add(correct ? 'correct' : 'wrong');
      feedback.className = 'feedback show ' + (correct ? 'correct' : 'wrong');
      feedback.innerHTML = correct ? '정답입니다.' : '오답입니다.';
      if (!correct || reveal) {
        feedback.innerHTML += '<div class="answer">정답: ' + escapeHtml(q.answer) + '</div>';
      }
      if (q.explanation) {
        feedback.innerHTML += '<div class="explanation">' + escapeHtml(q.explanation) + '</div>';
      }
      if (Array.isArray(q.additionalMeanings) && q.additionalMeanings.length) {
        feedback.innerHTML += '<div class="explanation">추가 뜻: ' +
          q.additionalMeanings.map(escapeHtml).join(' · ') + '</div>';
      }

      if (Array.isArray(q.options)) {
        q.options.forEach(function(opt, optIndex) {
          const label = document.querySelector('[data-option="' + index + '-' + optIndex + '"]');
          if (!label) return;
          label.classList.remove('correct', 'wrong');
          if (normalize(opt) === normalize(q.answer)) label.classList.add('correct');
          if (normalize(opt) === normalize(userAnswer) && !correct) label.classList.add('wrong');
        });
      }

      return correct;
    }

    function setSelfGrade(index, correct) {
      selfGrades[index] = correct;
      gradedResults[index] = correct;
      gradeQuestion(index, true);
      refreshScore();
    }

    function gradeAll() {
      questions.forEach(function(_, index) {
        gradeQuestion(index, false);
      });
      refreshScore();
      gradeButton.classList.add('active');
      answerButton.classList.remove('active');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    function showAnswers() {
      questions.forEach(function(_, index) { gradeQuestion(index, true); });
      answerButton.classList.add('active');
      gradeButton.classList.remove('active');
    }

    function resetQuiz() {
      Object.keys(state).forEach(function(key) { delete state[key]; });
      Object.keys(gradedResults).forEach(function(key) { delete gradedResults[key]; });
      Object.keys(selfGrades).forEach(function(key) { delete selfGrades[key]; });
      score.textContent = '0';
      gradeButton.classList.remove('active');
      answerButton.classList.remove('active');
      render();
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    render();
  </script>
</body>
</html>
''';
  }

  String _safeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'interactive_quiz' : cleaned;
  }

  String _selfTestTypeLabel(
    SelfTestType type, {
    bool isMultipleChoice = false,
  }) {
    switch (type) {
      case SelfTestType.wordToMeaning:
        return isMultipleChoice ? '뜻 고르기' : '뜻 쓰기';
      case SelfTestType.meaningToWord:
        return isMultipleChoice ? '단어 고르기' : '단어 쓰기';
      case SelfTestType.sentenceCompletion:
        return '문장 완성';
    }
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
