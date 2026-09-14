import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/rate_limiter.dart';

/// 东财请求：主域失败自动换镜像域重试 —— 「同源不同机」冗余。
///
/// 镜像范围见 [ApiEndpoints.mirrorOf]：
/// - `datacenter-web` → `datacenter`：**全部 reportName 可用**（实测响应体字节级一致）
/// - `push2` → `push2delay`：**仅实时类路径**（clist / ulist.np / kamt.rtmin / trends2）
///
/// ⚠️ 历史类路径（`stock/kline`、`stock/fflow/daykline`）**不是镜像** —— push2delay
/// 返回 HTTP 200 但 kline 是空数组、fflow 只有当日 1 条，会**静默丢数据**。
/// 这类调用必须传 `allowMirror: false` 或干脆不走本函数。
///
/// ⚠️ **本函数原样返回 `Response`，不做 JSON 解码**。东财 datacenter 系端点返回
/// `Content-Type: text/plain`，dio 不会自动解，`res.data` 是 String —— 取数前必须自己
/// decode（见各 datasource 里 `response.data is String ? json.decode(...) : response.data`）。
///
/// 什么算「失败」并触发换域：
/// 1. 抛异常 / 超时 / 非 2xx；
/// 2. **HTTP 200 但业务空** —— 东财限流与风控的典型形态是
///    `{"success":false,"message":"服务器繁忙"}` 或 `{"result":null,"data":null}`。
///    只判异常会漏掉最常见的那一类失效，所以这里连业务空一起判。
///
/// 不会误判「真的没有数据」：合法的空结果形如 `{"success":true,"result":{"data":[],"count":0}}`
/// （datacenter）或 `{"data":{"diff":[]}}`（push2），`result`/`data` 均非 null，不会触发换域。
Future<Response> getEmWithMirror(
  Dio dio,
  String url, {
  Map<String, dynamic>? params,
  bool allowMirror = true,
}) async {
  final mirror = allowMirror ? ApiEndpoints.mirrorOf(url) : url;
  final urls = <String>[url, if (mirror != url) mirror];

  Object? lastError;
  for (final u in urls) {
    try {
      await RateLimiter.instance.waitByUrl(u);
      final res = await dio.get(u, queryParameters: params);
      final empty = _classifyBusinessEmpty(res.data);
      if (empty != null) {
        lastError = EmptyResponseException(
          u,
          upstreamMessage: empty.message,
          definitiveNoData: empty.definitive,
        );
        continue;
      }
      return res;
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('东财请求失败: $url');
}

/// 东财「业务空」的判定与分类。`null` 表示不是业务空（正常响应）。
///
/// - `definitive: true` —— 上游明确答复「该标的没有这条数据」。这是关于**标的**的事实，
///   不是端点故障，故由 [EmptyResponseException] 带出去，让 `firstSuccess` 不把它算进
///   端点熔断（否则连看几个无覆盖标的就会误熔断，连累正常标的）。
/// - `definitive: false` —— 其余业务空（限流「服务器繁忙」、`result`/`data` 双 null 等），
///   保持原语义计入失败，熔断挡洪峰的作用不受影响。
///
/// ponytail: 用**窄白名单**认「无数据」文案，而不是去穷举限流文案 —— 上游改文案时最坏
/// 退化成旧行为（多熔断几次），不会反过来漏熔断。要调只需改 [_noDataMarkers]。
({bool definitive, String? message})? _classifyBusinessEmpty(dynamic data) {
  dynamic body = data;
  if (body is String) {
    final s = body.trim();
    if (s.isEmpty) return (definitive: false, message: null);
    try {
      body = json.decode(s);
    } catch (_) {
      return null; // 非 JSON（如 JS 包裹）交给调用方处理
    }
  }
  if (body is! Map) return null;
  final msg = body['message']?.toString();
  if (body['success'] == false) {
    return (
      definitive: msg != null && _noDataMarkers.any(msg.contains),
      message: msg,
    );
  }
  if (body['result'] == null && body['data'] == null) {
    return (definitive: false, message: msg);
  }
  return null;
}

/// 上游表示「该标的没有数据」的文案特征（窄白名单，见 [_classifyBusinessEmpty]）。
const List<String> _noDataMarkers = ['为空', '无数据', '不存在'];
