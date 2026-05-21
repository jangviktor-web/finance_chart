import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/kline_data.dart';
import '../models/realtime_quote.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/stock_code_utils.dart';

/// 百度财经 API 数据源
/// 无认证，纯 HTTP 请求
class BaiduApi {
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': 'https://gushitong.baidu.com/',
  };

  final Dio _dio;

  BaiduApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: _headers,
        ));

  /// 获取实时行情
  Future<RealtimeQuote> getRealtime(String code) async {
    final pureCode = StockCodeUtils.pureCode(code);
    final url = 'https://finance.pae.baidu.com/selfselect/getstockquotation'
        '?code=$pureCode&market=ab&is498=1&isBk=false&isBlock=false'
        '&isFutures=false&isStock=true&newFormat=1';

    try {
      final response = await _dio.get(url);
      final data = response.data is String ? json.decode(response.data) : response.data;

      final result = data['Result'] ?? data['result'] ?? [];
      if (result.isEmpty) {
        throw Exception('百度实时行情: 无数据');
      }

      final item = result[0];
      final formatted = StockCodeUtils.format(code);

      return RealtimeQuote(
        code: formatted.toUpperCase(),
        name: item['name']?.toString() ?? '',
        now: _toDouble(item['currentPrice'] ?? item['price']),
        yesterday: _toDouble(item['preClose']),
        high: _toDouble(item['high']),
        low: _toDouble(item['low']),
        volume: _toDouble(item['volume']),
        amount: _toDouble(item['amount']),
        time: DateTime.now(),
      );
    } catch (e) {
      AppLog.instance.error('BaiduApi', 'getRealtime 失败: $e');
      rethrow;
    }
  }

  /// 获取 K 线数据
  Future<List<KlineData>> getKline({
    required String code,
    int count = 100,
    int fqtype = 1, // 1=前复权, 2=后复权, 3=不复权
  }) async {
    final pureCode = StockCodeUtils.pureCode(code);
    final url = 'https://finance.pae.baidu.com/selfselect/getstockquotation'
        '?code=$pureCode&market=ab&is498=1&isBk=false&isBlock=false'
        '&isFutures=false&isStock=true&newFormat=1&count=$count&fqtype=$fqtype';

    try {
      final response = await _dio.get(url);
      final data = response.data is String ? json.decode(response.data) : response.data;

      final result = data['Result'] ?? data['result'] ?? [];
      if (result.isEmpty) {
        throw Exception('百度K线: 无数据');
      }

      final List<KlineData> klines = [];
      for (final item in result) {
        final dateStr = item['date']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();

        klines.add(KlineData(
          time: date,
          open: _toDouble(item['open']),
          close: _toDouble(item['close']),
          high: _toDouble(item['high']),
          low: _toDouble(item['low']),
          volume: _toDouble(item['volume']),
        ));
      }

      return klines;
    } catch (e) {
      AppLog.instance.error('BaiduApi', 'getKline 失败: $e');
      rethrow;
    }
  }

  /// 获取概念板块
  Future<List<Map<String, dynamic>>> getConcepts() async {
    final url = 'https://finance.pae.baidu.com/vapi/v1/getquotation'
        '?srcid=5353&all=1&pointType=string&group=quotation_kline_ab'
        '&query=概念板块&code=concept&market=ab&finClientType=pc';

    try {
      final response = await _dio.get(url);
      final data = response.data is String ? json.decode(response.data) : response.data;

      final result = data['Result'] ?? data['result'] ?? [];
      if (result is! List) return [];

      return result.map<Map<String, dynamic>>((item) => {
        'name': item['name']?.toString() ?? '',
        'code': item['code']?.toString() ?? '',
        'changePercent': _toDouble(item['changePercent'] ?? item['chg']),
      }).toList();
    } catch (e) {
      AppLog.instance.error('BaiduApi', 'getConcepts 失败: $e');
      return [];
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v == '-' || v == '' || v == '--' || v == 'N/A') return 0;
      return double.tryParse(v) ?? 0;
    }
    return 0;
  }
}
