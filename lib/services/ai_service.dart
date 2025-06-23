import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:dart_openai/dart_openai.dart' as openai;

import '../models/word_model.dart';
import '../models/ai_quiz_model.dart';
import 'api_key_service.dart';

// 사용자에게 보여줄 명확한 오류를 위한 사용자 정의 예외 클래스
class CustomApiException implements Exception {
  final String code;
  final String message;
  CustomApiException(this.code, this.message);
  @override
  String toString() => message;
}

class AiService {
  final ApiKeyService _apiKeyService;
  AiService(this._apiKeyService);

  Future<AiQuizResponse?> generateQuiz({
    required AiProvider provider,
    required String modelName,
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
    required bool includeExplanation,
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
    );
    try {
      String? responseText;
      if (provider == AiProvider.gemini) {
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([gemini.Content.text(prompt)]);
        responseText = response.text;
      } else {
        // OpenAI 호출 로직...
      }
      if (responseText != null) {
        final cleanedText = responseText.replaceAll('**', '');
        return AiQuizResponse.parse(cleanedText);
      }
      return null;
    } on Exception catch (e) {
      debugPrint('$provider AI 서비스 오류 발생: $e');
      if (e.toString().contains('overloaded') || e.toString().contains('503')) {
        throw CustomApiException('server_overloaded', 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.');
      } else if (e.toString().contains('quota') || e.toString().contains('429')) {
        throw CustomApiException(
          'quota_exceeded',
          'API 사용량 한도를 초과했습니다. 내일 다시 시도하거나 다른 AI 엔진을 선택해주세요.',
        );
      } else {
        throw CustomApiException(
          'unknown_error',
          '알 수 없는 오류가 발생했습니다. 네트워크 상태를 확인하거나 잠시 후 다시 시도해주세요.',
        );
      }
    }
  }

  String _buildImprovedPrompt(
    List<Word> words,
    String quizType,
    String difficulty,
    int count,
    bool includeExplanation,
  ) {
    final wordListString = words.map((w) => '"${w.word}":"${w.meaning}"').join(', ');
    final areaInstruction =
        (quizType != '종합')
            ? "You MUST generate questions ONLY for the following area: `${quizType.toLowerCase().replaceAll(' ', '_')}`."
            : "Generate a mix of questions from `vocabulary`, `grammar`, `reading_section`, `listening`.";

    return """
      You are an expert English Language Test (like TOEIC) creator for Korean students.
      Follow all instructions VERY STRICTLY.

      # MANDATORY RULES:
      1.  **TOTAL ANSWERABLE QUESTIONS:** The total number of individual, answerable questions you generate MUST be EXACTLY `$count`. For a 'reading_section', its sub-questions count towards this total. Example: For a `$count` of 10, provide 7 normal questions and one 'reading_section' with 3 sub-questions.
      2.  **QUESTION AREAS:** $areaInstruction
      3.  **STRICTLY ENGLISH QUESTIONS:** ALL response fields (`type`, `passage`, `script`, `question`, `options`, `answer`) MUST be in ENGLISH.
      4.  **EXPLANATION IN KOREAN:** If `include_explanation` is true, you MUST provide a brief, clear explanation for the correct answer in the `explanation` field. The explanation MUST be in KOREAN. If false, this field must be null.
      5.  **NO MARKDOWN:** Do not use markdown like `**` in the output strings.
      6.  **JSON ONLY:** Your output MUST be a single, valid JSON object.

      # VOCABULARY LIST & FORMATTING INFO
      - **Vocabulary List:** { $wordListString }
      - **Include Explanation:** `$includeExplanation`
      - **Difficulty:** '$difficulty'

      # REQUIRED JSON RESPONSE FORMAT
      {
        "questions": [
          {
            "type": "vocabulary",
            "question": "...",
            "options": ["...", "...", "...", "..."],
            "answer": "...",
            "explanation": "이것이 정답인 이유에 대한 한글 설명입니다. (or null)"
          },
          {
            "type": "reading_section",
            "passage": "A SINGLE passage...",
            "questions": [
              {
                "question": "Question 1...",
                "options": ["...", "...", "...", "..."],
                "answer": "...",
                "explanation": "1번 문제에 대한 한글 해설입니다. (or null)"
              }
            ]
          }
        ]
      }

      **FINAL CHECK: Ensure total answerable questions are EXACTLY `$count` and follow all rules.**
    """;
  }
}
