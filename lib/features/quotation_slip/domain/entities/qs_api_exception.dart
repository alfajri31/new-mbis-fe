/// Exception khusus pemanggilan API Quotation Slip.
/// Memuat [statusCode] HTTP dan [message] ramah pengguna dari server.
class QsApiException implements Exception {
  final int statusCode;
  final String message;

  const QsApiException(this.statusCode, this.message);

  @override
  String toString() => 'QsApiException($statusCode): $message';
}
