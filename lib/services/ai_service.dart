// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
// import 'package:dart_openai/dart_openai.dart' as openai;

// import '../models/word_model.dart';
// import '../models/ai_quiz_model.dart';
// import 'api_key_service.dart';

// // 사용자에게 보여줄 명확한 오류를 위한 사용자 정의 예외 클래스
// class CustomApiException implements Exception {
//   final String code;
//   final String message;
//   CustomApiException(this.code, this.message);
//   @override
//   String toString() => message;
// }

// class AiService {
//   final ApiKeyService _apiKeyService;
//   AiService(this._apiKeyService);

//   Future<String?> generateExampleSentence(String word) async {
//     final apiKey = await _apiKeyService.getApiKey(AiProvider.gemini);
//     if (apiKey == null || apiKey.isEmpty) {
//       throw CustomApiException('api_key_missing', 'Gemini API 키가 등록되지 않았습니다.');
//     }

//     final prompt = """
//     Create a simple and natural example sentence using the word "$word".
//     The sentence must be easy for an English learner to understand.
//     Respond with only the sentence itself, without any additional explanations or quotation marks.
//     """;

//     try {
//       // 현재 gemini-1.5-flash 모델을 사용하도록 고정
//       final model = gemini.GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
//       final response = await model.generateContent([gemini.Content.text(prompt)]);
//       return response.text?.trim();
//     } on Exception catch (e) {
//       debugPrint('Gemini 예문 생성 오류: $e');
//       // 기존 generateQuiz의 오류 처리 로직을 재사용하거나 단순화할 수 있습니다.
//       throw CustomApiException('sentence_generation_failed', '예문 생성에 실패했습니다. API 키와 네트워크를 확인해주세요.');
//     }
//   }

