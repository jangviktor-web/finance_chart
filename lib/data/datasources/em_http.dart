import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
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
      if (_looksBusinessEmpty(res.data)) {
        lastError = Exception('东财业务空返回: $u');
        continue;
      }
      return res;
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('东财请求失败: $url');
}

/// 判断东财响应是否是「业务空」：显式 success=false，或 result/data 双双为 null。
bool _looksBusinessEmpty(dynamic data) {
  dynamic body = data;
  if (body is String) {
    final s = body.trim();
    if (s.isEmpty) return true;
    try {
      body = json.decode(s);
    } catch (_) {
      return false; // 非 JSON（如 JS 包裹）交给调用方处理
    }
  }
  if (body is! Map) return false;
  if (body['success'] == false) return true;
  return body['result'] == null && body['data'] == null;
}
