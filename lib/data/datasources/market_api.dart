import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import '../models/kline_data.dart';
import '../models/realtime_quote.dart';
import '../models/data_source_config.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/stock_code_utils.dart';
import 'baidu_api.dart';

/// 行情数据 API — 多数据源支持
class MarketApi {
  final Dio _dio;
  final BaiduApi _baiduApi;
  final DataSourceType realtimeSource;
  final DataSourceType klineSource;

  MarketApi({
    Dio? dio,
    this.realtimeSource = DataSourceType.auto,
    this.klineSource = DataSourceType.auto,
  })  : _dio = dio ?? _createDio(),
        _baiduApi = BaiduApi();

  static Dio _createDio() {
    final d = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ));
    // 重试拦截器
    d.interceptors.add(RetryInterceptor(maxRetries: 2));
    return d;
  }

  // ──────────── 实时行情 ────────────

  /// 获取实时行情 — 根据配置选择数据源
  Future<RealtimeQuote> getRealtime(String code) async {
    if (realtimeSource == DataSourceType.tencent) {
      return await _getRealtimeFromTencentRaw(code);
    } else if (realtimeSource == DataSourceType.eastmoney) {
      return await _getRealtimeFromEastmoney(code);
    } else if (realtimeSource == DataSourceType.baidu) {
      return await _baiduApi.getRealtime(code);
    } else {
      // auto 模式：腾讯 → 东方财富 → 百度
      try {
        return await _getRealtimeFromTencentRaw(code);
      } catch (e) {
        try {
          return await _getRealtimeFromEastmoney(code);
        } catch (e2) {
          return await _baiduApi.getRealtime(code);
        }
      }
    }
  }

  /// 东方财富实时行情 — 用 raw HttpClient 绕开 Dio 编码干扰
  Future<RealtimeQuote> _getRealtimeFromEastmoney(String code) async {
    final secid = StockCodeUtils.toSecId(code);
    final url = '${ApiEndpoints.eastmoneyRealtime}?fltt=2&secids=$secid'
        '&fields=f2,f3,f4,f5,f6,f12,f14,f15,f16,f17,f18';

    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Referer', 'https://quote.eastmoney.com/');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      ).then((b) => b.toBytes());

      final body = utf8.decode(bytes, allowMalformed: true);
      final data = json.decode(body);

    if (data['data'] == null || data['data']['diff'] == null) {
      throw ParseException('东方财富返回空数据');
    }

    final diff = data['data']['diff'] as List;
    if (diff.isEmpty) throw ParseException('东方财富返回空列表');

    final item = diff[0] as Map<String, dynamic>;
    final formatted = StockCodeUtils.format(code);

    return RealtimeQuote(
      code: formatted.toUpperCase(),
      name: item['f14']?.toString() ?? '',
      now: (item['f2'] as num?)?.toDouble() ?? 0,
      yesterday: (item['f18'] as num?)?.toDouble() ?? 0,
      high: (item['f15'] as num?)?.toDouble() ?? 0,
      low: (item['f16'] as num?)?.toDouble() ?? 0,
      volume: (item['f5'] as num?)?.toDouble() ?? 0,
      amount: (item['f6'] as num?)?.toDouble() ?? 0,
      time: DateTime.now(),
    );
    } finally {
      client.close();
    }
  }

  /// 腾讯实时行情 — raw HttpClient + fast_gbk 解码
  Future<RealtimeQuote> _getRealtimeFromTencentRaw(String code) async {
    final formatted = StockCodeUtils.format(code);
    final url = '${ApiEndpoints.tencentRealtime}$formatted';

    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      ).then((b) => b.toBytes());

      // fast_gbk 正确解码 GBK 编码的中文
      final body = gbk.decode(bytes);

      // 格式: v_sh600519="1~贵州茅台~600519~1849.00~1845.00~..."
      final match = RegExp(r'"(.+?)"').firstMatch(body);
      if (match == null) throw ParseException('腾讯数据格式错误');

      final fields = match.group(1)!.split('~');
      if (fields.length < 35) throw ParseException('腾讯数据字段不足');

      return RealtimeQuote(
        code: formatted.toUpperCase(),
        name: fields[1],
        now: double.tryParse(fields[3]) ?? 0,
        yesterday: double.tryParse(fields[4]) ?? 0,
        high: double.tryParse(fields[33]) ?? 0,
        low: double.tryParse(fields[34]) ?? 0,
        volume: double.tryParse(fields[6]) ?? 0,
        amount: double.tryParse(fields[37]) ?? 0,
        time: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }

  // ──────────── 历史 K 线 ────────────

  /// 获取历史 K 线 — 根据配置选择数据源
  Future<List<KlineData>> getKline({
    required String code,
    String period = 'day',
    int count = 200,
  }) async {
    if (klineSource == DataSourceType.baidu) {
      return await _baiduApi.getKline(code: code, count: count);
    } else if (klineSource == DataSourceType.sina) {
      return await _getKlineFromSina(code, period, count);
    } else if (klineSource == DataSourceType.tencent) {
      return await _getKlineFromTencent(code, period, count);
    } else {
      // auto 模式：并行竞速
      final sources = <_Source<List<KlineData>>>[
        _Source('tencent', _getKlineFromTencent(code, period, count)),
      ];

      // 新浪只支持日/周/月线
      if (['day', 'week', 'month'].contains(period)) {
        sources.add(_Source('sina', _getKlineFromSina(code, period, count)));
      }

      // 百度作为兜底
      sources.add(_Source('baidu', _baiduApi.getKline(code: code, count: count)));

      return _race(sources);
    }
  }

  /// 新浪 K 线 API
  Future<List<KlineData>> _getKlineFromSina(String code, String period, int count) async {
    final scale = _periodToScale(period);
    final url = 'https://money.finance.sina.com.cn/quotes_service/api/json_v2.php'
        '/CN_MarketData.getKLineData?symbol=$code&scale=$scale&ma=5&datalen=$count';

    final response = await _dio.get(url);
    final body = response.data is String ? response.data as String : response.data.toString();

    // 新浪返回非标准 JSON：{day: 2025-07-17, open: 1413.980, ...}
    // key 无引号，日期值无引号，数值无引号 — 无法用 json.decode
    return _parseSinaKline(body);
  }

  /// 手动解析新浪 K 线数据（非标准 JSON）
  List<KlineData> _parseSinaKline(String body) {
    final results = <KlineData>[];

    // 匹配每个对象: {day: 2025-07-17, open: 1413.980, ...}
    final objPattern = RegExp(r'\{[^}]+\}');
    final objects = objPattern.allMatches(body);

    for (final objMatch in objects) {
      final objStr = objMatch.group(0)!;

      String? day;
      double? open, close, high, low;
      double volume = 0;

      // 提取各字段
      final dayMatch = RegExp(r'day:\s*([\d-]+)').firstMatch(objStr);
      if (dayMatch != null) day = dayMatch.group(1);

      final openMatch = RegExp(r'open:\s*([\d.]+)').firstMatch(objStr);
      if (openMatch != null) open = double.tryParse(openMatch.group(1)!);

      final closeMatch = RegExp(r'close:\s*([\d.]+)').firstMatch(objStr);
      if (closeMatch != null) close = double.tryParse(closeMatch.group(1)!);

      final highMatch = RegExp(r'high:\s*([\d.]+)').firstMatch(objStr);
      if (highMatch != null) high = double.tryParse(highMatch.group(1)!);

      final lowMatch = RegExp(r'low:\s*([\d.]+)').firstMatch(objStr);
      if (lowMatch != null) low = double.tryParse(lowMatch.group(1)!);

      final volMatch = RegExp(r'volume:\s*([\d.]+)').firstMatch(objStr);
      if (volMatch != null) volume = double.tryParse(volMatch.group(1)!) ?? 0;

      if (day != null && open != null && close != null && high != null && low != null) {
        results.add(KlineData(
          time: DateTime.parse(day),
          open: open,
          close: close,
          high: high,
          low: low,
          volume: volume,
        ));
      }
    }

    if (results.isEmpty) throw ParseException('新浪数据解析失败');
    return results;
  }

  /// 腾讯 K 线 API
  Future<List<KlineData>> _getKlineFromTencent(String code, String period, int count) async {
    final unit = _periodToUnit(period);
    final formatted = StockCodeUtils.format(code);
    final url = 'https://ifzq.gtimg.cn/appstock/app/kline/mkline?param=$formatted,$unit,,$count';

    final response = await _dio.get(url);
    final raw = response.data is String
        ? json.decode(response.data as String)
        : response.data;

    if (raw is! Map) throw ParseException('腾讯K线响应格式错误');

    final dataMap = raw['data'];
    if (dataMap is! Map) throw ParseException('腾讯K线data字段缺失');

    final klineData = dataMap[formatted];
    if (klineData is! Map) throw ParseException('腾讯K线股票数据为空: $formatted');

    // 尝试多种键名: day, week, month, m1, m5, m15, m30, m60
    final rows = klineData[unit] ?? klineData['m${unit.replaceAll('m', '')}'];
    if (rows == null || rows is! List || rows.isEmpty) {
      throw ParseException('腾讯K线数据格式错误: unit=$unit, keys=${klineData.keys.toList()}');
    }

    return rows.map((row) {
      if (row is! List || row.length < 6) return null;
      try {
        return KlineData(
          time: _parseTime(row[0].toString()),
          open: double.parse(row[1].toString()),
          close: double.parse(row[2].toString()),
          high: double.parse(row[3].toString()),
          low: double.parse(row[4].toString()),
          volume: double.parse(row[5].toString()),
        );
      } catch (_) {
        return null;
      }
    }).whereType<KlineData>().toList();
  }

  // ──────────── 并行竞速 ────────────

  /// 并行发起所有请求，返回第一个成功的结果；全部失败则抛异常
  Future<T> _race<T>(List<_Source<T>> sources) async {
    final errors = <String>[];

    // 包装每个 Future，捕获异常返回 null
    final futures = sources.map((s) async {
      try {
        return await s.future;
      } catch (e) {
        errors.add('${s.name}: $e');
        return null;
      }
    }).toList();

    // 等待第一个成功的
    final completer = Completer<T>();
    var remaining = futures.length;

    for (final future in futures) {
      future.then((result) {
        if (result != null && !completer.isCompleted) {
          completer.complete(result);
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.completeError(NetworkException(
            '所有数据源均失败: ${errors.join('; ')}',
            source: 'MarketApi._race',
          ));
        }
      });
    }

    return completer.future;
  }

  DateTime _parseTime(String timeStr) {
    if (timeStr.contains('-')) return DateTime.parse(timeStr);
    if (timeStr.length == 12) {
      return DateTime(
        int.parse(timeStr.substring(0, 4)),
        int.parse(timeStr.substring(4, 6)),
        int.parse(timeStr.substring(6, 8)),
        int.parse(timeStr.substring(8, 10)),
        int.parse(timeStr.substring(10, 12)),
      );
    }
    if (timeStr.length == 8) {
      return DateTime(
        int.parse(timeStr.substring(0, 4)),
        int.parse(timeStr.substring(4, 6)),
        int.parse(timeStr.substring(6, 8)),
      );
    }
    return DateTime.parse(timeStr);
  }

  String _periodToUnit(String period) {
    switch (period) {
      case '1m': return 'm1';
      case '5m': return 'm5';
      case '15m': return 'm15';
      case '30m': return 'm30';
      case '60m': return 'm60';
      case 'week': return 'week';
      case 'month': return 'month';
      default: return 'day';
    }
  }

  String _periodToScale(String period) {
    switch (period) {
      case 'week': return '1200';
      case 'month': return '7200';
      default: return '240';
    }
  }
}

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  final int maxRetries;

  RetryInterceptor({this.maxRetries = 2});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retryCount'] ?? 0) as int;

    if (retryCount < maxRetries && _shouldRetry(err)) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;

      // 指数退避: 500ms, 1000ms
      await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));

      try {
        final dio = Dio();
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {}
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}

/// 数据源包装：名称 + 异步 Future
class _Source<T> {
  final String name;
  final Future<T> future;
  _Source(this.name, this.future);
}
