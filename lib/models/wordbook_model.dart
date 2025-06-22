// lib/models/wordbook_model.dart (copyWith 추가)

enum WordbookSource { googleSheet, localCsv }

class Wordbook {
  final int? id;
  final String name;
  final String spreadsheetId;
  final String sheetName;
  final String dbFileName;
  final WordbookSource source;

  Wordbook({
    this.id,
    required this.name,
    this.spreadsheetId = '',
    this.sheetName = '',
    required this.dbFileName,
    required this.source,
  });

  // ▼▼▼ [추가] copyWith 메서드 ▼▼▼
  Wordbook copyWith({
    int? id,
    String? name,
    String? spreadsheetId,
    String? sheetName,
    String? dbFileName,
    WordbookSource? source,
  }) {
    return Wordbook(
      id: id ?? this.id,
      name: name ?? this.name,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      sheetName: sheetName ?? this.sheetName,
      dbFileName: dbFileName ?? this.dbFileName,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'spreadsheetId': spreadsheetId,
      'sheetName': sheetName,
      'dbFileName': dbFileName,
      'source': source.toString(),
    };
  }

  factory Wordbook.fromMap(Map<String, dynamic> map) {
    final sourceString = map['source'] as String?;
    final sourceEnum = WordbookSource.values.firstWhere(
      (e) => e.toString() == sourceString,
      orElse: () => WordbookSource.googleSheet,
    );

    return Wordbook(
      id: map['id'],
      name: map['name'],
      spreadsheetId: map['spreadsheetId'] ?? '',
      sheetName: map['sheetName'] ?? '',
      dbFileName: map['dbFileName'],
      source: sourceEnum,
    );
  }
}
