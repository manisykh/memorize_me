// lib/services/ai_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:http/http.dart' as http;

import '../models/ai_quiz_model.dart';
import '../models/grammar_curriculum.dart';
import '../models/word_model.dart';
import '../providers/ai_settings_provider.dart';
import 'api_key_service.dart';

class CustomApiException implements Exception {
  final String code;
  final String message;
  CustomApiException(this.code, this.message);
  @override
  String toString() => message;
}

class AiFallbackResult<T> {
  final T value;
  final AiRequestOption usedOption;
  final List<String> attempts;

  const AiFallbackResult({
    required this.value,
    required this.usedOption,
    required this.attempts,
  });
}

class AiService {
  static const Duration _requestTimeout = Duration(seconds: 45);

  final ApiKeyService _apiKeyService;
  AiService(this._apiKeyService);

  Future<String?> generateExampleSentence(
    String word,
    String meaning,
    String modelName, {
    AiProvider provider = AiProvider.gemini,
    String? endpoint,
  }) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', '${provider.label} API 키가 등록되지 않았습니다.');
    }
    final prompt = """
    Create a simple and natural example sentence using the English word "$word".
    The sentence MUST specifically reflect the provided Korean meaning: "$meaning".
    Respond with only the sentence itself, without any additional explanations or quotation marks.
    """;
    try {
      final responseText = await _sendPrompt(
        provider: provider,
        modelName: modelName,
        apiKey: apiKey,
        prompt: prompt,
        endpoint: endpoint,
      );
      return responseText?.trim().replaceAll('"', '');
    } on CustomApiException {
      rethrow;
    } on TimeoutException {
      throw CustomApiException('request_timeout', 'AI 요청 시간이 초과되었습니다.');
    } on Exception catch (e) {
      debugPrint('${provider.label} 예문 생성 오류: $e');
      throw CustomApiException('sentence_generation_failed', '예문 생성에 실패했습니다.');
    }
  }

  // ▼▼▼ [수정] 전체 메서드 수정
  Future<Map<String, Map<String, String>>> generateSentencesForWords(
    List<Word> words,
    AiProvider provider,
    String modelName,
    String? endpoint,
  ) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', '${provider.name} API 키가 등록되지 않았습니다.');
    }
    final wordListJson = jsonEncode(
      words.map((w) => {'word': w.word, 'meaning': w.meaning}).toList(),
    );
    final prompt = """
    For each English word in the following JSON list, create one simple, natural example sentence and its KOREAN translation.
    Each sentence MUST specifically reflect the provided Korean "meaning".
    Respond with ONLY a valid JSON object where each key is the English word, and the value is another JSON object containing "sentence" and "translation".
    Word list: $wordListJson
    Example response format:
    {
      "mold": {
        "sentence": "The sculptor poured liquid metal into the mold.",
        "translation": "조각가는 녹은 금속을 주형에 부었습니다."
      },
      "lead": {
        "sentence": "She will lead the team to victory.",
        "translation": "그녀는 팀을 승리로 이끌 것입니다."
      }
    }
    """;
    try {
      final responseText = await _sendPrompt(
            provider: provider,
            modelName: modelName,
            apiKey: apiKey,
            prompt: prompt,
            endpoint: endpoint,
          ) ??
          '{}';
      final cleanedJson = _cleanModelText(responseText);
      return _parseSentenceMap(cleanedJson);
    } on CustomApiException {
      rethrow;
    } catch (e) {
      final mappedError = _mapUnexpectedAiError(e);
      if (mappedError.code != 'unknown_error') {
        throw mappedError;
      }
      throw CustomApiException('model_response_invalid', 'AI 예문 응답 형식이 올바르지 않습니다.');
    }
  }

  Future<AiFallbackResult<Map<String, Map<String, String>>>> generateSentencesForWordsWithFallback(
    List<Word> words,
    List<AiRequestOption> options,
  ) async {
    return _runWithFallback<Map<String, Map<String, String>>>(
      options: options,
      run:
          (option) => generateSentencesForWords(
            words,
            option.provider,
            option.modelName,
            option.endpoint,
          ),
    );
  }

  Future<void> testConnection({
    required AiProvider provider,
    required String modelName,
    String? endpoint,
  }) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', '${provider.label} API 키가 등록되지 않았습니다.');
    }
    final responseText = await _sendPrompt(
      provider: provider,
      modelName: modelName,
      apiKey: apiKey,
      endpoint: endpoint,
      prompt: 'Return exactly this JSON object and nothing else: {"ok":true}',
    );
    final cleaned = _cleanModelText(responseText ?? '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
      throw CustomApiException('model_response_invalid', 'AI 연결 테스트 응답 형식이 올바르지 않습니다.');
    }
  }

  Future<AiQuizResponse?> generateGrammarQuiz({
    required AiProvider provider,
    required String modelName,
    required GrammarCategory category,
    required List<GrammarChapter> chapters,
    required int questionCount,
    required String difficulty,
    required bool includeExplanation,
    required String questionLanguage,
    String? endpoint,
  }) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', '${provider.name} API 키가 등록되지 않았습니다.');
    }
    final prompt = _buildGrammarPrompt(
      category,
      chapters,
      questionCount,
      difficulty,
      includeExplanation,
      questionLanguage,
    );
    try {
      String? responseText;
      responseText = await _sendPrompt(
        provider: provider,
        modelName: modelName,
        apiKey: apiKey,
        prompt: prompt,
        endpoint: endpoint,
      );
      if (responseText != null) {
        return _parseAndValidateQuizResponse(
          responseText,
          expectedAnswerableCount: questionCount,
        );
      }
      return null;
    } on CustomApiException {
      rethrow;
    } on Exception catch (e) {
      throw _mapUnexpectedAiError(e);
    }
  }

  Future<AiFallbackResult<AiQuizResponse?>> generateGrammarQuizWithFallback({
    required List<AiRequestOption> options,
    required GrammarCategory category,
    required List<GrammarChapter> chapters,
    required int questionCount,
    required String difficulty,
    required bool includeExplanation,
    required String questionLanguage,
  }) async {
    return _runWithFallback<AiQuizResponse?>(
      options: options,
      run:
          (option) => generateGrammarQuiz(
            provider: option.provider,
            modelName: option.modelName,
            category: category,
            chapters: chapters,
            questionCount: questionCount,
            difficulty: difficulty,
            includeExplanation: includeExplanation,
            questionLanguage: questionLanguage,
            endpoint: option.endpoint,
          ),
    );
  }

  Future<AiQuizResponse?> generateQuiz({
    required AiProvider provider,
    required String modelName,
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
    required bool includeExplanation,
    required String questionLanguage,
    String? endpoint,
  }) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', '${provider.name} API 키가 등록되지 않았습니다.');
    }
    final prompt = _buildImprovedPrompt(
      selectedWords,
      quizType,
      difficulty,
      questionCount,
      includeExplanation,
      questionLanguage,
    );
    try {
      String? responseText;
      responseText = await _sendPrompt(
        provider: provider,
        modelName: modelName,
        apiKey: apiKey,
        prompt: prompt,
        endpoint: endpoint,
      );
      if (responseText != null) {
        return _parseAndValidateQuizResponse(
          responseText,
          expectedAnswerableCount: questionCount,
        );
      }
      return null;
    } on CustomApiException {
      rethrow;
    } on Exception catch (e) {
      if (e.toString().contains('overloaded') || e.toString().contains('503')) {
        throw CustomApiException('server_overloaded', 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.');
      } else if (e.toString().contains('quota') || e.toString().contains('429')) {
        throw CustomApiException('quota_exceeded', 'API 사용량 한도를 초과했습니다.');
      } else if (e.toString().contains('TimeoutException')) {
        throw CustomApiException('request_timeout', 'AI 요청 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw CustomApiException('network_error', '네트워크 연결을 확인해주세요.');
      } else {
        throw _mapUnexpectedAiError(e);
      }
    }
  }

  Future<AiFallbackResult<AiQuizResponse?>> generateQuizWithFallback({
    required List<AiRequestOption> options,
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
    required bool includeExplanation,
    required String questionLanguage,
  }) async {
    return _runWithFallback<AiQuizResponse?>(
      options: options,
      run:
          (option) => generateQuiz(
            provider: option.provider,
            modelName: option.modelName,
            selectedWords: selectedWords,
            quizType: quizType,
            difficulty: difficulty,
            questionCount: questionCount,
            includeExplanation: includeExplanation,
            questionLanguage: questionLanguage,
            endpoint: option.endpoint,
          ),
    );
  }

  Future<AiFallbackResult<T>> _runWithFallback<T>({
    required List<AiRequestOption> options,
    required Future<T> Function(AiRequestOption option) run,
  }) async {
    if (options.isEmpty) {
      throw CustomApiException('api_key_missing', '사용 가능한 AI 제공자가 없습니다.');
    }

    final attempts = <String>[];
    CustomApiException? lastFallbackError;

    for (final option in options) {
      final apiKey = await _apiKeyService.getApiKey(option.provider);
      if (apiKey == null || apiKey.isEmpty) {
        attempts.add('${option.provider.shortLabel}: API 키 없음');
        continue;
      }
      if (option.provider == AiProvider.customOpenAI &&
          (option.endpoint == null || option.endpoint!.isEmpty)) {
        attempts.add('${option.provider.shortLabel}: 엔드포인트 없음');
        continue;
      }

      try {
        final value = await run(option);
        return AiFallbackResult<T>(
          value: value,
          usedOption: option,
          attempts: [...attempts, '${option.provider.shortLabel}: 성공'],
        );
      } on CustomApiException catch (e) {
        attempts.add('${option.provider.shortLabel}: ${e.message}');
        if (_isFallbackCandidate(e)) {
          lastFallbackError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastFallbackError != null) {
      throw CustomApiException(
        'fallback_exhausted',
        '등록된 AI 제공자를 모두 시도했지만 실패했습니다.\n${attempts.join('\n')}',
      );
    }
    throw CustomApiException(
      'api_key_missing',
      '사용 가능한 API 키가 없습니다. AI 설정에서 API 키를 등록해주세요.',
    );
  }

  bool _isFallbackCandidate(CustomApiException error) {
    return {
      'quota_exceeded',
      'server_overloaded',
      'request_timeout',
      'network_error',
      'openai_request_failed',
      'anthropic_request_failed',
      'model_response_invalid',
      'model_request_failed',
    }.contains(error.code);
  }

  Future<String?> _sendPrompt({
    required AiProvider provider,
    required String modelName,
    required String apiKey,
    required String prompt,
    String? endpoint,
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model
            .generateContent([gemini.Content.text(prompt)])
            .timeout(_requestTimeout);
        return response.text;
      case AiProvider.anthropic:
        return _sendAnthropicPrompt(modelName: modelName, apiKey: apiKey, prompt: prompt);
      case AiProvider.openAI:
      case AiProvider.groq:
      case AiProvider.openRouter:
      case AiProvider.mistral:
      case AiProvider.deepSeek:
      case AiProvider.xAI:
      case AiProvider.perplexity:
      case AiProvider.together:
      case AiProvider.fireworks:
      case AiProvider.customOpenAI:
      case AiProvider.zAi:
        return _sendOpenAiCompatiblePrompt(
          provider: provider,
          modelName: modelName,
          apiKey: apiKey,
          prompt: prompt,
          endpoint: endpoint,
        );
    }
  }

  Future<String?> _sendOpenAiCompatiblePrompt({
    required AiProvider provider,
    required String modelName,
    required String apiKey,
    required String prompt,
    String? endpoint,
  }) async {
    final resolvedEndpoint =
        provider == AiProvider.customOpenAI ? endpoint?.trim() : provider.chatCompletionsEndpoint;
    if (resolvedEndpoint == null || resolvedEndpoint.isEmpty) {
      throw CustomApiException('endpoint_missing', '${provider.label} 엔드포인트를 입력해주세요.');
    }

    final response = await http
        .post(
          Uri.parse(resolvedEndpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {
                'role': 'system',
                'content': 'Return only valid JSON. Do not wrap the response in markdown.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.7,
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw CustomApiException('api_key_invalid', '${provider.label} API 키를 확인해주세요.');
      }
      if (response.statusCode == 429) {
        throw CustomApiException('quota_exceeded', 'API 사용량 한도를 초과했습니다.');
      }
      if (response.statusCode == 503 || response.statusCode == 529) {
        throw CustomApiException('server_overloaded', '${provider.label} 서버가 현재 바쁩니다.');
      }
      throw CustomApiException('openai_request_failed', '${provider.label} 요청에 실패했습니다. ($body)');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final message = choices.first['message'] as Map<String, dynamic>?;
    return message?['content']?.toString();
  }

  Future<String?> _sendAnthropicPrompt({
    required String modelName,
    required String apiKey,
    required String prompt,
  }) async {
    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': modelName,
            'max_tokens': 4096,
            'temperature': 0.7,
            'system': 'Return only valid JSON. Do not wrap the response in markdown.',
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw CustomApiException('api_key_invalid', 'Anthropic API 키를 확인해주세요.');
      }
      if (response.statusCode == 429) {
        throw CustomApiException('quota_exceeded', 'API 사용량 한도를 초과했습니다.');
      }
      if (response.statusCode == 503 || response.statusCode == 529) {
        throw CustomApiException('server_overloaded', 'Anthropic 서버가 현재 바쁩니다.');
      }
      throw CustomApiException('anthropic_request_failed', 'Anthropic 요청에 실패했습니다. ($body)');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) return null;
    final firstText = content.firstWhere(
      (item) => item is Map<String, dynamic> && item['type'] == 'text',
      orElse: () => null,
    );
    if (firstText is Map<String, dynamic>) {
      return firstText['text']?.toString();
    }
    return null;
  }

  Map<String, Map<String, String>> _parseSentenceMap(String cleanedJson) {
    final decoded = jsonDecode(cleanedJson);
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
      throw CustomApiException('model_response_invalid', 'AI 예문 응답이 비어 있습니다.');
    }

    final result = <String, Map<String, String>>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final sentence = value['sentence']?.toString().trim() ?? '';
      final translation = value['translation']?.toString().trim() ?? '';
      if (entry.key.trim().isEmpty || sentence.isEmpty || translation.isEmpty) continue;
      result[entry.key] = {
        'sentence': sentence,
        'translation': translation,
      };
    }

    if (result.isEmpty) {
      throw CustomApiException('model_response_invalid', '저장할 수 있는 예문이 없습니다.');
    }
    return result;
  }

  AiQuizResponse _parseAndValidateQuizResponse(
    String responseText, {
    int? expectedAnswerableCount,
  }) {
    try {
      final response = AiQuizResponse.parse(_cleanModelText(responseText));
      return _sanitizeAndValidateQuizResponse(
        response,
        expectedAnswerableCount: expectedAnswerableCount,
      );
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException('model_response_invalid', 'AI 퀴즈 응답 형식이 올바르지 않습니다.');
    }
  }

  AiQuizResponse _sanitizeAndValidateQuizResponse(
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
      if (_isBlank(question.type)) {
        throw CustomApiException('model_response_invalid', '문제 유형이 비어 있습니다.');
      }
      if (!allowedTypes.contains(question.type)) {
        throw CustomApiException('model_response_invalid', '지원하지 않는 문제 유형이 포함되어 있습니다.');
      }

      if (question.type == 'reading_section') {
        final subQuestions = question.questions;
        if (_isBlank(question.passage) || subQuestions == null || subQuestions.isEmpty) {
          throw CustomApiException('model_response_invalid', '독해 문제의 지문 또는 하위 문제가 누락되었습니다.');
        }
        final sanitizedSubQuestions = <AiReadingSubQuestion>[];
        for (final subQuestion in subQuestions) {
          final shouldKeep = _validateQuestionParts(
            question: subQuestion.question,
            options: subQuestion.options,
            answer: subQuestion.answer,
            seenQuestions: seenQuestions,
            seenOptionSets: seenOptionSets,
          );
          if (!shouldKeep) {
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

      final shouldKeep = _validateQuestionParts(
        question: question.question,
        options: question.options,
        answer: question.answer,
        seenQuestions: seenQuestions,
        seenOptionSets: seenOptionSets,
      );
      if (!shouldKeep) {
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
      if (droppedDuplicateCount > 0 && answerableCount < expectedAnswerableCount) {
        debugPrint(
          'AI quiz accepted after dropping $droppedDuplicateCount duplicate question(s). '
          'Generated $answerableCount/$expectedAnswerableCount answerable question(s).',
        );
        return AiQuizResponse(
          questions: sanitizedQuestions,
          requestedQuestionCount: expectedAnswerableCount,
          droppedDuplicateCount: droppedDuplicateCount,
        );
      }
      throw CustomApiException(
        'model_response_invalid',
        'AI가 요청한 문제 수와 다른 수의 문제를 생성했습니다. ($answerableCount/$expectedAnswerableCount)',
      );
    }
    if (droppedDuplicateCount > 0) {
      debugPrint('AI quiz dropped $droppedDuplicateCount duplicate question(s).');
    }
    return AiQuizResponse(
      questions: sanitizedQuestions,
      requestedQuestionCount: expectedAnswerableCount ?? answerableCount,
      droppedDuplicateCount: droppedDuplicateCount,
    );
  }

  bool _validateQuestionParts({
    required String? question,
    required List<String>? options,
    required String? answer,
    required Set<String> seenQuestions,
    required Set<String> seenOptionSets,
  }) {
    if (_isBlank(question)) {
      throw CustomApiException('model_response_invalid', '문제 문항이 누락되었습니다.');
    }
    final normalizedQuestion = _normalizeForDuplicateCheck(question!);
    if (!seenQuestions.add(normalizedQuestion)) {
      return false;
    }
    if (options == null || options.length != 4 || options.any((option) => _isBlank(option))) {
      throw CustomApiException('model_response_invalid', '선택지는 정확히 4개여야 합니다.');
    }
    final normalizedOptions = options.map(_normalizeForDuplicateCheck).toList();
    if (normalizedOptions.toSet().length != normalizedOptions.length) {
      throw CustomApiException('model_response_invalid', '중복된 선택지가 포함되어 있습니다.');
    }
    if (normalizedOptions.any(_isDisallowedOptionText)) {
      throw CustomApiException('model_response_invalid', '부적절한 선택지가 포함되어 있습니다.');
    }
    if (_isBlank(answer)) {
      throw CustomApiException('model_response_invalid', '정답이 누락되었습니다.');
    }
    final normalizedAnswer = _normalizeForDuplicateCheck(answer ?? '');
    if (normalizedOptions.where((option) => option == normalizedAnswer).length != 1) {
      throw CustomApiException('model_response_invalid', '정답과 일치하는 선택지가 정확히 1개여야 합니다.');
    }
    final optionSetKey = (normalizedOptions..sort()).join('|');
    if (!seenOptionSets.add(optionSetKey)) {
      return false;
    }
    if (_isBlank(answer)) {
      throw CustomApiException('model_response_invalid', '정답이 누락되었습니다.');
    }
    if (!options.contains(answer)) {
      throw CustomApiException('model_response_invalid', '정답이 선택지 안에 없습니다.');
    }
    return true;
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  bool _isDisallowedOptionText(String value) {
    return {
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

  String _normalizeForDuplicateCheck(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'''[“”"'`.,!?;:()\[\]{}]'''), '');
  }

  CustomApiException _mapUnexpectedAiError(Object error) {
    final text = error.toString();
    final lowerText = text.toLowerCase();
    if (lowerText.contains('model') ||
        lowerText.contains('not found') ||
        lowerText.contains('invalid_argument') ||
        lowerText.contains('invalid argument') ||
        lowerText.contains('404')) {
      return CustomApiException(
        'model_request_failed',
        '선택한 모델로 요청할 수 없습니다. AI 설정에서 다른 모델을 선택해주세요.',
      );
    }
    if (lowerText.contains('timeout')) {
      return CustomApiException('request_timeout', 'AI 요청 시간이 초과되었습니다.');
    }
    if (lowerText.contains('socket') || lowerText.contains('network')) {
      return CustomApiException('network_error', '네트워크 연결을 확인해주세요.');
    }
    return CustomApiException('unknown_error', '알 수 없는 오류가 발생했습니다: $text');
  }

  String _cleanModelText(String text) {
    final cleaned = text.replaceAll(RegExp(r'```(?:json)?|```'), '').replaceAll('**', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return cleaned.substring(start, end + 1).trim();
    }
    return cleaned;
  }

  String _questionLanguageGuide(String questionLanguage) {
    final isKorean = questionLanguage.toLowerCase().contains('korean');
    if (isKorean) {
      return """
    - User-facing question instructions may be written in Korean.
    - English learning material MUST stay in English: passages, sentence-completion sentences, target words, and English sentence options.
    - Korean meanings may be used when a vocabulary question asks about meaning.
    - The explanation field, when present, MUST be in Korean.
    """;
    }
    return """
    - User-facing question instructions should be written in English.
    - English learning material MUST stay in English.
    - Korean meanings may be used only when the question explicitly asks for Korean meaning.
    - The explanation field, when present, MUST be in Korean.
    """;
  }

  String _canonicalQuizType(String quizType) {
    return switch (quizType) {
      '어휘' => 'vocabulary',
      '문법' => 'grammar',
      '독해' => 'reading_section',
      _ => 'mixed',
    };
  }

  List<Word> _wordsForPrompt(List<Word> words, int count) {
    var candidateLimit = count * 4;
    if (candidateLimit < 20) candidateLimit = 20;
    if (candidateLimit > 80) candidateLimit = 80;
    final shuffledWords = List<Word>.from(words)..shuffle(Random());
    return shuffledWords.take(candidateLimit).toList();
  }

  String _buildGrammarPrompt(
    GrammarCategory category,
    List<GrammarChapter> chapters,
    int count,
    String difficulty,
    bool includeExplanation,
    String questionLanguage,
  ) {
    final chaptersJson = jsonEncode(
      chapters
          .map(
            (c) => {
              'group': c.description,
              'chapter': c.title,
              if (c.details.isNotEmpty) 'details': c.details,
            },
          )
          .toList(),
    );
    final difficultyMap = {
      '기초':
          "Beginner level for elementary school students. Use simple S+V+O sentences and basic vocabulary.",
      '기본':
          "Basic level for middle school students. Use compound sentences and essential vocabulary.",
      '중급':
          "Intermediate level for high school students. Use complex sentences with various clauses, and include more nuanced vocabulary.",
      '중고급':
          "High-intermediate level for college entrance exam preparation. Use advanced vocabulary and complex sentence structures.",
      '고급': "Advanced level for TOEIC preparation. Use business and formal vocabulary.",
      '최상급':
          "Expert level for TOEFL/TEPS preparation. Use academic vocabulary and sophisticated sentence structures.",
      '전문가':
          "Professional level. Use vocabulary and sentence structures found in academic papers and reputable news sources like CNN or Newsweek.",
    };
    final difficultyDescription = difficultyMap[difficulty] ?? difficultyMap['중급']!;
    final languageGuide = _questionLanguageGuide(questionLanguage);
    final explanationRule =
        includeExplanation
            ? 'Every answerable question MUST include a concise Korean explanation.'
            : 'Do not include explanation, or set explanation to an empty string.';

    return """
    You are an adaptive learning assistant creating English grammar quizzes.
    Your job is to create accurate, answerable English grammar questions for Korean learners.

    # Mission
    Create exactly `$count` answerable multiple-choice grammar questions based only on the selected chapters.

    # Core Rules
    1. Scope: Every question MUST test one of the selected chapters. Do not introduce unrelated grammar points.
    2. Difficulty: Sentence length, vocabulary, and distractor subtlety MUST match the target difficulty.
    3. Count: The response MUST contain exactly `$count` answerable questions.
    4. Options: Every question MUST have exactly 4 unique options.
    5. Answer: The `answer` value MUST exactly match one string from `options`.
    6. Explanation: $explanationRule
    7. JSON only: Return one valid JSON object. No markdown, no comments, no trailing commas.
    8. Language:
$languageGuide

    # Quality Rules
    - Do NOT repeat the same question stem, sentence, answer, or option set.
    - If multiple chapters are selected, distribute questions across chapters as evenly as possible.
    - Do NOT create more than 2 consecutive questions from the same chapter group unless only one group is selected.
    - Each distractor MUST be plausible and test the same grammar point as the correct answer.
    - Distractors should be common learner mistakes: tense mismatch, agreement error, wrong preposition, wrong word order, wrong infinitive/gerund, or incorrect clause connector.
    - Do NOT use silly distractors, obviously unrelated choices, "all of the above", "none of the above", or true/false style choices.
    - Randomize the correct answer position. Do not always place the answer in the same option slot.
    - For "choose the incorrect sentence" questions, make exactly one option incorrect and make the other three clearly grammatical.
    - For "choose the correct sentence" questions, make exactly one option correct and make the other three contain realistic grammar errors.
    - Avoid testing two unrelated grammar rules in the same question.

    # Quiz Configuration
    - **Target Level:** ${category.title}
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Question Count:** $count
    - **Question Language:** $questionLanguage
    - **Selected Chapters JSON:** $chaptersJson

    # Allowed Question Formats
    - Fill in the blank.
    - Choose the grammatically correct sentence.
    - Choose the grammatically incorrect sentence.
    - Choose the best correction.

    # Required JSON Schema
    {
      "questions": [
        {
          "type": "grammar",
          "question": "...",
          "options": ["...", "...", "...", "..."],
          "answer": "...",
          "explanation": "..."
        }
      ]
    }
    """;
  }

  String _buildImprovedPrompt(
    List<Word> words,
    String quizType,
    String difficulty,
    int count,
    bool includeExplanation,
    String questionLanguage,
  ) {
    final promptWords = _wordsForPrompt(words, count);
    final omittedWordCount = words.length - promptWords.length;
    final wordListJson = jsonEncode(
      promptWords
          .map(
            (w) => {
              'word': w.word,
              'meaning': w.meaning,
              if (w.exampleSentence != null && w.exampleSentence!.trim().isNotEmpty)
                'exampleSentence': w.exampleSentence,
            },
          )
          .toList(),
    );

    final difficultyMap = {
      '기초':
          "Beginner level for elementary school students. Use simple S+V+O sentences and basic vocabulary.",
      '기본':
          "Basic level for middle school students. Use compound sentences and essential vocabulary.",
      '중급':
          "Intermediate level for high school students. Use complex sentences with various clauses, and include more nuanced vocabulary.",
      '중고급':
          "High-intermediate level for college entrance exam preparation. Use advanced vocabulary and complex sentence structures.",
      '고급': "Advanced level for TOEIC. Use business and formal vocabulary.",
      '최상급':
          "Expert level for TOEFL/TEPS. Use academic vocabulary and sophisticated sentence structures.",
      '전문가':
          "Professional level. Use vocabulary and structures from news articles or academic papers.",
    };
    final difficultyDescription = difficultyMap[difficulty] ?? difficultyMap['중급']!;
    final canonicalType = _canonicalQuizType(quizType);
    final languageGuide = _questionLanguageGuide(questionLanguage);
    final explanationRule =
        includeExplanation
            ? 'Every answerable question MUST include a concise Korean explanation.'
            : 'Do not include explanation, or set explanation to an empty string.';
    final candidateNote =
        omittedWordCount > 0
            ? 'The user selected ${words.length} words. To keep the prompt reliable, this request includes ${promptWords.length} shuffled candidate words. Build the quiz from these candidates.'
            : 'Build the quiz from the provided candidate words.';

    const vocabularyInstructions = """
  Vocabulary questions:
  - Use type exactly "vocabulary".
  - Prefer the selected English words as the correct answers.
  - Good formats: sentence completion, definition matching, Korean meaning matching, synonym/antonym.
  - If using sentence completion, the sentence must contain exactly one blank: "______".
  - Use each candidate word as a correct answer at most once unless the requested count exceeds the number of candidates.
  - The correct answer MUST reflect the provided Korean meaning, especially for polysemous words.
  - Distractors must be plausible words with a similar part of speech or semantic field, not random words.
  - Do not reuse the same sentence template or ask the same "meaning of this word" pattern repeatedly.
  """;

    const grammarInstructions = """
  Grammar questions:
  - Use type exactly "grammar".
  - Test grammar through selected vocabulary when natural, but do not force awkward sentences.
  - Good formats: fill in the blank, sentence correction, choosing the grammatical sentence, choosing the incorrect sentence.
  - Do not repeat the same grammar pattern more than once unless the requested count is larger than the available patterns.
  - Distractors must represent realistic learner errors, not vocabulary misunderstandings.
  """;

    const readingInstructions = """
  Reading questions:
  - Use type exactly "reading_section".
  - A reading_section counts by the number of sub-questions inside its `questions` list.
  - Passage length and complexity MUST match the Target Difficulty.
    - '기초'/'기본': 1-3 simple sentences.
    - '중급'/'중고급': 1-2 paragraphs with some complex sentences.
    - '고급' or higher: 2-4 paragraphs with advanced vocabulary and complex structures.
  - Every reading_section MUST contain a non-empty `questions` list.
  - Each sub-question MUST have exactly 4 unique options and an answer that exactly matches one option.
  - Do not create a passage that directly repeats the answer phrase from the correct option unless the question is explicit detail lookup.
  - Mix sub-question skills when possible: main idea, inference, detail, vocabulary in context, and sentence insertion.
  - Avoid more than 3 sub-questions per passage unless the requested count is high enough.
  """;

    String areaInstruction;
    String strictTypeConstraint = "";

    if (quizType != '종합') {
      strictTypeConstraint =
          "- Critical Rule: Generate ONLY `$canonicalType` question blocks.";
      if (quizType == '어휘') {
        areaInstruction = vocabularyInstructions;
      } else if (quizType == '독해') {
        areaInstruction = readingInstructions;
      } else if (quizType == '문법') {
        areaInstruction = grammarInstructions;
      } else {
        areaInstruction = 'Generate questions for the `$canonicalType` type.';
      }
    } else {
      areaInstruction =
          "Generate a useful mix from `vocabulary`, `grammar`, and `reading_section`. Listening is intentionally excluded from the MVP quiz generator. If the requested count is small, choose the most appropriate types without exceeding the exact answerable count.";
    }

    return """
    You are an adaptive learning assistant that creates English quizzes.
    Your job is to create accurate, answerable English vocabulary and grammar quizzes for Korean learners.

    # 1. MANDATORY RULES
    $strictTypeConstraint
    - Difficulty: Vocabulary, sentence structure, and passage length MUST match the Target Difficulty.
    - Count: Total answerable questions MUST be exactly `$count`. A reading_section with 3 sub-questions counts as 3.
    - Options: Every answerable question MUST have exactly 4 unique options.
    - Answer: The `answer` value MUST exactly match one string from `options`.
    - Explanation: $explanationRule
    - JSON only: Return one valid JSON object. No markdown, no comments, no trailing commas.
    - Language:
$languageGuide

    # 1-B. QUALITY RULES
    - Do NOT repeat the same question stem, sentence, answer, or set of options.
    - Use the provided candidate words broadly. Avoid using the same correct word twice unless unavoidable.
    - Correct answer positions must be varied across questions.
    - Distractors must be plausible and close enough to test knowledge, but only one option may be correct.
    - Do NOT use "all of the above", "none of the above", true/false choices, joke options, or obviously unrelated distractors.
    - Avoid questions that can be answered without understanding the target word, grammar point, or passage.
    - When using Korean meanings, keep them concise and aligned with the supplied word meanings.
    - If the requested type is not `종합`, every answerable question MUST use only the requested type.
    - If the requested type is `종합` and count >= 4, include at least two different question types.
    - Do NOT generate `listening` questions in this generator. Listening will be handled by a separate feature later.

    # 2. QUIZ CONFIGURATION
    - **Vocabulary Candidates JSON:** $wordListJson
    - **Candidate Note:** $candidateNote
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Requested Quiz Type:** $quizType
    - **Question Language:** $questionLanguage

    # 3. QUESTION AREA & TYPE INSTRUCTIONS
    $areaInstruction

    # 4. REQUIRED JSON RESPONSE FORMAT
    Use one of these shapes:
    {
      "questions": [
        {
          "type": "vocabulary",
          "question": "...",
          "options": ["...", "...", "...", "..."],
          "answer": "...",
          "explanation": "..."
        },
        {
          "type": "grammar",
          "question": "...",
          "options": ["...", "...", "...", "..."],
          "answer": "...",
          "explanation": "..."
        },
        {
          "type": "reading_section",
          "passage": "...",
          "questions": [
            {
              "question": "...",
              "options": ["...", "...", "...", "..."],
              "answer": "...",
              "explanation": "..."
            }
          ]
        }
      ]
    }

    FINAL CHECK:
    - Exactly `$count` answerable questions.
    - Every answer exactly matches one option.
    - No duplicate question stems, no duplicate correct answers unless unavoidable, and no duplicate option sets.
    - Distractors are plausible, same-category alternatives.
    - The JSON can be parsed by a strict JSON parser.
  """;
  }
}
