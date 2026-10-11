import '../models/ai_quiz_model.dart';
import 'ai_difficulty_profile.dart';
import 'custom_api_exception.dart';

class AiQuizValidator {
  const AiQuizValidator._();

  static AiQuizResponse sanitize(
    AiQuizResponse response, {
    int? expectedAnswerableCount,
    Iterable<String>? allowedTargetWords,
    Set<String>? allowedGrammarChapterIds,
    Set<String>? expectedTypes,
    AiDifficultyProfile? difficultyProfile,
    bool requireFormatDiversity = false,
    bool requireTypeDiversity = false,
  }) {
    if (response.questions.isEmpty) {
      throw CustomApiException('model_response_invalid', 'AI가 문제를 생성하지 않았습니다.');
    }

    var answerableCount = 0;
    var droppedDuplicateCount = 0;
    var difficultyMismatchCount = 0;
    final sanitizedQuestions = <AiQuestion>[];
    final seenQuestions = <String>{};
    final seenOptionSets = <String>{};
    final usedFormats = <String>{};
    final usedTypes = <String>{};
    const allowedTypes = {'vocabulary', 'grammar', 'reading_section'};
    final normalizedAllowedTargets =
        allowedTargetWords
            ?.map(_normalizeTarget)
            .where((word) => word.isNotEmpty)
            .toSet() ??
        const <String>{};

    for (final question in response.questions) {
      if (_isBlank(question.type) || !allowedTypes.contains(question.type)) {
        throw CustomApiException('model_response_invalid', '지원하지 않는 문제 유형입니다.');
      }
      if (expectedTypes != null && !expectedTypes.contains(question.type)) {
        throw CustomApiException(
          'model_response_invalid',
          '요청하지 않은 문제 유형이 포함되어 있습니다.',
        );
      }
      if (question.type == 'grammar' && allowedGrammarChapterIds != null &&
          !allowedGrammarChapterIds.contains(question.grammarChapterId?.trim())) {
        throw CustomApiException(
          'model_response_invalid',
          '선택하지 않은 문법 챕터가 포함되었거나 챕터 정보가 누락되었습니다.',
        );
      }

      if (question.type == 'reading_section') {
        final subQuestions = question.questions;
        if (_isBlank(question.passage) ||
            subQuestions == null ||
            subQuestions.isEmpty) {
          throw CustomApiException(
            'model_response_invalid',
            '독해 문제 구성이 완전하지 않습니다.',
          );
        }
        if (difficultyProfile != null) {
          final matchesDifficulty = _matchesWordCount(
            content: question.passage!,
            minimum: difficultyProfile.passageMinWords,
            maximum: difficultyProfile.passageMaxWords,
          );
          if (!matchesDifficulty) {
            difficultyMismatchCount += subQuestions.length;
          }
        }
        final sanitizedSubQuestions = <AiReadingSubQuestion>[];
        for (final subQuestion in subQuestions) {
          final validatedFormat = _validatedQuestionFormat(
            type: question.type,
            format: subQuestion.questionFormat,
            isRequired: requireFormatDiversity,
          );
          _validateTargetWord(
            targetWord: subQuestion.targetWord,
            allowedTargets: normalizedAllowedTargets,
            content: [
              question.passage!,
              subQuestion.question,
              ...subQuestion.options,
            ].join(' '),
          );
          if (!_validateParts(
            question: subQuestion.question,
            options: subQuestion.options,
            answer: subQuestion.answer,
            seenQuestions: seenQuestions,
            seenOptionSets: seenOptionSets,
          )) {
            droppedDuplicateCount++;
            continue;
          }
          if (validatedFormat != null) usedFormats.add(validatedFormat);
          usedTypes.add(question.type);
          sanitizedSubQuestions.add(subQuestion);
          answerableCount++;
        }
        if (sanitizedSubQuestions.isNotEmpty) {
          sanitizedQuestions.add(
            AiQuestion(
              type: question.type,
              questionFormat: question.questionFormat,
              targetWord: question.targetWord,
              grammarChapterId: question.grammarChapterId,
              passage: question.passage,
              script: question.script,
              question: question.question,
              options: question.options,
              answer: question.answer,
              explanation: question.explanation,
              questions: sanitizedSubQuestions,
            ),
          );
        }
        continue;
      }

      final validatedFormat = _validatedQuestionFormat(
        type: question.type,
        format: question.questionFormat,
        isRequired: requireFormatDiversity,
      );
      if (difficultyProfile != null) {
        final matchesDifficulty = _matchesContextWordCount(
          question: question.question ?? '',
          options: question.options ?? const [],
          minimum: difficultyProfile.contextMinWords,
          // Allow a short instruction in addition to the measured context sentence.
          maximum: difficultyProfile.contextMaxWords + 8,
        );
        if (!matchesDifficulty) difficultyMismatchCount++;
      }
      _validateTargetWord(
        targetWord: question.targetWord,
        allowedTargets: normalizedAllowedTargets,
        content: [question.question ?? '', ...?question.options].join(' '),
      );
      if (!_validateParts(
        question: question.question,
        options: question.options,
        answer: question.answer,
        seenQuestions: seenQuestions,
        seenOptionSets: seenOptionSets,
      )) {
        droppedDuplicateCount++;
        continue;
      }
      if (validatedFormat != null) usedFormats.add(validatedFormat);
      usedTypes.add(question.type);
      sanitizedQuestions.add(question);
      answerableCount++;
    }

    if (answerableCount == 0) {
      throw CustomApiException('model_response_invalid', '채점 가능한 문제가 없습니다.');
    }
    if (requireFormatDiversity) {
      final requiredFormatCount =
          answerableCount >= 8 ? 3 : (answerableCount >= 4 ? 2 : 1);
      if (usedFormats.length < requiredFormatCount) {
        throw CustomApiException(
          'model_response_invalid',
          '문제 유형이 충분히 다양하지 않습니다. (${usedFormats.length}/$requiredFormatCount)',
        );
      }
    }
    if (requireTypeDiversity) {
      final requiredTypeCount =
          answerableCount >= 8 ? 3 : (answerableCount >= 4 ? 2 : 1);
      if (usedTypes.length < requiredTypeCount) {
        throw CustomApiException(
          'model_response_invalid',
          '종합 퀴즈의 영역 구성이 충분히 다양하지 않습니다. (${usedTypes.length}/$requiredTypeCount)',
        );
      }
    }
    if (expectedAnswerableCount != null &&
        answerableCount != expectedAnswerableCount) {
      if (droppedDuplicateCount == 0 ||
          answerableCount > expectedAnswerableCount) {
        throw CustomApiException(
          'model_response_invalid',
          'AI가 요청한 문제 수와 다른 수의 문제를 생성했습니다. '
              '($answerableCount/$expectedAnswerableCount)',
        );
      }
    }

    return AiQuizResponse(
      questions: sanitizedQuestions,
      requestedQuestionCount: expectedAnswerableCount ?? answerableCount,
      droppedDuplicateCount: droppedDuplicateCount,
      difficultyMismatchCount: difficultyMismatchCount,
    );
  }

