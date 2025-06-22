// lib/services/ai_service.dart (modelName 파라미터가 추가된 최종 코드)

import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:dart_openai/dart_openai.dart' as openai;

import '../models/word_model.dart';
import '../models/ai_quiz_model.dart';
import 'api_key_service.dart';

class AiService {
  final ApiKeyService _apiKeyService;

  AiService(this._apiKeyService);

  // ▼▼▼ [수정] generateQuiz 함수에 modelName 파라미터를 추가합니다. ▼▼▼
  Future<AiQuizResponse?> generateQuiz({
    required AiProvider provider,
    required String modelName, // 이 파라미터를 받도록 수정
    required List<Word> selectedWords,
    required String quizType,
    required String difficulty,
    required int questionCount,
  }) async {
    final apiKey = await _apiKeyService.getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('${provider.name} API 키가 등록되지 않았습니다.');
    }

    final prompt = _buildPrompt(selectedWords, quizType, difficulty, questionCount);

    try {
      if (provider == AiProvider.gemini) {
        return await _generateWithGemini(apiKey, prompt, modelName);
      } else {
        return await _generateWithOpenAI(apiKey, prompt, modelName);
      }
    } catch (e) {
      print('$provider AI 서비스 오류 발생: $e');
      return null;
    }
  }

  Future<AiQuizResponse> _generateWithGemini(String apiKey, String prompt, String modelName) async {
    final model = gemini.GenerativeModel(model: modelName, apiKey: apiKey); // 전달받은 modelName 사용
    final response = await model.generateContent([gemini.Content.text(prompt)]);
    return AiQuestion.parse(response.text!);
  }

  Future<AiQuizResponse> _generateWithOpenAI(String apiKey, String prompt, String modelName) async {
    openai.OpenAI.apiKey = apiKey;
    final chatCompletion = await openai.OpenAI.instance.chat.create(
      model: modelName, // 전달받은 modelName 사용
      messages: [
        openai.OpenAIChatCompletionChoiceMessageModel(
          role: openai.OpenAIChatMessageRole.system,
          content: [
            openai.OpenAIChatCompletionChoiceMessageContentItemModel.text(
              "당신은 전문적인 영어 교육 콘텐츠 제작자입니다. 사용자의 요청에 따라 문제를 생성하고, 반드시 지정된 JSON 형식으로만 응답해야 합니다.",
            ),
          ],
        ),
        openai.OpenAIChatCompletionChoiceMessageModel(
          role: openai.OpenAIChatMessageRole.user,
          content: [openai.OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
        ),
      ],
      responseFormat: {"type": "json_object"},
    );
    final responseText = chatCompletion.choices.first.message.content?.first.text;
    return AiQuestion.parse(responseText!);
  }

  String _buildPrompt(List<Word> words, String type, String difficulty, int count) {
    final wordListString = words.map((w) => '"${w.word}":"${w.meaning}"').join(', ');
    return """
      # 지시사항:
      1.  **문제 생성**: 아래 제공된 단어 목록을 반드시 활용하여 문제를 만드세요.
      2.  **출제 영역**: '${type.replaceAll("종합", "어휘, 문법, 독해, 듣기")}' 영역의 문제를 골고루 출제하세요.
      3.  **난이도**: '$difficulty' 수준에 맞춰 문제를 출제하세요.
      4.  **문제 수**: 총 '$count'개의 문제를 생성하세요.
      5.  **독해/듣기**: '독해' 또는 '듣기' 유형의 문제를 만들 때는, 지문('passage')이나 스크립트('script')를 반드시 포함해야 합니다. 지문과 스크립트 안에는 주어진 단어들을 자연스럽게 녹여내세요.
      6.  **선택지**: 모든 문제는 4개의 선택지를 가져야 하며, 정답은 그 중 하나여야 합니다.
      7.  **응답 형식**: 결과는 반드시 아래에 명시된 JSON 형식으로만 응답해야 합니다. 다른 설명이나 응답은 절대 추가하지 마세요.

      # 제공된 단어 목록:
      { $wordListString }

      # 필수 JSON 응답 형식:
      {
        "questions": [
          {
            "type": "문제유형(vocabulary, grammar, reading, listening)",
            "passage": "독해 문제일 경우에만 여기에 지문을 포함",
            "script": "듣기 문제일 경우에 '듣기 평가용 스크립트'를 여기에 포함",
            "question": "문제 내용",
            "options": ["선택지 1", "선택지 2", "선택지 3", "선택지 4"],
            "answer": "정답 내용(선택지 중 하나와 일치해야 함)"
          }
        ]
      }
      """;
  }
}
