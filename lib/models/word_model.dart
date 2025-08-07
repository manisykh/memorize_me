// lib/models/word_model.dart

class Word {
  final int? id;
  final String word;
  final String meaning;
  final String? exampleSentence;
  final String? exampleSentenceTranslation; // ▼▼▼ [추가] 예문 번역 필드
  final int srsLevel;
  final String? nextReviewDate;
  final int incorrectCount;
  final int correctStreak;

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.exampleSentence,
    this.exampleSentenceTranslation, // ▼▼▼ [추가]
    this.srsLevel = 0,
    this.nextReviewDate,
    this.incorrectCount = 0,
    this.correctStreak = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence,
      'exampleSentenceTranslation': exampleSentenceTranslation, // ▼▼▼ [추가]
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate,
      'incorrectCount': incorrectCount,
      'correctStreak': correctStreak,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      meaning: map['meaning'],
      exampleSentence: map['exampleSentence'],
      exampleSentenceTranslation: map['exampleSentenceTranslation'], // ▼▼▼ [추가]
      srsLevel: map['srsLevel'] ?? 0,
      nextReviewDate: map['nextReviewDate'],
      incorrectCount: map['incorrectCount'] ?? 0,
      correctStreak: map['correctStreak'] ?? 0,
    );
  }

  Word copyWith({
    int? id,
    String? word,
    String? meaning,
    String? exampleSentence,
    String? exampleSentenceTranslation, // ▼▼▼ [추가]
    int? srsLevel,
    String? nextReviewDate,
    int? incorrectCount,
    int? correctStreak,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      exampleSentenceTranslation:
          exampleSentenceTranslation ?? this.exampleSentenceTranslation, // ▼▼▼ [추가]
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      correctStreak: correctStreak ?? this.correctStreak,
    );
  }
}
