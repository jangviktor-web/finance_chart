import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/utils/stock_code_utils.dart';

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

        String formattedCode;
        if (marketNum == '1') {
          formattedCode = 'sh$code';
        } else if (marketNum == '0') {
          formattedCode = 'sz$code';
        } else {
          formattedCode = StockCodeUtils.format(code);
        }

        return SearchResult(code: formattedCode, name: name);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
