import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/data/datasources/em_http.dart';

/// 用拦截器短路请求，验证 getEmWithMirror 的镜像换域逻辑，
/// 重点证明「镜像域真被请求到」，而非代码里仅存在字符串。
class _MockInterceptor extends Interceptor {
  final Map<String, int> _status;
  final Map<String, Map<String, dynamic>> _body;

  _MockInterceptor(this._status, this._body);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.uri.toString();
    final code = _status[key] ?? 200;
    final body = _body[key] ?? {'ok': true};
    if (code >= 400) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(statusCode: code, requestOptions: options, data: body),
        ),
        true,
      );
    } else {
      handler.resolve(Response(statusCode: code, requestOptions: options, data: body));
    }
  }
}

void main() {
  test('主域 200 直接返回，不碰镜像', () async {
    final main = 'https://datacenter-web.eastmoney.com/x';
    final dio = Dio()..interceptors.add(_MockInterceptor({main: 200}, {main: {'result': {'data': [1]}}}));
    final res = await getEmWithMirror(dio, main);
    final d = res.data is String ? json.decode(res.data) : res.data;
    expect(d['result']['data'], [1]);
  });

  test('主域 500 → 真正换到镜像域', () async {
    final main = 'https://datacenter-web.eastmoney.com/x';
    final mirror = 'https://datacenter.eastmoney.com/x';
    final dio = Dio()
      ..interceptors.add(_MockInterceptor({main: 500, mirror: 200}, {mirror: {'result': {'data': [2]}}}));
    final res = await getEmWithMirror(dio, main);
    final d = res.data is String ? json.decode(res.data) : res.data;
    expect(d['result']['data'], [2]);
  });

  test('主域业务空(result/data 双 null) → 换镜像域', () async {
    final main = 'https://datacenter-web.eastmoney.com/x';
    final mirror = 'https://datacenter.eastmoney.com/x';
    final dio = Dio()
      ..interceptors.add(_MockInterceptor(
        {main: 200, mirror: 200},
        {main: {'result': null, 'data': null}, mirror: {'result': {'data': [3]}}},
      ));
    final res = await getEmWithMirror(dio, main);
    final d = res.data is String ? json.decode(res.data) : res.data;
    expect(d['result']['data'], [3]);
  });

  test('主域与镜像域都失败 → 抛异常', () async {
    final main = 'https://datacenter-web.eastmoney.com/x';
    final dio = Dio()..interceptors.add(_MockInterceptor({main: 500}, {}));
    expect(() => getEmWithMirror(dio, main), throwsA(anything));
  });
}
