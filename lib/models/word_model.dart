class Word {
  final int? id;
  final String word;
  final String meaning;
  final String? exampleSentence;
  final int srsLevel;
  final String? nextReviewDate;

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.exampleSentence,
    this.srsLevel = 0,
    this.nextReviewDate,
  });

  Word copyWith({
    int? id,
    String? word,
    String? meaning,
    String? exampleSentence,
    int? srsLevel,
    String? nextReviewDate,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence,
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence,
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'] ?? '',
      meaning: map['meaning'] ?? '',
      exampleSentence: map['exampleSentence'],
      srsLevel: map['srsLevel'] ?? 0,
      nextReviewDate: map['nextReviewDate'],
    );
  }
}