//   Future<AiQuizResponse?> generateQuiz({
//     required AiProvider provider,
//     required String modelName,
//     required List<Word> selectedWords,
//     required String quizType,
//     required String difficulty,
//     required int questionCount,
//     required bool includeExplanation,
//   }) async {
//     final apiKey = await _apiKeyService.getApiKey(provider);
//     if (apiKey == null || apiKey.isEmpty) {
//       throw CustomApiException('api_key_missing', '${provider.name} API 키가 등록되지 않았습니다.');
//     }
//     final prompt = _buildImprovedPrompt(
//       selectedWords,
//       quizType,
//       difficulty,
//       questionCount,
//       includeExplanation,
//     );
//     try {
//       String? responseText;
//       if (provider == AiProvider.gemini) {
//         final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
//         final response = await model.generateContent([gemini.Content.text(prompt)]);
//         responseText = response.text;
//       } else {
//         // OpenAI 호출 로직...
//       }
//       if (responseText != null) {
//         final cleanedText = responseText.replaceAll('**', '');
//         return AiQuizResponse.parse(cleanedText);
//       }
//       return null;
//     } on Exception catch (e) {
//       debugPrint('$provider AI 서비스 오류 발생: $e');
//       if (e.toString().contains('overloaded') || e.toString().contains('503')) {
//         throw CustomApiException('server_overloaded', 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.');
//       } else if (e.toString().contains('quota') || e.toString().contains('429')) {
//         throw CustomApiException(
//           'quota_exceeded',
//           'API 사용량 한도를 초과했습니다. 내일 다시 시도하거나 다른 AI 엔진을 선택해주세요.',
//         );
//       } else {
//         throw CustomApiException(
//           'unknown_error',
//           '알 수 없는 오류가 발생했습니다. 네트워크 상태를 확인하거나 잠시 후 다시 시도해주세요.',
//         );
//       }
//     }
//   }

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import 'api_key_service.dart';

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

  // ▼▼▼ [수정] modelName을 인자로 받도록 변경 ▼▼▼
  Future<Map<String, String>> generateSentencesForWords(
    List<String> words,
    String modelName,
  ) async {
    final apiKey = await _apiKeyService.getApiKey(AiProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', 'Gemini API 키가 등록되지 않았습니다.');
    }

    final wordListString = words.join(', ');
    final prompt = """
    For the following list of English words, create one simple and natural example sentence for each word.
    The sentences must be easy for an English learner to understand.
    Respond with ONLY a valid JSON object where each key is the word and the value is its corresponding example sentence.

    Word list: [$wordListString]

    Example response format for words "apple", "book":
    {
      "apple": "She took a big bite of the juicy apple.",
      "book": "He is reading a fascinating book about history."
    }
    """;

    debugPrint("📝 [AI_SERVICE] 일괄 예문 생성 프롬프트:\n$prompt");

    try {
      // ▼▼▼ [수정] 고정된 모델 이름 대신 전달받은 modelName 사용 ▼▼▼
      final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([gemini.Content.text(prompt)]);
      final responseText = response.text ?? '{}';
      debugPrint("📄 [AI_SERVICE] 일괄 예문 생성 원본 응답:\n$responseText");

      final cleanedJson = responseText.replaceAll(RegExp(r'```json|```'), '').trim();
      final decodedJson = jsonDecode(cleanedJson) as Map<String, dynamic>;
      return decodedJson.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint("❌ [AI_SERVICE] 일괄 예문 생성 중 오류 발생: $e");
      throw CustomApiException('sentence_generation_failed', '일괄 예문 생성에 실패했습니다.');
    }
  }

  Future<AiQuizResponse?> generateQuiz({
    required AiProvider provider,
    required String modelName,
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
    required bool includeExplanation,
  }) async {
    debugPrint("🤖 [AI_SERVICE] generateQuiz 호출됨");
    debugPrint("   - Provider: $provider, Model: $modelName");
    debugPrint("   - QuizType: $quizType, Difficulty: $difficulty, Count: $questionCount");

    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("❌ [AI_SERVICE] API 키 없음. 오류 발생시킴.");
      throw CustomApiException('api_key_missing', '${provider.name} API 키가 등록되지 않았습니다.');
    }

    final prompt = _buildImprovedPrompt(
      selectedWords,
      quizType,
      difficulty,
      questionCount,
      includeExplanation,
    );

    debugPrint("📝 [AI_SERVICE] 최종 프롬프트:\n$prompt");

    try {
      String? responseText;
      if (provider == AiProvider.gemini) {
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        debugPrint("✅ [AI_SERVICE] Gemini API 호출 시작...");
        final response = await model.generateContent([gemini.Content.text(prompt)]);
        responseText = response.text;
        debugPrint("✅ [AI_SERVICE] Gemini API 응답 수신 완료.");
      }

      if (responseText != null) {
        debugPrint("📄 [AI_SERVICE] AI 원본 응답:\n$responseText");
        final cleanedText = responseText.replaceAll('**', '');
        return AiQuizResponse.parse(cleanedText);
      }
      return null;
    } on Exception catch (e) {
      debugPrint("❌ [AI_SERVICE] API 호출 중 심각한 오류 발생: $e");
      if (e.toString().contains('overloaded') || e.toString().contains('503')) {
        throw CustomApiException('server_overloaded', 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.');
      } else if (e.toString().contains('quota') || e.toString().contains('429')) {
        throw CustomApiException('quota_exceeded', 'API 사용량 한도를 초과했습니다.');
      } else {
        throw CustomApiException('unknown_error', '알 수 없는 오류가 발생했습니다: ${e.toString()}');
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

    // 1. 난이도 정의 (기존과 동일)
    String difficultyDescription;
    switch (difficulty) {
      case '쉬움':
        difficultyDescription =
            "Elementary and Middle school level. Use basic vocabulary and simple sentence structures.";
        break;
      case '어려움':
        difficultyDescription =
            "Advanced level, including High school, TOEIC, TOEFL, and SAT vocabulary. Use complex sentences and nuanced contexts.";
        break;
      case '보통':
      default:
        difficultyDescription =
            "Intermediate level, including Elementary, Middle, and High school vocabulary. Standard sentence structures.";
    }

    // 2. 어휘 문제 유형 상세 지침 (수정됨)
    const vocabularyInstructions = """
  **Area Specific Instructions for 'vocabulary' questions:**
  You MUST generate a diverse mix of the following sub-types. The `sub_type` field is MANDATORY.

  - **`sentence_completion`**: The `question` field itself MUST be a complete sentence containing a blank (e.g., '______'). The user must choose the word that best fills this blank.
    - *Example Question*: "The new policy is expected to ______ significant changes across the company."
  
  - **`definition_matching`**: The question is a definition, and the options are words.
    - *Example Question*: "The act of formally giving up a position or a right."
  
  - **`synonym_antonym`**: Ask for a synonym or an antonym of a given word.
    - *Example Question*: "Which word is an antonym for 'transient'?"

  - **`word_form`**: Provide a sentence with a blank. The options MUST be different forms of the same root word.
    - *Example Question*: "Her ______ to the team was invaluable."
    - *Example Options*: ["contribute", "contribution", "contributor", "contributing"]

  - **`categorization`**: Ask the user to identify which word belongs to a specific category.
    - *Example Question*: "Which of the following words is a type of vehicle?"

  - **`confusing_words`**: Provide a sentence that tests the ability to distinguish between commonly confused words.
    - *Example Question*: "Please ______ this gift as a token of our appreciation."
    - *Example Options*: ["accept", "except", "aspect", "expect"]
  """;

    // 3. ▼▼▼ [신규] 독해 문제 유형 상세 지침 ▼▼▼
    const readingInstructions = """
  **Area Specific Instructions for 'reading' questions:**
  You MUST generate a diverse mix of the following sub-types. The `type` MUST be "reading_section".

  1.  **sub_type: `standard_comprehension`**
      - **Description:** Provide a longer passage (1-3 paragraphs). Then, provide MULTIPLE questions that test the user's overall understanding of the passage (e.g., main idea, specific details, author's intent).
      - **JSON Structure:** The `passage` field contains the long text, and the `questions` field is a LIST of 2 or more sub-question objects.

  2.  **sub_type: `contextual_inference`**
      - **Description:** Provide a SHORT passage (1-2 sentences). Then, provide ONLY ONE question that asks for the meaning of a specific word as it is used within that short passage.
      - **JSON Structure:** The `passage` field contains the short text, and the `questions` field is a LIST containing EXACTLY ONE sub-question object.
  """;

    // 4. 영역별 지시사항 동적 설정
    String areaInstruction;
    if (quizType == '어휘') {
      areaInstruction = vocabularyInstructions;
    } else if (quizType == '독해') {
      areaInstruction = readingInstructions;
    } else if (quizType != '종합') {
      areaInstruction =
          "You MUST generate questions ONLY for the following area: `${quizType.toLowerCase().replaceAll(' ', '_')}`.";
    } else {
      areaInstruction =
          "Generate a mix of questions from `vocabulary`, `grammar`, `reading_section`, and `listening`. For `vocabulary` and `reading` questions, follow their specific instructions if applicable.";
    }

    // 5. 최종 프롬프트 조합
    return """
    You are an expert English Language Test creator for Korean students.
    Your task is to create a quiz based on the provided word list and instructions.
    Follow all rules VERY STRICTLY.

    # 1. MANDATORY RULES
    - The total number of answerable questions MUST be EXACTLY `$count`. For types like `reading_section`, its sub-questions count towards this total.
    - All text in the JSON fields MUST be in ENGLISH, except for the `explanation` field, which MUST be in KOREAN.
    - Do not use any markdown like `**` in the JSON output.
    - The correct answer MUST be clearly distinguishable from the incorrect options.
    - You can use other words to create questions, but the user-selected words from the `Vocabulary List` MUST be included in the quiz, either as a question target or as one of the options.

    # 2. QUIZ CONFIGURATION
    - **Vocabulary List:** { $wordListString }
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Include Explanation in Korean:** `$includeExplanation`

    # 3. QUESTION AREA & TYPE INSTRUCTIONS
    $areaInstruction

    # 4. REQUIRED JSON RESPONSE FORMAT
    Your output MUST be a single, valid JSON object. For vocabulary questions, `sub_type` in each question object is mandatory. For reading questions, `sub_type` in each `reading_section` object is mandatory.
    {
      "questions": [
        {
          "type": "vocabulary",
          "sub_type": "sentence_completion",
          "question": "The company decided to ______ its new headquarters in the city center.",
          "options": ["locate", "donate", "vibrate", "hesitate"],
          "answer": "locate",
          "explanation": "'locate'는 '~에 위치시키다'라는 의미로 문맥에 가장 적절합니다."
        },
        {
          "type": "reading_section",
          "sub_type": "contextual_inference",
          "passage": "The team's proposal was met with derision from the board members, who found the ideas to be completely impractical.",
          "questions": [
            {
              "question": "In the passage, the word 'derision' is closest in meaning to:",
              "options": ["praise", "ridicule", "indifference", "curiosity"],
              "answer": "ridicule",
              "explanation": "'derision'은 조롱, 비웃음을 의미하며, 문맥상 아이디어가 비현실적이라고 생각했으므로 'ridicule'이 가장 가깝습니다."
            }
          ]
        }
      ]
    }

    **FINAL CHECK: Create exactly `$count` questions following all rules, difficulty levels, and type definitions.**
  """;
  }
}
