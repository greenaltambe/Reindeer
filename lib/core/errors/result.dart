import 'package:reindeer/core/errors/app_exception.dart';

/// Type-safe Result wrapper using Dart 3 sealed classes.
sealed class Result<T> {
  const Result();

  /// Returns `true` when the operation succeeded.
  bool get isSuccess => this is Success<T>;

  /// Returns `true` when the operation failed.
  bool get isFailure => this is Failure<T>;

  /// Pattern-matches both states cleanly.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException error) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      Failure<T>(:final error) => onFailure(error),
    };
  }
}

/// Represents a successful operation containing [data].
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

/// Represents a failed operation containing an [error].
final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppException error;
}
