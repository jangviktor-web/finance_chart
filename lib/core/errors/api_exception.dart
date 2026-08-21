/// API 异常类型
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? source;

  /// 原始异常（保留底层错误便于排障）
  final dynamic error;

  /// 原始调用栈
  final StackTrace? stackTrace;

  ApiException(
    this.message, {
    this.statusCode,
    this.source,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final parts = ['ApiException: $message'];
    if (statusCode != null) parts.add('Status: $statusCode');
    if (source != null) parts.add('Source: $source');
    if (error != null) parts.add('Cause: $error');
    return parts.join(', ');
  }
}

/// 网络连接异常
class NetworkException extends ApiException {
  NetworkException(String message, {String? source, dynamic error, StackTrace? stackTrace})
      : super(
          message,
          source: source ?? 'network',
          error: error,
          stackTrace: stackTrace,
        );
}

/// 数据解析异常
class ParseException extends ApiException {
  ParseException(String message, {String? source, dynamic error, StackTrace? stackTrace})
      : super(
          message,
          source: source ?? 'parse',
          error: error,
          stackTrace: stackTrace,
        );
}

/// 请求超时异常
class TimeoutException extends ApiException {
  TimeoutException(String message, {String? source, dynamic error, StackTrace? stackTrace})
      : super(
          message,
          source: source ?? 'timeout',
          error: error,
          stackTrace: stackTrace,
        );
}
