/// The outcome of an operation that can fail.
///
/// Returned instead of throwing so that callers are forced to handle the
/// failure case.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.failure(Object error, [StackTrace? stackTrace]) =
      Failure<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Failure<T>() => null,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure($error)';
}

/// An error whose [message] is safe to show to the user as-is.
class FeedException implements Exception {
  const FeedException(this.message);

  final String message;

  @override
  String toString() => message;
}
