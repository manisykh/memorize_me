class Word {
  final int? id;
  final String word;
  final String meaning;
  final String? exampleSentence;

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.exampleSentence, // ▼▼▼ [수정] 생성자에 누락된 필드 초기화 추가
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence, // ▼▼▼ [수정] 맵 변환 문법 오류 수정
    };
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'word': word,
      'meaning': meaning,
      'exampleSentence': exampleSentence, // ▼▼▼ [수정] 여기도 동일하게 수정
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      meaning: map['meaning'],
      exampleSentence: map['exampleSentence'], // ▼▼▼ [수정] 정상적으로 인자 전달
    );
  }
}
