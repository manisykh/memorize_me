class AiDifficultyProfile {
  final int level;
  final String label;
  final String audience;
  final String cefr;
  final String lexile;
  final String sentenceLength;
  final String passageLength;
  final int contextMinWords;
  final int contextMaxWords;
  final int passageMinWords;
  final int passageMaxWords;
  final String languageGuide;
  final String reasoningGuide;
  final String questionFormats;

  const AiDifficultyProfile({
    required this.level,
    required this.label,
    required this.audience,
    required this.cefr,
    required this.lexile,
    required this.sentenceLength,
    required this.passageLength,
    required this.contextMinWords,
    required this.contextMaxWords,
    required this.passageMinWords,
    required this.passageMaxWords,
    required this.languageGuide,
    required this.reasoningGuide,
    required this.questionFormats,
  });

  String get uiSummary =>
      '$audience · CEFR $cefr · Lexile $lexile\n$sentenceLength · 지문 $passageLength';

  String toPromptGuide() => '''
Level $level — $label
- Learner benchmark: $audience
- CEFR reference: $cefr
- Lexile composition target: $lexile
- Sentence length: $sentenceLength
- Reading passage length: $passageLength
- Language and syntax: $languageGuide
- Cognitive demand and distractors: $reasoningGuide
- Preferred question formats: $questionFormats
''';
}

class AiDifficultyProfiles {
  const AiDifficultyProfiles._();

  static const List<AiDifficultyProfile> values = [
    AiDifficultyProfile(
      level: 1,
      label: '기초',
      audience: '초등 저학년(1–3학년)',
      cefr: 'Pre-A1–A1',
      lexile: 'BR–300L',
      sentenceLength: '문맥 문장 6–10단어',
      passageLength: '50–80단어, 3–6개의 짧은 문장',
      contextMinWords: 6,
      contextMaxWords: 10,
      passageMinWords: 50,
      passageMaxWords: 80,
      languageGuide: '현재형 중심의 단순 S+V 또는 S+V+O 문장, 구체적이고 일상적인 고빈도 어휘',
      reasoningGuide: '명시된 뜻·사실을 바로 찾게 하며 오답은 같은 품사이되 분명히 구별되게 구성',
      questionFormats: '그림처럼 구체적인 문맥, 뜻 연결, 한 칸 빈칸, 명시적 세부 내용',
    ),
    AiDifficultyProfile(
      level: 2,
      label: '기본',
      audience: '초등 고학년(4–6학년)',
      cefr: 'A1–A2',
      lexile: '300–500L',
      sentenceLength: '문맥 문장 8–14단어',
      passageLength: '80–120단어, 짧은 한 문단',
      contextMinWords: 8,
      contextMaxWords: 14,
      passageMinWords: 80,
      passageMaxWords: 120,
      languageGuide: 'because, when, but을 사용한 기초 복문과 기본 시제·대명사·전치사',
      reasoningGuide: '순서, 원인·결과, 직접적인 문맥 단서를 묻고 오답은 흔한 초급 오류로 구성',
      questionFormats: '뜻·예문 연결, 기초 연어, 시제·일치, 순서와 사실 확인',
    ),
    AiDifficultyProfile(
      level: 3,
      label: '중급',
      audience: '중학교 수준',
      cefr: 'A2–B1',
      lexile: '500–750L',
      sentenceLength: '문맥 문장 12–20단어',
      passageLength: '120–180단어, 1–2개 문단',
      contextMinWords: 12,
      contextMaxWords: 20,
      passageMinWords: 120,
      passageMaxWords: 180,
      languageGuide: '등위·종속절을 섞고 학교생활과 일반 교양 어휘 및 다양한 기본 시제를 사용',
      reasoningGuide: '중심 내용, 간단한 추론, 문맥상 의미와 원인·결과를 판단하게 구성',
      questionFormats: '문맥 어휘, 연결어·시제, 중심 내용, 간단한 추론',
    ),
    AiDifficultyProfile(
      level: 4,
      label: '중고급',
      audience: '중학교 상위–고등학교 초반',
      cefr: 'B1–B2',
      lexile: '750–950L',
      sentenceLength: '문맥 문장 16–26단어',
      passageLength: '180–260단어, 2–3개 문단',
      contextMinWords: 16,
      contextMaxWords: 26,
      passageMinWords: 180,
      passageMaxWords: 260,
      languageGuide: '관계절·부사절·명사절·분사구문을 포함하고 다소 추상적인 일반 교양 어휘 사용',
      reasoningGuide: '바꿔쓰기, 글의 구조, 근거 기반 추론을 요구하며 오답의 표면상 개연성을 높임',
      questionFormats: '바꿔쓰기, 문법 판단, 글의 흐름·구조, 근거 추론',
    ),
    AiDifficultyProfile(
      level: 5,
      label: '고급',
      audience: '고등학교·수능 수준',
      cefr: 'B2',
      lexile: '950–1100L',
      sentenceLength: '문맥 문장 20–32단어',
      passageLength: '250–350단어, 2–4개 문단',
      contextMinWords: 20,
      contextMaxWords: 32,
      passageMinWords: 250,
      passageMaxWords: 350,
      languageGuide: '중첩절·축약 관계절·분사구문과 정규 고등학교 학술·시사 어휘 사용',
      reasoningGuide: '목적·어조·논리 관계와 함의를 판단하게 하며 정교하고 그럴듯한 오답 구성',
      questionFormats: '수능형 문맥 어휘, 어법, 목적·어조, 빈칸 논리, 고난도 추론',
    ),
    AiDifficultyProfile(
      level: 6,
      label: '최상급',
      audience: '대학·TOEFL/TEPS 수준',
      cefr: 'B2–C1',
      lexile: '1100–1300L',
      sentenceLength: '문맥 문장 24–40단어',
      passageLength: '350–500단어, 3–5개 문단',
      contextMinWords: 24,
      contextMaxWords: 40,
      passageMinWords: 350,
      passageMaxWords: 500,
      languageGuide: '명사화·도치·생략을 포함한 밀도 높은 복문과 분야 횡단 학술 어휘 사용',
      reasoningGuide: '여러 근거의 종합, 수사적 기능, 필자의 태도를 묻고 근접 의미 오답을 사용',
      questionFormats: 'TOEFL/TEPS형 종합, 수사 기능, 근거 종합, 미묘한 용법 구별',
    ),
    AiDifficultyProfile(
      level: 7,
      label: '전문가',
      audience: '논문·전문직·네이티브 시사 매거진 수준',
      cefr: 'C1–C2',
      lexile: '1300L+',
      sentenceLength: '문맥 문장 28–50단어, 자연스러운 장단문 변주',
      passageLength: '500–750단어, 논증 구조가 있는 4–7개 문단',
      contextMinWords: 28,
      contextMaxWords: 50,
      passageMinWords: 500,
      passageMaxWords: 750,
      languageGuide: '학술 논문과 권위 있는 영미권 매거진 수준의 정밀한 전문·관용 어휘 및 복합 구문 사용',
      reasoningGuide: '논증 평가, 암묵적 관점, 전제, 방법론적 한계를 면밀한 독해로 판별하게 구성',
      questionFormats: '주장·전제 평가, 방법론 한계, 함축 태도, 전문 용어의 정밀한 문맥 의미',
    ),
  ];

  static List<String> get labels =>
      values.map((profile) => profile.label).toList(growable: false);

  static AiDifficultyProfile forLevel(int level) =>
      values[(level - 1).clamp(0, 6)];

  static AiDifficultyProfile fromLabel(String label) => values.firstWhere(
    (profile) => profile.label == label,
    orElse: () => values[2],
  );
}
