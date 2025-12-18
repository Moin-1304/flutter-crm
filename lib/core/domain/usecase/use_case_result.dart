/// A generic result wrapper for use cases that can return either success data or an error
class UseCaseResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  UseCaseResult._({
    required this.data,
    required this.error,
    required this.isSuccess,
  });

  /// Creates a successful result with data
  factory UseCaseResult.success(T data) {
    return UseCaseResult._(
      data: data,
      error: null,
      isSuccess: true,
    );
  }

  /// Creates an error result with error message
  factory UseCaseResult.error(String error) {
    return UseCaseResult._(
      data: null,
      error: error,
      isSuccess: false,
    );
  }
}
