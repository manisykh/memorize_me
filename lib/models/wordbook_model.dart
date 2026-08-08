enum WordbookSource { googleSheet, localCsv, builtin }

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
      orElse: () => WordbookSource.localCsv,
    );

    return Wordbook(
      id: map['id'],
      name: map['name'] ?? 'Unnamed Wordbook',
      spreadsheetId: map['spreadsheetId'] ?? '',
      sheetName: map['sheetName'] ?? '',
      dbFileName: map['dbFileName'],
      source: sourceEnum,
    );
  }
}
