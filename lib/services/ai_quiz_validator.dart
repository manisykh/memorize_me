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
    bool requireKoreanQuestions = false,
  }) {
    if (response.questions.isEmpty) {
      throw CustomApiException('model_response_invalid', 'AI가 문제를 생성하지 않았습니다.');
    }

    var answerableCount = 0;
    var droppedDuplicateCount = 0;
    var droppedInvalidCount = 0;
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

    for (final rawQuestion in response.questions) {
      final question = _sanitizeGrammarBlankQuestion(rawQuestion);
      if (_isBlank(question.type) || !allowedTypes.contains(question.type)) {
        throw CustomApiException('model_response_invalid', '지원하지 않는 문제 유형입니다.');
      }
      if (expectedTypes != null && !expectedTypes.contains(question.type)) {
        throw CustomApiException(
          'model_response_invalid',
          '요청하지 않은 문제 유형이 포함되어 있습니다.',
        );
      }
      if (question.type == 'grammar' &&
          allowedGrammarChapterIds != null &&
          !allowedGrammarChapterIds.contains(
            question.grammarChapterId?.trim(),
          )) {
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
          _validateQuestionLanguage(
            subQuestion.question,
            requireKoreanQuestions: requireKoreanQuestions,
          );
          _validateAnswerChoiceLanguage(
            options: subQuestion.options,
            answer: subQuestion.answer,
            requireEnglishChoices: requireKoreanQuestions,
          );
          final validatedFormat = _validatedQuestionFormat(
            type: question.type,
            format: subQuestion.questionFormat,
            isRequired: requireFormatDiversity,
          );
          if (!_matchesTargetWord(
            targetWord: subQuestion.targetWord,
            allowedTargets: normalizedAllowedTargets,
            content: [
              question.passage!,
              subQuestion.question,
              ...subQuestion.options,
            ].join(' '),
          )) {
            droppedInvalidCount++;
            continue;
          }
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

      _validateQuestionLanguage(
        question.question,
        requireKoreanQuestions: requireKoreanQuestions,
      );
      _validateAnswerChoiceLanguage(
        options: question.options,
        answer: question.answer,
        requireEnglishChoices: requireKoreanQuestions,
      );
      final validatedFormat = _validatedQuestionFormat(
        type: question.type,
        format: question.questionFormat,
        isRequired: requireFormatDiversity,
      );
      if (!_hasExactlyOneGrammarBlank(question)) {
        droppedInvalidCount++;
        continue;
      }
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
      if (!_matchesTargetWord(
        targetWord: question.targetWord,
        allowedTargets: normalizedAllowedTargets,
        content: [question.question ?? '', ...?question.options].join(' '),
      )) {
        droppedInvalidCount++;
        continue;
      }
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
      if (droppedDuplicateCount + droppedInvalidCount == 0 ||
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
      droppedInvalidCount: droppedInvalidCount,
      difficultyMismatchCount: difficultyMismatchCount,
    );
  }

  static void _validateQuestionLanguage(
    String? question, {
    required bool requireKoreanQuestions,
  }) {
    if (!requireKoreanQuestions || question == null) return;
    if (!RegExp(r'[가-힣]').hasMatch(question)) {
      throw CustomApiException(
        'model_response_invalid',
        '한국어 출제 설정을 지키지 않은 AI 응답입니다. 다시 생성해주세요.',
      );
    }
  }

  static void _validateAnswerChoiceLanguage({
    required List<String>? options,
    required String? answer,
    required bool requireEnglishChoices,
  }) {
    if (!requireEnglishChoices) return;
    final containsKorean = RegExp(r'[가-힣]');
    if ((options?.any(containsKorean.hasMatch) ?? false) ||
        (answer != null && containsKorean.hasMatch(answer))) {
      throw CustomApiException(
        'model_response_invalid',
        '한국어 출제는 질문만 한국어로 표시해야 합니다. 선택지와 정답은 영어로 유지해주세요.',
      );
    }
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

  /// Hides an answer that a model incorrectly returned as `[answer]`,
  /// `(answer)`, `{answer}`, or `【answer】` in a grammar fill-in-the-blank stem.
  /// This is public so already-saved quizzes receive the same protection in
  /// the player even when they predate response validation.
  static String sanitizeQuestionForDisplay({
    required String type,
    required String? questionFormat,
    required String? question,
    required String? answer,
  }) {
    final source = question ?? '';
    if (type != 'grammar' ||
        questionFormat?.trim().toLowerCase() != 'fill_blank' ||
        _isBlank(answer)) {
      return source;
    }

    final answerPattern = answer!
        .trim()
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    final exposedAnswer = RegExp(
      r'(?:\[|\{|\(|【)\s*(?:answer\s*[:：]\s*)?' +
          answerPattern +
          r'\s*(?:\]|\}|\)|】)',
      caseSensitive: false,
    );
    final blankPattern = RegExp(r'_{3,}');
    final alreadyHasBlank = blankPattern.hasMatch(source);
    final hidden = source.replaceAll(
      exposedAnswer,
      alreadyHasBlank ? '' : '______',
    );
    return hidden
        .replaceAll(blankPattern, '______')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  static AiQuestion _sanitizeGrammarBlankQuestion(AiQuestion question) {
    final sanitizedText = sanitizeQuestionForDisplay(
      type: question.type,
      questionFormat: question.questionFormat,
      question: question.question,
      answer: question.answer,
    );
    if (sanitizedText == question.question) return question;
    return AiQuestion(
      type: question.type,
      questionFormat: question.questionFormat,
      targetWord: question.targetWord,
      grammarChapterId: question.grammarChapterId,
      passage: question.passage,
      script: question.script,
      question: sanitizedText,
      options: question.options,
      answer: question.answer,
      explanation: question.explanation,
      questions: question.questions,
    );
  }

  static bool _hasExactlyOneGrammarBlank(AiQuestion question) {
    if (question.type != 'grammar' ||
        question.questionFormat?.trim().toLowerCase() != 'fill_blank') {
      return true;
    }
    return RegExp(r'_{3,}').allMatches(question.question ?? '').length == 1;
  }

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

  static bool _matchesTargetWord({
    required String? targetWord,
    required Set<String> allowedTargets,
    required String content,
  }) {
    if (allowedTargets.isEmpty) return true;
    if (_isBlank(targetWord)) return false;
    final normalizedTarget = _normalizeTarget(targetWord!);
    if (!allowedTargets.contains(normalizedTarget)) return false;

    final targetTokens = normalizedTarget.split(' ');
    final contentTokens = _normalizeTarget(content).split(' ');
    if (targetTokens.isEmpty || contentTokens.length < targetTokens.length) {
      return false;
    }
    for (
      var start = 0;
      start <= contentTokens.length - targetTokens.length;
      start++
    ) {
      var allMatch = true;
      for (var offset = 0; offset < targetTokens.length; offset++) {
        if (!_isSameWordFamily(
          targetTokens[offset],
          contentTokens[start + offset],
        )) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return true;
    }
    return false;
  }

  static bool _isSameWordFamily(String base, String candidate) {
    if (base == candidate) return true;
    if (base.length < 3) {
      return _irregularForms[base]?.contains(candidate) ?? false;
    }
    final forms = <String>{
      '${base}s',
      '${base}es',
      '${base}ed',
      '${base}ing',
      "$base's",
      ...?_irregularForms[base],
    };
    if (base.endsWith('e') && base.length > 3) {
      forms
        ..add('${base}d')
        ..add('${base.substring(0, base.length - 1)}ing');
    }
    if (base.endsWith('y') &&
        base.length > 3 &&
        !'aeiou'.contains(base[base.length - 2])) {
      final stem = base.substring(0, base.length - 1);
      forms
        ..add('${stem}ies')
        ..add('${stem}ied');
    }
    if (_endsWithConsonantVowelConsonant(base)) {
      final doubled = '$base${base[base.length - 1]}';
      forms
        ..add('${doubled}ed')
        ..add('${doubled}ing');
    }
    return forms.contains(candidate);
  }

  static bool _endsWithConsonantVowelConsonant(String value) {
    if (value.length < 3) return false;
    const vowels = 'aeiou';
    final first = value[value.length - 3];
    final middle = value[value.length - 2];
    final last = value[value.length - 1];
    return !vowels.contains(first) &&
        vowels.contains(middle) &&
        !vowels.contains(last) &&
        !'wxy'.contains(last);
  }

  static const Map<String, Set<String>> _irregularForms = {
    'be': {'am', 'is', 'are', 'was', 'were', 'been', 'being'},
    'become': {'became'},
    'begin': {'began', 'begun', 'beginning'},
    'bring': {'brought'},
    'buy': {'bought'},
    'catch': {'caught'},
    'choose': {'chose', 'chosen'},
    'come': {'came'},
    'do': {'does', 'did', 'done', 'doing'},
    'feel': {'felt'},
    'fly': {'flew', 'flown'},
    'get': {'got', 'gotten', 'getting'},
    'go': {'goes', 'went', 'gone', 'going'},
    'grow': {'grew', 'grown'},
    'have': {'has', 'had', 'having'},
    'keep': {'kept'},
    'know': {'knew', 'known'},
    'leave': {'left'},
    'make': {'made', 'making'},
    'meet': {'met'},
    'pay': {'paid'},
    'run': {'ran', 'running'},
    'say': {'said'},
    'see': {'saw', 'seen'},
    'sell': {'sold'},
    'send': {'sent'},
    'sit': {'sat', 'sitting'},
    'speak': {'spoke', 'spoken'},
    'stand': {'stood'},
    'swim': {'swam', 'swum', 'swimming'},
    'take': {'took', 'taken'},
    'teach': {'taught'},
    'think': {'thought'},
    'understand': {'understood'},
    'win': {'won', 'winning'},
    'write': {'wrote', 'written', 'writing'},
  };

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
