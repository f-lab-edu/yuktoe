sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.error(Exception error) = Error<T>;
}

final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

final class Error<T> extends Result<T> {
  final Exception error;

  const Error(this.error);
}
