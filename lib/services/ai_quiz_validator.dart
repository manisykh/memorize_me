import '../models/ai_quiz_model.dart';
import 'custom_api_exception.dart';

class AiQuizValidator {
  const AiQuizValidator._();

  static AiQuizResponse sanitize(
    AiQuizResponse response, {
    int? expectedAnswerableCount,
  }) {
    if (response.questions.isEmpty) {
      throw CustomApiException('model_response_invalid', 'AI가 문제를 생성하지 않았습니다.');
    }

    var answerableCount = 0;
    var droppedDuplicateCount = 0;
    final sanitizedQuestions = <AiQuestion>[];
    final seenQuestions = <String>{};
    final seenOptionSets = <String>{};
    const allowedTypes = {'vocabulary', 'grammar', 'reading_section'};

    for (final question in response.questions) {
      if (_isBlank(question.type) || !allowedTypes.contains(question.type)) {
        throw CustomApiException('model_response_invalid', '지원하지 않는 문제 유형입니다.');
      }

      if (question.type == 'reading_section') {
        final subQuestions = question.questions;
        if (_isBlank(question.passage) || subQuestions == null || subQuestions.isEmpty) {
          throw CustomApiException('model_response_invalid', '독해 문제 구성이 완전하지 않습니다.');
        }
        final sanitizedSubQuestions = <AiReadingSubQuestion>[];
        for (final subQuestion in subQuestions) {
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
          sanitizedSubQuestions.add(subQuestion);
          answerableCount++;
        }
        if (sanitizedSubQuestions.isNotEmpty) {
          sanitizedQuestions.add(
            AiQuestion(
              type: question.type,
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
      sanitizedQuestions.add(question);
      answerableCount++;
    }

    if (answerableCount == 0) {
      throw CustomApiException('model_response_invalid', '채점 가능한 문제가 없습니다.');
    }
    if (expectedAnswerableCount != null && answerableCount != expectedAnswerableCount) {
      if (droppedDuplicateCount == 0 || answerableCount > expectedAnswerableCount) {
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
      throw CustomApiException('model_response_invalid', '부적절한 선택지가 포함되어 있습니다.');
    }
    if (_isBlank(answer)) {
      throw CustomApiException('model_response_invalid', '정답이 누락되었습니다.');
    }
    final normalizedAnswer = _normalize(answer!);
    if (normalizedOptions.where((option) => option == normalizedAnswer).length != 1) {
      throw CustomApiException('model_response_invalid', '정답과 일치하는 선택지가 정확히 1개여야 합니다.');
    }

    final optionSetKey = (List<String>.from(normalizedOptions)..sort()).join('|');
    if (!seenOptionSets.add(optionSetKey)) return false;
    return true;
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

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
