import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

import '../models/ai_quiz_model.dart';
import '../models/grammar_curriculum.dart';
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

  // 단어 하나에 대한 예문을 생성하는 메서드
  Future<String?> generateExampleSentence(String word, String meaning, String modelName) async {
    final apiKey = await _apiKeyService.getApiKey(AiProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', 'Gemini API 키가 등록되지 않았습니다.');
    }

    final prompt = """
    Create a simple and natural example sentence using the English word "$word".
    The sentence MUST specifically reflect the provided Korean meaning: "$meaning".
    Respond with only the sentence itself, without any additional explanations or quotation marks.
    """;

    try {
      final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([gemini.Content.text(prompt)]);
      return response.text?.trim().replaceAll('"', '');
    } on Exception catch (e) {
      debugPrint('Gemini 예문 생성 오류: $e');
      throw CustomApiException('sentence_generation_failed', '예문 생성에 실패했습니다.');
    }
  }

  // 여러 단어에 대한 예문을 일괄 생성하는 메서드
  Future<Map<String, String>> generateSentencesForWords(List<Word> words, String modelName) async {
    final apiKey = await _apiKeyService.getApiKey(AiProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', 'Gemini API 키가 등록되지 않았습니다.');
    }

    final wordListJson = jsonEncode(
      words.map((w) => {'word': w.word, 'meaning': w.meaning}).toList(),
    );

    final prompt = """
    For each English word in the following JSON list, create one simple and natural example sentence.
    Each sentence MUST specifically reflect the provided Korean "meaning" for that word.
    Respond with ONLY a valid JSON object where each key is the English word and the value is its corresponding example sentence.

    Word list: $wordListJson

    Example response format for words "mold" (meaning: 주형) and "lead" (meaning: 이끌다):
    {
      "mold": "The sculptor poured liquid metal into the mold.",
      "lead": "She will lead the team to victory."
    }
    """;

    debugPrint("📝 [AI_SERVICE] 일괄 예문 생성 프롬프트:\n$prompt");

    try {
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

  // 단어장 기반 AI 퀴즈를 생성하는 메서드
  Future<AiQuizResponse?> generateQuiz({
    required AiProvider provider,
    required String modelName,
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
    required bool includeExplanation,
    required String questionLanguage,
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

    debugPrint("📝 [AI_SERVICE] 단어장 퀴즈 프롬프트:\n$prompt");

    try {
      String? responseText;
      if (provider == AiProvider.gemini) {
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([gemini.Content.text(prompt)]);
        responseText = response.text;
      }

      if (responseText != null) {
        final cleanedText = responseText.replaceAll('**', '');
        return AiQuizResponse.parse(cleanedText);
      }
      return null;
    } on Exception catch (e) {
      if (e.toString().contains('overloaded') || e.toString().contains('503')) {
        throw CustomApiException('server_overloaded', 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.');
      } else if (e.toString().contains('quota') || e.toString().contains('429')) {
        throw CustomApiException('quota_exceeded', 'API 사용량 한도를 초과했습니다.');
      } else {
        throw CustomApiException('unknown_error', '알 수 없는 오류가 발생했습니다: ${e.toString()}');
      }
    }
  }

  // 문법 퀴즈 생성을 위한 메서드
  Future<AiQuizResponse?> generateGrammarQuiz({
    required AiProvider provider,
    required String modelName,
    required GrammarCategory category,
    required List<GrammarChapter> chapters,
    required int questionCount,
    required String difficulty,
    required bool includeExplanation,
    required String questionLanguage,
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
    debugPrint("📝 [AI_SERVICE] 문법 퀴즈 생성 프롬프트:\n$prompt");

    try {
      String? responseText;
      if (provider == AiProvider.gemini) {
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([gemini.Content.text(prompt)]);
        responseText = response.text;
      }

      if (responseText != null) {
        debugPrint("📄 [AI_SERVICE] 문법 퀴즈 원본 응답:\n$responseText");
        return AiQuizResponse.parse(responseText);
      }
      return null;
    } on Exception catch (e) {
      debugPrint("❌ [AI_SERVICE] 문법 퀴즈 생성 중 오류 발생: $e");
      throw CustomApiException('unknown_error', '알 수 없는 오류가 발생했습니다: ${e.toString()}');
    }
  }

  String _buildGrammarPrompt(
    GrammarCategory category,
    List<GrammarChapter> chapters,
    int count,
    String difficulty,
    bool includeExplanation,
    String questionLanguage,
  ) {
    final chaptersString = chapters
        .map((c) {
          final detailsString = c.details.map((d) => "    - $d").join('\n');
          return "  - Chapter: ${c.title} (${c.description})\n$detailsString";
        })
        .join('\n');

    return """
    You are a professional English grammar instructor who creates exam questions for Korean students.
    Your task is to generate a high-quality grammar quiz based on the user's specific selections.

    # Mission
    Create exactly `$count` multiple-choice grammar questions that are strictly based on the provided "SELECTED CHAPTERS" and their "Details".

    # Core Rules
    1.  **Strictly Adhere to Scope**: All questions MUST test concepts only from the provided "SELECTED CHAPTERS". Do not include grammar points from other chapters.
    2.  **Utilize Details for Diversity**: You MUST create a variety of questions that test the different concepts listed in the "Details" section for each chapter. Do not create multiple questions testing the exact same detail.
    3.  **Vary Question Formats**: Do not only use "fill-in-the-blank". Mix in formats like "choose the grammatically correct/incorrect sentence" to make the quiz more effective.
    4.  **Language Requirements**: All keys and values in the JSON (question, options, answer) MUST be in $questionLanguage. The "explanation" field MUST be in KOREAN and clearly explain why the answer is correct based on the grammar rules.
    5.  **JSON Format**: The output MUST be a single, valid JSON object, adhering to the specified format. Do not include any markdown like `**` or ```json.

    # Example of How to Use "Details" to Create a Question
    - IF a selected chapter is "3. 조동사 심화 (Advanced Auxiliaries)"
    - AND one of its "Details" is "- should have p.p. (과거 사실에 대한 후회/유감)"
    - THEN, you should create a specific question that tests this exact concept, such as:
      "I ______ studied harder for the exam. I regret it now."
      Options: [ "should have", "must have", "could have", "would have" ]
      Answer: "should have"

    # Quiz Configuration
    - **Target Level:** ${category.title} (${category.description})
    - **Difficulty:** $difficulty
    - **Question Count:** $count
    - **Include Korean Explanation:** $includeExplanation
    - **Question Language:** $questionLanguage
    - **SELECTED CHAPTERS & DETAILS:**
$chaptersString

    # Required JSON Output Format
    { "questions": [ { "type": "grammar", "question": "...", "options": [], "answer": "...", "explanation": "..." } ] }
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
    final wordListString = words.map((w) => '"${w.word}":"${w.meaning}"').join(', ');
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

    const vocabularyInstructions = """
  **Area Specific Instructions for 'vocabulary' questions:**
  You MUST generate a diverse mix of the following sub-types. The `sub_type` field is MANDATORY.

  - **`sentence_completion`**: The `question` field MUST be a complete sentence. This sentence MUST contain EXACTLY ONE blank, represented as '______'. It is forbidden to have more than one blank. The user must choose the single word that best fills this single blank.
  - **`definition_matching`**: The question is a definition, and the options are words.
  - **`synonym_antonym`**: Ask for a synonym or an antonym of a given word.
  - **`word_form`**: Provide a sentence with a blank. The options MUST be different forms of the same root word.
  - **`categorization`**: Ask the user to identify which word belongs to a specific category.
  - **`confusing_words`**: Provide a sentence that tests the ability to distinguish between commonly confused words.
  """;

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

    const listeningInstructions = """
  **Area Specific Instructions for 'listening' questions:**
  The `type` MUST be "listening".
  - The dialogue or monologue MUST be placed in the `script` field. Use `[MALE]` and `[FEMALE]` tags to distinguish speakers in a dialogue.
  - The `question` field MUST contain ONLY the question about the script (e.g., "What are the speakers discussing?").
  - **CRITICAL RULE**: The `question` field MUST NOT contain the dialogue/monologue from the `script` field. They must be separate.
  """;

    String areaInstruction;
    String strictTypeConstraint = "";

    if (quizType != '종합') {
      final typeName = quizType.toLowerCase().replaceAll(' ', '_');
      strictTypeConstraint =
          "- **Critical Rule**: You MUST ONLY generate questions of the '$typeName' type. Do NOT include any other types like 'vocabulary', 'grammar', or 'reading_section' unless it is the requested type.";

      if (quizType == '어휘') {
        areaInstruction = vocabularyInstructions;
      } else if (quizType == '독해') {
        areaInstruction = readingInstructions;
      } else if (quizType == '듣기') {
        areaInstruction = listeningInstructions;
      } else {
        areaInstruction = "Generate questions for the '$typeName' type.";
      }
    } else {
      areaInstruction =
          "Generate a mix of questions from `vocabulary`, `grammar`, `reading_section`, and `listening`. For `vocabulary`, `reading`, and `listening` questions, follow their specific instructions if applicable.";
    }

    return """
    You are an expert English Language Test creator for Korean students.
    Your task is to create a quiz based on the provided word list and instructions.
    Follow all rules VERY STRICTLY.

    # 1. MANDATORY RULES
    $strictTypeConstraint
    - The total number of answerable questions MUST be EXACTLY `$count`. For types like `reading_section`, its sub-questions count towards this total.
    - All text in the JSON fields (question, options, answer) MUST be in $questionLanguage. The `explanation` field, if included, MUST be in KOREAN.
    - Do not use any markdown like `**` in the JSON output.
    - The correct answer MUST be clearly distinguishable from the incorrect options.
    - The user-selected words from the `Vocabulary List` MUST be included in the quiz, either as a question target or as one of the options.

    # 2. QUIZ CONFIGURATION
    - **Vocabulary List:** { $wordListString }
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Include Explanation in Korean:** `$includeExplanation`
    - **Question Language:** $questionLanguage

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
