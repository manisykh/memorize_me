// models/wordbook_model.dart  <- 이 파일의 내용을 아래 코드로 완전히 교체하세요.

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
    // DB에서 읽어온 'source' 문자열
    final sourceString = map['source'] as String?;

    // 문자열을 Enum으로 변환합니다.
    // 만약 DB에 source 값이 없거나(null) 매칭되는 값이 없으면 googleSheet를 기본값으로 사용합니다.
    // 이 로직 덕분에 오래된 DB 데이터를 읽어도 오류가 발생하지 않아야 합니다.
    final sourceEnum = WordbookSource.values.firstWhere(
      (e) => e.toString() == sourceString,
      orElse: () => WordbookSource.googleSheet,
    );

    return Wordbook(
      id: map['id'],
      name: map['name'],
      spreadsheetId: map['spreadsheetId'],
      sheetName: map['sheetName'],
      dbFileName: map['dbFileName'],
      source: sourceEnum, // 'source' 파라미터에 값을 반드시 전달합니다.
    );
  }
}
