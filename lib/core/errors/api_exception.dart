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

/// 上游**业务空返回**（HTTP 200，但业务层说没有数据）。
///
/// [definitiveNoData] 是关键区分，决定它是否计入端点熔断（`SourceHealth`）：
/// - `true` —— 上游明确答复「该标的没有这条数据」（东财实测文案「返回数据为空」）。
///   这是**关于标的的事实**，不代表端点不健康，因此不该熔断；否则连续看几个无覆盖
///   标的（港股/美股/ETF）就会把共享同一端点的正常标的请求一起误熔断 5 分钟。
/// - `false` —— 限流/风控等**暂时性**业务空（如「服务器繁忙」）。仍按失败计入，
///   保留熔断挡洪峰的作用。
class EmptyResponseException extends ApiException {
  final String url;
  final String? upstreamMessage;
  final bool definitiveNoData;

  EmptyResponseException(this.url, {this.upstreamMessage, this.definitiveNoData = false})
      : super(
          '业务空返回: $url${upstreamMessage == null ? '' : ' ($upstreamMessage)'}',
          source: 'upstream',
        );
}
