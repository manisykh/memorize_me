class CustomApiException implements Exception {
  final String code;
  final String message;

  CustomApiException(this.code, this.message);

  @override
  String toString() => message;
}
