// lib/models/word_model.dart

class Word {
  final int? id;
  final String word;
  final String meaning;
  final String? exampleSentence;
  final int srsLevel;
  final String? nextReviewDate;
  final int incorrectCount; // ▼▼▼ [추가] 오답 횟수
  final int correctStreak; // ▼▼▼ [추가] 연속 정답 횟수

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.exampleSentence,
    this.srsLevel = 0,
    this.nextReviewDate,
    this.incorrectCount = 0, // ▼▼▼ [추가]
    this.correctStreak = 0, // ▼▼▼ [추가]
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence,
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate,
      'incorrectCount': incorrectCount, // ▼▼▼ [추가]
      'correctStreak': correctStreak, // ▼▼▼ [추가]
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
      srsLevel: map['srsLevel'] ?? 0,
      nextReviewDate: map['nextReviewDate'],
      incorrectCount: map['incorrectCount'] ?? 0, // ▼▼▼ [추가]
      correctStreak: map['correctStreak'] ?? 0, // ▼▼▼ [추가]
    );
  }

  Word copyWith({
    int? id,
    String? word,
    String? meaning,
    String? exampleSentence,
    int? srsLevel,
    String? nextReviewDate,
    int? incorrectCount, // ▼▼▼ [추가]
    int? correctStreak, // ▼▼▼ [추가]
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      incorrectCount: incorrectCount ?? this.incorrectCount, // ▼▼▼ [추가]
      correctStreak: correctStreak ?? this.correctStreak, // ▼▼▼ [추가]
    );
  }
}