  static bool _validateParts({
    required String? question,
    required List<String>? options,
    required String? answer,
    required Set<String> seenQuestions,
    required Set<String> seenOptionSets,
  }) {
    if (_isBlank(question)) {
      throw CustomApiException('model_response_invalid', '문제 문항이 누락되었습니다.');
    }
    final normalizedQuestion = _normalize(question!);
    if (!seenQuestions.add(normalizedQuestion)) return false;

    if (options == null || options.length != 4 || options.any(_isBlank)) {
      throw CustomApiException('model_response_invalid', '선택지는 정확히 4개여야 합니다.');
    }
    final normalizedOptions = options.map(_normalize).toList();
    if (normalizedOptions.toSet().length != normalizedOptions.length) {
      throw CustomApiException('model_response_invalid', '중복된 선택지가 포함되어 있습니다.');
    }
    if (normalizedOptions.any(_isDisallowedOptionText)) {
      throw CustomApiException(
        'model_response_invalid',
        '부적절한 선택지가 포함되어 있습니다.',
      );
    }
    if (_isBlank(answer)) {
      throw CustomApiException('model_response_invalid', '정답이 누락되었습니다.');
    }
    final normalizedAnswer = _normalize(answer!);
    if (normalizedOptions
            .where((option) => option == normalizedAnswer)
            .length !=
        1) {
      throw CustomApiException(
        'model_response_invalid',
        '정답과 일치하는 선택지가 정확히 1개여야 합니다.',
      );
    }

    final optionSetKey = (List<String>.from(normalizedOptions)
      ..sort()).join('|');
    if (!seenOptionSets.add(optionSetKey)) return false;
    return true;
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static const Map<String, Set<String>> _allowedFormats = {
    'vocabulary': {
      'sentence_completion',
      'meaning_in_context',
      'definition_match',
      'synonym',
      'antonym',
      'collocation',
    },
    'grammar': {
      'fill_blank',
      'correct_sentence',
      'incorrect_sentence',
      'error_correction',
      'sentence_transformation',
    },
    'reading_section': {
      'main_idea',
      'detail',
      'inference',
      'vocabulary_in_context',
      'purpose_tone',
      'rhetorical_function',
      'sentence_insertion',
      'summary',
    },
  };

  static String? _validatedQuestionFormat({
    required String type,
    required String? format,
    required bool isRequired,
  }) {
    if (!isRequired) return null;
    final normalizedFormat = format?.trim().toLowerCase() ?? '';
    if (normalizedFormat.isEmpty ||
        !(_allowedFormats[type]?.contains(normalizedFormat) ?? false)) {
      throw CustomApiException(
        'model_response_invalid',
        '지원하지 않거나 누락된 세부 문제 유형입니다.',
      );
    }
    return normalizedFormat;
  }

  static bool _matchesWordCount({
    required String content,
    required int minimum,
    required int maximum,
  }) {
    final count =
        RegExp(r"[A-Za-z]+(?:['’-][A-Za-z]+)*").allMatches(content).length;
    return count >= minimum && count <= maximum;
  }

  static bool _matchesContextWordCount({
    required String question,
    required List<String> options,
    required int minimum,
    required int maximum,
  }) {
    final candidates = [question, ...options];
    final count = candidates
        .map(
          (content) =>
              RegExp(
                r"[A-Za-z]+(?:['’-][A-Za-z]+)*",
              ).allMatches(content).length,
        )
        .fold<int>(
          0,
          (longest, current) => current > longest ? current : longest,
        );
    return count >= minimum && count <= maximum;
  }

  static void _validateTargetWord({
    required String? targetWord,
    required Set<String> allowedTargets,
    required String content,
  }) {
    if (allowedTargets.isEmpty) return;
    if (_isBlank(targetWord)) {
      throw CustomApiException(
        'model_response_invalid',
        '학습 단어 연결 정보가 누락되었습니다.',
      );
    }
    final normalizedTarget = _normalizeTarget(targetWord!);
    if (!allowedTargets.contains(normalizedTarget)) {
      throw CustomApiException(
        'model_response_invalid',
        '단어장에 없는 학습 단어가 사용되었습니다.',
      );
    }
    final normalizedContent = ' ${_normalizeTarget(content)} ';
    if (!normalizedContent.contains(' $normalizedTarget ')) {
      throw CustomApiException(
        'model_response_invalid',
        '학습 단어가 문제나 지문에 실제로 포함되지 않았습니다.',
      );
    }
  }

  static String _normalizeTarget(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9가-힣'-]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isDisallowedOptionText(String value) {
    return const {
      'all of the above',
      'none of the above',
      'both a and b',
      'both b and c',
      'true',
      'false',
      'all',
      'none',
    }.contains(value);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'''[“”"'`.,!?;:()\[\]{}]'''), '');
  }
}
