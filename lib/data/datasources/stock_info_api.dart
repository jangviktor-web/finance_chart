import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/stock_info_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';

/// 个股深度数据 API — 东方财富（带降级）
class StockInfoApi {
  final Dio _dio;

  StockInfoApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://data.eastmoney.com/',
          },
        ));

  /// 股东人数变化 — 多报表名降级
  Future<List<ShareholderData>> getShareholders(String code, {int limit = 10}) async {
    final secCode = code.replaceAll(RegExp(r'^(sh|sz)'), '');

    // 尝试多个可能的报表名
    final reportNames = [
      'RPT_F10_EH_HOLDERSNUM',
      'RPT_F10_SHAREHOLDERNUM',
      'RPT_F10_EH_FREEHOLDERSNUM',
      'RPTA_WEB_SHAREHOLDERNUM',
    ];

    for (final reportName in reportNames) {
      try {
        final params = {
          'sortColumns': 'END_DATE',
          'sortTypes': '-1',
          'pageSize': '$limit',
          'pageNumber': '1',
          'reportName': reportName,
          'columns': 'ALL',
          'source': 'WEB',
          'client': 'WEB',
          'filter': '(SECURITY_CODE=\'$secCode\')',
        };
        final response = await _dio.get(ApiEndpoints.shareholders, queryParameters: params);
        final data = response.data is String ? json.decode(response.data) : response.data;

        if (data['result'] == null) continue;
        final rows = data['result']['data'] as List? ?? [];
        if (rows.isEmpty) continue;

        return rows.map((item) => ShareholderData(
          date: _formatDate(item['END_DATE'] ?? item['REPORT_DATE']),
          holderCount: _toInt(item['HOLDER_NUM'] ?? item['HOLDERNUM']),
          avgAmount: _toDouble(item['AVG_FREE_SHARES']),
          changePercent: _toDouble(item['HOLDER_NUM_CHANGE_RATE'] ?? item['CHANGE_RATE']),
        )).toList();
      } catch (_) {
        continue;
      }
    }

    AppLog.instance.error('StockInfoApi', 'getShareholders 所有报表名均失败: $secCode');
    return [];
  }

  /// 估值数据 — push2 stock/get API
  Future<ValuationData> getValuation(String code) async {
    final secCode = code.replaceAll(RegExp(r'^(sh|sz)'), '');
    final secid = code.startsWith('sh') ? '$secCode.SH' : '$secCode.SZ';

    try {
      final url = '${ApiEndpoints.eastmoneyPush}/api/qt/stock/get';
      final params = {
        'secid': secid,
        'fields': 'f57,f58,f116,f117,f162,f163,f164,f167,f173,f183,f186,f187',
        'invt': '2',
      };
      final response = await _dio.get(url, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;
      final d = data['data'];
      if (d != null && d is Map) {
        return ValuationData(
          pe: _toDouble(d['f162']),
          pb: _toDouble(d['f167']),
          ps: _toDouble(d['f163']),
          pcf: _toDouble(d['f164']),
          totalMarketCap: _toDouble(d['f116']) / 100000000,
          circulatingCap: _toDouble(d['f117']) / 100000000,
          dividendYield: _toDouble(d['f173']),
        );
      }
    } catch (_) {}

    // 降级: 用行情接口获取基本估值
    try {
      final quoteUrl = 'https://qt.gtimg.cn/q=$code';
      final response = await _dio.get(quoteUrl);
      final body = response.data is String ? response.data as String : '';
      // 腾讯行情格式: v_sh600519="1~贵州茅台~600519~..."
      final match = RegExp(r'"(.+?)"').firstMatch(body);
      if (match != null) {
        final fields = match.group(1)!.split('~');
        if (fields.length > 45) {
          return ValuationData(
            pe: _toDouble(fields[39]), // 市盈率
            pb: _toDouble(fields[46]), // 市净率
            totalMarketCap: _toDouble(fields[45]) / 100000000, // 总市值(万)→亿
          );
        }
      }
    } catch (_) {}

    return const ValuationData();
  }

  /// 大宗交易 — 多报表名降级
  Future<List<BlockTrade>> getBlockTrades(String code, {int limit = 20}) async {
    final secCode = code.replaceAll(RegExp(r'^(sh|sz)'), '');

    final reportNames = [
      'RPT_BLOCKTRADE_DETAILNEW',
      'RPT_BLOCKTRADE_DETAIL',
      'RPT_BLOCKTRADE_DAILY',
      'RPTA_WEB_BLOCKTRADE',
    ];

    for (final reportName in reportNames) {
      try {
        final params = {
          'sortColumns': 'TURNOVER_DATE',
          'sortTypes': '-1',
          'pageSize': '$limit',
          'pageNumber': '1',
          'reportName': reportName,
          'columns': 'ALL',
          'source': 'WEB',
          'client': 'WEB',
          'filter': '(SECURITY_CODE=\'$secCode\')',
        };
        final response = await _dio.get(ApiEndpoints.blockTrades, queryParameters: params);
        final data = response.data is String ? json.decode(response.data) : response.data;

        if (data['result'] == null) continue;
        final rows = data['result']['data'] as List? ?? [];
        if (rows.isEmpty) continue;

        return rows.map((item) => BlockTrade(
          date: DateTime.tryParse(item['TURNOVER_DATE']?.toString() ?? item['TRADE_DATE']?.toString() ?? '') ?? DateTime.now(),
          price: _toDouble(item['DEAL_PRICE'] ?? item['PRICE']),
          volume: _toDouble(item['DEAL_VOLUME'] ?? item['VOLUME']) / 10000,
          amount: _toDouble(item['DEAL_AMOUNT'] ?? item['AMOUNT']) / 10000,
          premiumRate: _toDouble(item['PREMIUM_RATIO'] ?? item['PREMIUM_RATE']),
          buyer: item['BUYER_NAME']?.toString() ?? '',
          seller: item['SELLER_NAME']?.toString() ?? '',
        )).toList();
      } catch (_) {
        continue;
      }
    }

    AppLog.instance.error('StockInfoApi', 'getBlockTrades 所有报表名均失败: $secCode');
    return [];
  }

  /// 限售解禁 — RPT_LIFT_STAGE 已验证可用
  Future<List<RestrictedShare>> getRestrictedShares(String code, {int limit = 10}) async {
    final secCode = code.replaceAll(RegExp(r'^(sh|sz)'), '');
    final params = {
      'sortColumns': 'FREE_DATE',
      'sortTypes': '-1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': 'RPT_LIFT_STAGE',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(SECURITY_CODE=\'$secCode\')',
    };

    try {
      final response = await _dio.get(ApiEndpoints.restrictedShares, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => RestrictedShare(
        date: DateTime.tryParse(item['FREE_DATE']?.toString() ?? '') ?? DateTime.now(),
        amount: _toDouble(item['FREE_MARKET_CAP']) / 100000000,
        volume: _toDouble(item['FREE_SHARES']) / 10000,
        type: item['FREE_TYPE']?.toString() ?? '',
      )).toList();
    } catch (e) {
      AppLog.instance.error('StockInfoApi', 'getRestrictedShares 失败: $e');
      return [];
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    final s = dateStr.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
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

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
