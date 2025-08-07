// lib/services/ai_service.dart

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

  // ▼▼▼ [수정] 전체 메서드 수정
  Future<Map<String, Map<String, String>>> generateSentencesForWords(
    List<Word> words,
    String modelName,
  ) async {
    final apiKey = await _apiKeyService.getApiKey(AiProvider.gemini);
    if (apiKey == null || apiKey.isEmpty) {
      throw CustomApiException('api_key_missing', 'Gemini API 키가 등록되지 않았습니다.');
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
      final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([gemini.Content.text(prompt)]);
      final responseText = response.text ?? '{}';
      final cleanedJson = responseText.replaceAll(RegExp(r'```json|```'), '').trim();
      final decodedJson = jsonDecode(cleanedJson) as Map<String, dynamic>;

      return decodedJson.map((key, value) {
        final valueMap = value as Map<String, dynamic>;
        return MapEntry(key, {
          "sentence": valueMap['sentence']?.toString() ?? '',
          "translation": valueMap['translation']?.toString() ?? '',
        });
      });
    } catch (e) {
      throw CustomApiException('sentence_generation_failed', '일괄 예문 생성에 실패했습니다.');
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
      if (provider == AiProvider.gemini) {
        final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([gemini.Content.text(prompt)]);
        responseText = response.text;
      }
      if (responseText != null) {
        return AiQuizResponse.parse(responseText);
      }
      return null;
    } on Exception catch (e) {
      throw CustomApiException('unknown_error', '알 수 없는 오류가 발생했습니다: ${e.toString()}');
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

  String _buildGrammarPrompt(
    GrammarCategory category,
    List<GrammarChapter> chapters,
    int count,
    String difficulty,
    bool includeExplanation,
    String questionLanguage,
  ) {
    // ... (기존과 동일)
    final chaptersString = chapters.map((c) => "  - ${c.description}: ${c.title}").join('\n');
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

    return """
    You are an adaptive learning assistant creating English grammar quizzes.
    Your MOST IMPORTANT task is to strictly control the difficulty of the questions, including the complexity of sentence structures, to match the user's selected level.

    # Mission
    Create exactly `$count` multiple-choice grammar questions based on the provided "SELECTED CHAPTERS".

    # Core Rules
    1.  **Strictly Adhere to Scope**: All questions MUST test concepts only from the "SELECTED CHAPTERS".
    2.  **Difficulty Adherence (CRITICAL)**: The complexity of sentence structure and vocabulary in your questions MUST precisely match the `Target Difficulty` description. This is your highest priority. It is a failure if you use simple sentences for a '전문가' level question.
    3.  **Vary Question Formats**: Mix formats like "fill-in-the-blank", "choose the grammatically correct/incorrect sentence".
    4.  **Language Requirements**: All JSON fields (question, options, answer) MUST be in $questionLanguage. The "explanation" field MUST be in KOREAN.
    5.  **JSON Format**: The output MUST be a single, valid JSON object without any markdown.

    # Quiz Configuration
    - **Target Level:** ${category.title}
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Question Count:** $count
    - **Include Korean Explanation:** $includeExplanation
    - **Question Language:** $questionLanguage
    - **SELECTED CHAPTERS:**
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
    // ... (기존과 동일)
    final wordListString = words.map((w) => '"${w.word}":"${w.meaning}"').join(', ');

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

    const vocabularyInstructions = """
  **Area Specific Instructions for 'vocabulary' questions:**
  - `sentence_completion`: The `question` MUST be a sentence with EXACTLY ONE blank ('______'). The sentence complexity and vocabulary MUST strictly match the `Target Difficulty`.
  - `definition_matching`: The `question` is a definition. Options are words.
  - `synonym_antonym`: Ask for a synonym or antonym.
  """;

    const readingInstructions = """
  **Area Specific Instructions for 'reading' questions:**
  - The `type` MUST be "reading_section".
  - **Passage Length & Complexity (CRITICAL)**: MUST be proportional to the `Target Difficulty`. 
    - '기초'/'기본': 1-3 simple sentences.
    - '중급'/'중고급': 1-2 paragraphs with some complex sentences.
    - '고급' or higher: 2-4 paragraphs with advanced vocabulary and complex structures.
  - **Question Types (CRITICAL)**: You MUST generate a diverse mix of sub-questions based on the `Target Difficulty` and the following `sub_type` list.
    - **For '기초'/'기본'**:
      - `main_idea`: Ask for the main idea.
      - `detail`: Ask for specific details (who, what, when, where).
    - **For '중급'/'중고급'**: In addition to the above, include:
      - `inference`: Ask the user to infer information not explicitly stated.
      - `purpose`: Ask about the author's purpose.
      - `contextual_vocabulary`: Ask for the meaning of a word in context.
    - **For '고급' or higher**: In addition to all the above, include challenging types like:
      - `tone_attitude`: Ask about the author's tone or attitude.
      - `paragraph_ordering`: Provide 3-4 paragraphs labeled (A), (B), (C)... out of order. The question asks for the correct sequence. The passage should contain the scrambled paragraphs, and the options should be permutations like ["(B)-(A)-(C)", "(C)-(A)-(B)", ...].
      - `sentence_insertion`: The passage should contain a marker like "[INSERT SENTENCE HERE]". The question asks which sentence from the options best fits into the passage.
  - **MANDATORY `questions` field**: Every `reading_section` object MUST contain a non-empty `questions` list with at least one sub-question object.
  """;

    const listeningInstructions = """
  **Area Specific Instructions for 'listening' questions:**
  - The `type` MUST be "listening".
  - **Script Length & Speed (CRITICAL)**: MUST be proportional to the `Target Difficulty`.
    - '기초'/'기본': 2-4 slow turns of dialogue.
    - '중급'/'중고급': 4-6 turns of natural speed dialogue.
    - '고급' or higher: A long monologue or a dialogue with >6 turns at a fast, natural pace.
  - The `question` field MUST NOT contain the script. It must only be the question about the script.
  """;

    String areaInstruction;
    String strictTypeConstraint = "";

    if (quizType != '종합') {
      final typeName = quizType.toLowerCase().replaceAll(' ', '_');
      strictTypeConstraint =
          "- **Critical Rule**: You MUST ONLY generate questions of the '$typeName' type.";
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
          "Generate a mix of questions from `vocabulary`, `grammar`, `reading_section`, and `listening`. Follow all specific instructions for each type.";
    }

    return """
    You are an adaptive learning assistant that creates English quizzes.
    Your MOST IMPORTANT task is to strictly and precisely control the difficulty of all generated content (questions, sentences, passages, scripts) to match the user's selected level.

    # 1. MANDATORY RULES
    $strictTypeConstraint
    - **Difficulty Adherence (HIGHEST PRIORITY)**: The complexity of vocabulary, sentence structure, and passage/script length used in ALL question types MUST strictly match the `Target Difficulty` description. It is a critical failure if you do not follow this rule.
    - Total answerable questions MUST be EXACTLY `$count`.
    - All text in JSON fields MUST be in $questionLanguage. The `explanation` field, if included, MUST be in KOREAN.
    - Do not use markdown like `**`.
    - User-selected words from the `Vocabulary List` MUST be included in the quiz.

    # 2. QUIZ CONFIGURATION
    - **Vocabulary List:** { $wordListString }
    - **Target Difficulty:** $difficulty. ($difficultyDescription)
    - **Include Korean Explanation:** `$includeExplanation`
    - **Question Language:** $questionLanguage

    # 3. QUESTION AREA & TYPE INSTRUCTIONS
    $areaInstruction

    # 4. REQUIRED JSON RESPONSE FORMAT
    Your output MUST be a single, valid JSON object.
    { "questions": [ /* ... your questions here ... */ ] }

    **FINAL CHECK: Review your generated quiz to ensure the passage/sentence/script length and question complexity STRICTLY match the requested '$difficulty' level. This is the highest priority.**
  """;
  }
}
