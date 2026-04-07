enum ErrorCode {
  networkError,
  unauthorized,
  invalidResponse,
  parseFailed,
  notFound,
  unknown,
}

class AppException implements Exception {
  final ErrorCode code;
  final String message;
  final Object? cause;

  const AppException(this.code, this.message, {this.cause});

  @override
  String toString() => 'AppException(code: $code, message: $message, cause: $cause)';
}
