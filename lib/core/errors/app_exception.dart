/// Sealed hierarchy of application exceptions for predictable error handling.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException(${code != null ? '$code: ' : ''}$message)';
}

/// Network or remote server error.
final class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.cause,
    this.statusCode,
  });

  final int? statusCode;
}

/// Local storage or cache error.
final class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.cause});
}

/// Validation or invalid user input error.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});
}

/// Unexpected fallback error.
final class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.code, super.cause});
}
