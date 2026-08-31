// lib/models/word_model.dart

import 'dart:convert';

class Word {
  final int? id;
  final String word;
  final String meaning;
  final List<String> additionalMeanings;
  final String? exampleSentence;
  final String? exampleSentenceTranslation; // ▼▼▼ [추가] 예문 번역 필드
  final int srsLevel;
  final String? nextReviewDate;
  final String? lastReviewedAt;
  final int incorrectCount;
  final int correctStreak;
  final int pendingMcqReview;
  final int pendingSpellingReview;

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.additionalMeanings = const [],
    this.exampleSentence,
    this.exampleSentenceTranslation, // ▼▼▼ [추가]
    this.srsLevel = 0,
    this.nextReviewDate,
    this.lastReviewedAt,
    this.incorrectCount = 0,
    this.correctStreak = 0,
    this.pendingMcqReview = 0,
    this.pendingSpellingReview = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'additionalMeanings': jsonEncode(additionalMeanings),
      'exampleSentence': exampleSentence,
      'exampleSentenceTranslation': exampleSentenceTranslation, // ▼▼▼ [추가]
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate,
      'lastReviewedAt': lastReviewedAt,
      'incorrectCount': incorrectCount,
      'correctStreak': correctStreak,
      'pendingMcqReview': pendingMcqReview,
      'pendingSpellingReview': pendingSpellingReview,
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
      additionalMeanings: _decodeAdditionalMeanings(map['additionalMeanings']),
      exampleSentence: map['exampleSentence'],
      exampleSentenceTranslation: map['exampleSentenceTranslation'], // ▼▼▼ [추가]
      srsLevel: map['srsLevel'] ?? 0,
      nextReviewDate: map['nextReviewDate'],
      lastReviewedAt: map['lastReviewedAt'],
      incorrectCount: map['incorrectCount'] ?? 0,
      correctStreak: map['correctStreak'] ?? 0,
      pendingMcqReview: map['pendingMcqReview'] ?? 0,
      pendingSpellingReview: map['pendingSpellingReview'] ?? 0,
    );
  }

  Word copyWith({
    int? id,
    String? word,
    String? meaning,
    List<String>? additionalMeanings,
    String? exampleSentence,
    String? exampleSentenceTranslation, // ▼▼▼ [추가]
    int? srsLevel,
    String? nextReviewDate,
    String? lastReviewedAt,
    int? incorrectCount,
    int? correctStreak,
    int? pendingMcqReview,
    int? pendingSpellingReview,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      additionalMeanings: additionalMeanings ?? this.additionalMeanings,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      exampleSentenceTranslation:
          exampleSentenceTranslation ?? this.exampleSentenceTranslation, // ▼▼▼ [추가]
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      correctStreak: correctStreak ?? this.correctStreak,
      pendingMcqReview: pendingMcqReview ?? this.pendingMcqReview,
      pendingSpellingReview: pendingSpellingReview ?? this.pendingSpellingReview,
    );
  }

  static List<String> _decodeAdditionalMeanings(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    if (value is! String || value.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
