import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/sentiment_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';
import '../../core/utils/stock_code_utils.dart';

/// 资金流向 API — 个股/大盘/排行
class FundFlowApi {
  final Dio _dio;

  FundFlowApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://quote.eastmoney.com/',
          },
        ));

  /// 个股资金流向历史（日线）
  /// 返回最近 [days] 天的主力/大单/中单/小单/超大单净流入
  Future<List<FundFlowDetail>> getStockFundFlow(String code, {int days = 30}) async {
    await RateLimiter.instance.wait('push2his.eastmoney.com');

    final secid = StockCodeUtils.toSecId(code);
    final params = {
      'lmt': '0',
      'klt': '101',
      'secid': secid,
      'fields1': 'f1,f2,f3,f7',
      'fields2': 'f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61,f62,f63,f64,f65',
      'ut': 'b2884a393a59ad64002292a3e90d46a5',
    };

    try {
      final response = await _dio.get(ApiEndpoints.fundFlowKline, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['data'] == null) return [];
      final klines = data['data']['klines'] as List? ?? [];
      if (klines.isEmpty) return [];

      final results = <FundFlowDetail>[];
      for (final line in klines) {
        final fields = line.toString().split(',');
        if (fields.length < 13) continue;

        results.add(FundFlowDetail(
          date: DateTime.tryParse(fields[0]) ?? DateTime.now(),
          mainNet: _toDouble(fields[1]),
          smallNet: _toDouble(fields[2]),
          mediumNet: _toDouble(fields[3]),
          largeNet: _toDouble(fields[4]),
          superLargeNet: _toDouble(fields[5]),
          mainPercent: _toDouble(fields[6]),
          closePrice: _toDouble(fields[11]),
          changePercent: _toDouble(fields[12]),
        ));
      }

      // 只返回最近 N 天
      return results.length > days ? results.sublist(results.length - days) : results;
    } catch (e) {
      AppLog.instance.error('FundFlowApi', 'getStockFundFlow 失败: $e');
      return [];
    }
  }

  /// 大盘实时资金流快照（上证+深证）
  Future<MarketFundFlow> getMarketFundFlow() async {
    await RateLimiter.instance.wait('push2his.eastmoney.com');

    final params = {
      'fltt': '2',
      'secids': '1.000001,0.399001',
      'fields': 'f62,f184,f66,f69,f72,f75,f78,f81,f84,f87',
    };

    try {
      final response = await _dio.get(ApiEndpoints.marketFundFlow, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['data'] == null) return const MarketFundFlow();
      final diff = data['data']['diff'] as List? ?? [];
      if (diff.isEmpty) return const MarketFundFlow();

      // 合并上证+深证
      double mainNet = 0, superLarge = 0, large = 0, medium = 0, small = 0, mainPct = 0;
      for (final item in diff) {
        mainNet += _toDouble(item['f62']);
        superLarge += _toDouble(item['f66']);
        large += _toDouble(item['f72']);
        medium += _toDouble(item['f78']);
        small += _toDouble(item['f84']);
        mainPct += _toDouble(item['f184']);
      }

      return MarketFundFlow(
        mainNet: mainNet,
        superLargeNet: superLarge,
        largeNet: large,
        mediumNet: medium,
        smallNet: small,
        mainPercent: diff.isNotEmpty ? mainPct / diff.length : 0,
      );
    } catch (e) {
      AppLog.instance.error('FundFlowApi', 'getMarketFundFlow 失败: $e');
      return const MarketFundFlow();
    }
  }

  /// 全市场资金流排行榜
  /// [period] 今日/3日/5日/10日
  Future<List<FundFlowRankItem>> getFundFlowRank({
    String period = 'today',
    int limit = 50,
  }) async {
    await RateLimiter.instance.wait('push2his.eastmoney.com');

    final indicatorMap = {
      'today': {'fid': 'f62', 'fields': 'f12,f14,f2,f3,f62,f184,f66,f69,f72,f75,f78,f81,f84,f87'},
      '3day':  {'fid': 'f267', 'fields': 'f12,f14,f2,f3,f267,f164,f269,f270,f273,f274,f275,f276,f277,f278'},
      '5day':  {'fid': 'f164', 'fields': 'f12,f14,f2,f3,f164,f174,f165,f166,f169,f170,f171,f172,f173,f174'},
      '10day': {'fid': 'f174', 'fields': 'f12,f14,f2,f3,f174,f184,f165,f166,f169,f170,f171,f172,f173,f174'},
    };

    final indicator = indicatorMap[period] ?? indicatorMap['today']!;

    final params = {
      'pn': '1',
      'pz': '$limit',
      'po': '1',
      'np': '1',
      'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
      'fltt': '2',
      'invt': '2',
      'fid': indicator['fid']!,
      'fs': 'm:0+t:6+f:!50,m:0+t:80+f:!50,m:1+t:2+f:!50,m:1+t:23+f:!50',
      'fields': indicator['fields']!,
    };

    try {
      final response = await _dio.get(ApiEndpoints.fundFlowRank, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['data'] == null) return [];
      final rows = (data['data']['diff'] as List?) ?? [];

      return rows.map((item) {
        final code = (item['f12'] ?? '').toString();
        final market = item['f13'];
        String prefix = 'sz';
        if (market == 1) prefix = 'sh';
        else if (code.startsWith('6')) prefix = 'sh';

        return FundFlowRankItem(
          code: '$prefix$code',
          name: item['f14']?.toString() ?? '',
          price: _toDouble(item['f2']),
          changePercent: _toDouble(item['f3']),
          mainNet: _toDouble(item[indicator['fid']!.replaceFirst('f', 'f')]),
          mainPercent: _toDouble(item['f184'] ?? item['f164'] ?? item['f174']),
          superLargeNet: _toDouble(item['f66'] ?? item['f269'] ?? item['f165']),
          largeNet: _toDouble(item['f72'] ?? item['f273'] ?? item['f169']),
          mediumNet: _toDouble(item['f78'] ?? item['f275'] ?? item['f171']),
          smallNet: _toDouble(item['f84'] ?? item['f277'] ?? item['f173']),
        );
      }).toList();
    } catch (e) {
      AppLog.instance.error('FundFlowApi', 'getFundFlowRank 失败: $e');
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
