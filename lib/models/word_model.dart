// lib/models/word_model.dart (수정된 전체 코드)

class Word {
  final int? id;
  final String word;
  final String meaning;

  Word({this.id, required this.word, required this.meaning});

  // DB 저장을 위해 Map 형태로 변환하는 메서드
  Map<String, dynamic> toMap() {
    return {'id': id, 'word': word, 'meaning': meaning};
  }

  // ▼▼▼ [추가] 새로운 단어로 삽입할 때 사용할 맵 (id 제외) ▼▼▼
  Map<String, dynamic> toMapForInsert() {
    return {'word': word, 'meaning': meaning};
  }

  // Map 형태에서 Word 객체로 변환하는 메서드
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(id: map['id'], word: map['word'], meaning: map['meaning']);
  }
}
