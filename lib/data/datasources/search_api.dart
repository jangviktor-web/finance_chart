import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/utils/rate_limiter.dart';

/// 搜索结果
class SearchResult {
  final String code;
  final String name;

  const SearchResult({required this.code, required this.name});
}

/// 股票搜索 API — 东方财富搜索接口
class SearchApi {
  final Dio _dio;

  SearchApi({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// 搜索股票
  Future<List<SearchResult>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    await RateLimiter.instance.wait('searchapi.eastmoney.com');
    try {
      final url = 'https://searchapi.eastmoney.com/api/suggest/get'
          '?input=${Uri.encodeComponent(keyword)}&type=14&count=10';

      final response = await _dio.get(url, options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ));

      final data = response.data is String
          ? json.decode(response.data as String)
          : response.data;

      final tableData = data['QuotationCodeTable'];
      if (tableData == null || tableData['Data'] == null) {
        return [];
      }

      return (tableData['Data'] as List).map((item) {
        final code = item['Code']?.toString() ?? '';
        final name = item['Name']?.toString() ?? '';
        final marketNum = item['MktNum']?.toString() ?? '';
        final quoteId = item['QuoteID']?.toString() ?? '';

        String formattedCode;
        if (marketNum == '1') {
          formattedCode = 'sh$code';
        } else if (marketNum == '0') {
          formattedCode = 'sz$code';
        } else if (quoteId.contains('.')) {
          // ponytail: 非沪深（港 116 / 美 105-107 / 京 / 板块）东财同一次响应里
          // 已直接给出 secid（QuoteID），用它即可，无需猜 —— 原实现退到
          // StockCodeUtils.format()，把港股 00700 拼成 sz00700，行情与K线全空。
          formattedCode = quoteId;
        } else {
          formattedCode = code;
        }

        return SearchResult(code: formattedCode, name: name);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
