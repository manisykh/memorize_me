// models/wordbook_model.dart

class Wordbook {
  final int? id; // 메타 DB에서의 고유 ID
  final String name; // 사용자가 지정한 단어장 이름
  final String spreadsheetId; // 연동된 구글 시트 파일 ID
  final String sheetName; // 선택한 시트 이름
  final String dbFileName; // 실제 단어가 저장될 로컬 DB 파일명

  Wordbook({
    this.id,
    required this.name,
    required this.spreadsheetId,
    required this.sheetName,
    required this.dbFileName,
  });

  // DB 저장을 위해 Map 형태로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'spreadsheetId': spreadsheetId,
      'sheetName': sheetName,
      'dbFileName': dbFileName,
    };
  }

  // Map에서 Wordbook 객체로 변환
  factory Wordbook.fromMap(Map<String, dynamic> map) {
    return Wordbook(
      id: map['id'],
      name: map['name'],
      spreadsheetId: map['spreadsheetId'],
      sheetName: map['sheetName'],
      dbFileName: map['dbFileName'],
    );
  }
}
