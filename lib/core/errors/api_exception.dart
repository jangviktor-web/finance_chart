/// API 异常类型
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? source;

  ApiException(this.message, {this.statusCode, this.source});

  @override
  String toString() {
    final parts = ['ApiException: $message'];
    if (statusCode != null) parts.add('Status: $statusCode');
    if (source != null) parts.add('Source: $source');
    return parts.join(', ');
  }
}

/// 网络连接异常
class NetworkException extends ApiException {
  NetworkException(String message, {String? source})
      : super(message, source: source ?? 'network');
}

/// 数据解析异常
class ParseException extends ApiException {
  ParseException(String message, {String? source})
      : super(message, source: source ?? 'parse');
}

/// 请求超时异常
class TimeoutException extends ApiException {
  TimeoutException(String message, {String? source})
      : super(message, source: source ?? 'timeout');
}
