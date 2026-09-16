sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int? code;
  const ApiFailure(this.message, {this.code});
}

class ApiLoading<T> extends ApiResult<T> {
  const ApiLoading();
}
