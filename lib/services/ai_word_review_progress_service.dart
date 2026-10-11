import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_model.dart';

class AiWordReviewProgressService {
  const AiWordReviewProgressService();

  String _key(String dbFileName) => 'ai_word_review_v1.$dbFileName';

  String _fingerprint(Word word) => jsonEncode([
    word.word,
    word.meaning,
    word.additionalMeanings,
    word.exampleSentence,
    word.exampleSentenceTranslation,
  ]);

  Future<Map<String, String>> _read(String dbFileName) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(dbFileName));
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<Set<int>> reviewedWordIds(String dbFileName, List<Word> words) async {
    final fingerprints = await _read(dbFileName);
    return {
      for (final word in words)
        if (word.id != null && fingerprints['${word.id}'] == _fingerprint(word))
          word.id!,
    };
  }

  Future<void> markReviewed(String dbFileName, List<Word> words) async {
    final fingerprints = await _read(dbFileName);
    for (final word in words) {
      if (word.id != null) fingerprints['${word.id}'] = _fingerprint(word);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(dbFileName), jsonEncode(fingerprints));
  }
}
