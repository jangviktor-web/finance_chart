import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/sentiment_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';

/// 市场情绪 API — 多数据源降级
class SentimentApi {
  final Dio _dio;

  SentimentApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://quote.eastmoney.com/',
            'Accept': 'application/json, text/plain, */*',
          },
        ));

  /// 带重试 + 域名降级的 push 请求
  /// 主域名 push2 → 备用域名 push3，每个域名最多重试 maxRetries 次
  Future<Response> _push2Retry(String url, Map<String, dynamic> params, {int maxRetries = 2}) async {
    // 全局频率控制
    await RateLimiter.instance.waitByUrl(url);

    // 构建域名列表：push2 → push3
    final fallbackUrl = url.replaceFirst('push2.eastmoney.com', 'push3.eastmoney.com');
    final hosts = [url, if (fallbackUrl != url) fallbackUrl];

    for (final hostUrl in hosts) {
      for (int i = 0; i < maxRetries; i++) {
        try {
          final response = await _dio.get(hostUrl, queryParameters: params);
          RateLimiter.instance.recordSuccess(_extractDomain(hostUrl));
          return response;
        } catch (e) {
          final domain = _extractDomain(hostUrl);
          RateLimiter.instance.recordFailure(domain);
          AppLog.instance.warn('SentimentApi', '$domain 请求第${i + 1}次失败: $e');
          if (i < maxRetries - 1) {
            await Future.delayed(Duration(seconds: 1 << i));
          }
        }
      }
    }
    throw Exception('push2/push3 所有请求均失败');
  }

  String _extractDomain(String url) {
    try { return Uri.parse(url).host; } catch (_) { return 'unknown'; }
  }

  /// 涨停池 — 通过 push2 clist API 筛选涨幅>=9.8%的股票
  Future<List<LimitStock>> getLimitUpPool({int limit = 80}) async {
    final params = {
      'pn': '1',
      'pz': '$limit',
      'po': '1',
      'np': '1',
      'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
      'fltt': '2',
      'invt': '2',
      'fid': 'f3',
      'fs': 'm:0+t:6+f:!50,m:0+t:80+f:!50,m:1+t:2+f:!50,m:1+t:23+f:!50',
      'fields': 'f2,f3,f5,f6,f12,f13,f14,f15,f16,f17',
    };

    try {
      final response = await _push2Retry(ApiEndpoints.sectorFlow, params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['data'] == null) return [];
      final rows = (data['data']['diff'] as List?) ?? [];

      return rows
          .map((item) {
            final code = (item['f12'] ?? '').toString();
            final changePercent = _toDouble(item['f3']);
            if (changePercent < 9.8) return null;

            final market = _getMarketPrefix(item);
            return LimitStock(
              code: '$market$code',
              name: item['f14']?.toString() ?? '',
              price: _toDouble(item['f2']),
              changePercent: changePercent,
              amount: _toDouble(item['f6']),
              limitType: '涨停',
              openCount: 0,
            );
          })
          .where((item) => item != null)
          .cast<LimitStock>()
          .toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getLimitUpPool 失败: $e');
      return [];
    }
  }

  /// 跌停池 — 通过 push2 clist API 筛选跌幅<=-9.8%的股票
  Future<List<LimitStock>> getLimitDownPool({int limit = 80}) async {
    final params = {
      'pn': '1',
      'pz': '$limit',
      'po': '0',
      'np': '1',
      'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
      'fltt': '2',
      'invt': '2',
      'fid': 'f3',
      'fs': 'm:0+t:6+f:!50,m:0+t:80+f:!50,m:1+t:2+f:!50,m:1+t:23+f:!50',
      'fields': 'f2,f3,f5,f6,f12,f13,f14,f15,f16,f17',
    };

    try {
      final response = await _push2Retry(ApiEndpoints.sectorFlow, params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['data'] == null) return [];
      final rows = (data['data']['diff'] as List?) ?? [];

      return rows
          .map((item) {
            final code = (item['f12'] ?? '').toString();
            final changePercent = _toDouble(item['f3']);
            if (changePercent > -9.8) return null;

            final market = _getMarketPrefix(item);
            return LimitStock(
              code: '$market$code',
              name: item['f14']?.toString() ?? '',
              price: _toDouble(item['f2']),
              changePercent: changePercent,
              amount: _toDouble(item['f6']),
              limitType: '跌停',
              openCount: 0,
            );
          })
          .where((item) => item != null)
          .cast<LimitStock>()
          .toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getLimitDownPool 失败: $e');
      return [];
    }
  }

  /// 龙虎榜
  Future<List<DragonTigerItem>> getDragonTiger({int days = 5, int limit = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final params = {
      'sortColumns': 'TRADE_DATE,SECURITY_CODE',
      'sortTypes': '-1,1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': 'RPT_DAILYBILLBOARD_DETAILSNEW',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(TRADE_DATE>=\'$start\')(TRADE_DATE<=\'$end\')',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.dragonTiger);
      final response = await _dio.get(ApiEndpoints.dragonTiger, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) {
        final code = (item['SECURITY_CODE'] ?? '').toString();
        final market = code.startsWith('6') ? 'sh' : 'sz';
        return DragonTigerItem(
          code: '$market$code',
          name: item['SECURITY_NAME_ABBR']?.toString() ?? '',
          changePercent: _toDouble(item['CHANGE_RATE']),
          closePrice: _toDouble(item['CLOSE_PRICE']),
          turnoverRate: _toDouble(item['TURNOVERRATE']),
          netBuy: _toDouble(item['BILLBOARD_NET_AMT']) / 10000, // 元→万元
          totalBuy: _toDouble(item['BILLBOARD_BUY_AMT']) / 10000,
          totalSell: _toDouble(item['BILLBOARD_SELL_AMT']) / 10000,
          reason: item['EXPLANATION']?.toString() ?? '',
          date: DateTime.tryParse(item['TRADE_DATE']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getDragonTiger 失败: $e');
      return [];
    }
  }

  /// 北向资金实时（多参数降级）
  Future<List<NorthboundData>> getNorthboundRealtime() async {
    final paramSets = [
      {
        'fields1': 'f1,f2,f3,f4',
        'fields2': 'f51,f52,f53,f54,f55,f56',
        'ut': 'b2884a393a59ad64002292a3e90d46a5',
      },
      {
        'fields1': 'f1,f2,f3,f4',
        'fields2': 'f51,f52,f53,f54,f55,f56',
      },
    ];

    for (final params in paramSets) {
      try {
        await RateLimiter.instance.waitByUrl(ApiEndpoints.northbound);
        final response = await _dio.get(ApiEndpoints.northbound, queryParameters: params);
        final data = response.data is String ? json.decode(response.data) : response.data;

        final List<NorthboundData> result = [];
        final s2n = data['s2n'] as List? ?? [];
        for (final item in s2n) {
          if (item is List && item.length >= 3) {
            final timeStr = item[0]?.toString() ?? '';
            final netBuy = _toDouble(item[1]);
            if (timeStr.isNotEmpty) {
              final parts = timeStr.split(':');
              if (parts.length >= 2) {
                final now = DateTime.now();
                result.add(NorthboundData(
                  time: DateTime(now.year, now.month, now.day,
                      int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0),
                  netBuy: netBuy / 10000,
                ));
              }
            }
          }
        }
        if (result.isNotEmpty) return result;
      } catch (_) {
        continue;
      }
    }

    // 降级：用历史数据最新一天
    try {
      final history = await getNorthboundHistory(days: 3);
      if (history.isNotEmpty) {
        final latest = history.first;
        return [NorthboundData(time: latest.date, netBuy: latest.totalNet)];
      }
    } catch (_) {}

    return [];
  }

  /// 北向资金历史 — 按日期聚合沪股通(002)+深股通(006)
  Future<List<NorthboundHistory>> getNorthboundHistory({int days = 30}) async {
    final params = {
      'sortColumns': 'TRADE_DATE',
      'sortTypes': '-1',
      'pageSize': '${days * 6}', // 每天最多6条(不同MUTUAL_TYPE)
      'pageNumber': '1',
      'reportName': 'RPT_MUTUAL_DEAL_HISTORY',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.northboundHistory);
      final response = await _dio.get(ApiEndpoints.northboundHistory, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      // 按日期聚合：同一天可能有 001-006 多条记录
      final Map<String, Map<String, double>> byDate = {};
      for (final item in rows) {
        final dateStr = item['TRADE_DATE']?.toString() ?? '';
        if (dateStr.isEmpty) continue;
        final dateKey = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
        final type = item['MUTUAL_TYPE']?.toString() ?? '';
        final netAmt = _toDouble(item['NET_DEAL_AMT']); // 已经是亿元

        byDate[dateKey] ??= {'sh': 0, 'sz': 0, 'total': 0};
        if (type == '002') {
          byDate[dateKey]!['sh'] = netAmt;
        } else if (type == '006') {
          byDate[dateKey]!['sz'] = netAmt;
        } else if (type == '004') {
          byDate[dateKey]!['total'] = netAmt;
        }
      }

      return byDate.entries.map((e) {
        final sh = e.value['sh']!;
        final sz = e.value['sz']!;
        final total = e.value['total']! != 0 ? e.value['total']! : sh + sz;
        return NorthboundHistory(
          date: DateTime.tryParse(e.key) ?? DateTime.now(),
          shNet: sh,
          szNet: sz,
          totalNet: total,
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getNorthboundHistory 失败: $e');
      return [];
    }
  }

  /// 融资融券
  Future<List<MarginData>> getMargin({int days = 30}) async {
    final params = {
      'sortColumns': 'DATE',
      'sortTypes': '-1',
      'pageSize': '$days',
      'pageNumber': '1',
      'reportName': 'RPTA_WEB_RZRQ_GGMX',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.margin);
      final response = await _dio.get(ApiEndpoints.margin, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => MarginData(
        date: DateTime.tryParse(item['DATE']?.toString() ?? '') ?? DateTime.now(),
        rzBalance: _toDouble(item['RZYE']) / 100000000,
        rzBuy: _toDouble(item['RZMRE'] ?? item['RZ_MRE']) / 100000000,
        rqBalance: _toDouble(item['RQYE']) / 100000000,
      )).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getMargin 失败: $e');
      return [];
    }
  }

  /// 板块资金流向（多参数降级）
  Future<List<SectorFlowData>> getSectorFlow({int limit = 20}) async {
    final paramSets = [
      {
        'pn': '1', 'pz': '$limit', 'po': '1', 'np': '1',
        'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
        'fltt': '2', 'invt': '2', 'fid': 'f62',
        'fs': 'm:90+t:2+f:!50',
        'fields': 'f12,f14,f2,f3,f62,f184,f66,f69',
      },
      {
        'pn': '1', 'pz': '$limit', 'po': '1', 'np': '1',
        'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
        'fltt': '2', 'invt': '2', 'fid': 'f62',
        'fs': 'm:90+t:3+f:!50',
        'fields': 'f12,f14,f2,f3,f62,f184,f66,f69',
      },
      {
        'pn': '1', 'pz': '$limit', 'po': '1', 'np': '1',
        'fltt': '2', 'invt': '2', 'fid': 'f62',
        'fs': 'm:90+t:2+f:!50',
        'fields': 'f12,f14,f2,f3,f62,f184,f66,f69',
      },
    ];

    for (final params in paramSets) {
      try {
        final response = await _push2Retry(ApiEndpoints.sectorFlow, params);
        final data = response.data is String ? json.decode(response.data) : response.data;

        if (data['data'] != null) {
          final rows = (data['data']['diff'] as List?) ?? [];
          if (rows.isNotEmpty) {
            return rows.map((item) => SectorFlowData(
              name: item['f14']?.toString() ?? '',
              changePercent: _toDouble(item['f3']),
              netInflow: _toDouble(item['f62']) / 100000000,
              mainInflow: _toDouble(item['f66']) / 100000000,
            )).toList();
          }
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// 热门板块 — 按涨跌幅排序，返回板块名/涨跌幅/涨跌家数/领涨股/BK代码
  Future<List<Map<String, dynamic>>> getHotSectors({int limit = 8}) async {
    // 先尝试行业板块，失败再尝试概念板块
    final fsList = ['m:90+t:2+f:!50', 'm:90+t:3+f:!50'];

    for (final fs in fsList) {
      try {
        final response = await _push2Retry(ApiEndpoints.sectorFlow, {
          'pn': '1', 'pz': '$limit', 'po': '1', 'np': '1',
          'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
          'fltt': '2', 'invt': '2', 'fid': 'f3',
          'fs': fs,
          'fields': 'f12,f14,f3,f104,f105,f128,f140',
        });

        final data = response.data is String ? json.decode(response.data) : response.data;
        if (data['data'] != null) {
          final rows = (data['data']['diff'] as List?) ?? [];
          if (rows.isNotEmpty) {
            return rows.take(limit).map((item) => {
              'name': item['f14']?.toString() ?? '',
              'changePercent': (item['f3'] ?? 0).toDouble(),
              'upCount': (item['f104'] ?? 0).toInt(),
              'downCount': (item['f105'] ?? 0).toInt(),
              'leader': item['f128']?.toString() ?? '',
              'bkCode': item['f12']?.toString() ?? '',
            }).toList();
          }
        }
      } catch (e) {
        AppLog.instance.info('SentimentApi', 'getHotSectors fs=$fs 失败: $e');
        continue;
      }
    }
    return [];
  }

  /// 根据 f13 字段判断市场前缀（0=深圳, 1=上海）
  String _getMarketPrefix(Map<String, dynamic> item) {
    final market = item['f13'];
    if (market == 1) return 'sh';
    if (market == 0) return 'sz';
    final code = (item['f12'] ?? '').toString();
    return code.startsWith('6') ? 'sh' : 'sz';
  }

  // ──────────── 北向资金深度数据 ────────────

  /// 北向资金板块排名
  Future<List<NorthboundBoardRank>> getNorthboundBoardRank({int limit = 30}) async {
    final params = {
      'sortColumns': 'HOLD_MARKET_CAP',
      'sortTypes': '-1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': 'RPT_MUTUAL_BOARD_HOLDRANK_WEB',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.northboundHistory);
      final response = await _dio.get(ApiEndpoints.northboundHistory, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => NorthboundBoardRank(
        boardName: item['BOARD_NAME']?.toString() ?? '',
        boardCode: item['BOARD_CODE']?.toString() ?? '',
        holdMarketValue: _toDouble(item['HOLD_MARKET_CAP']),
        holdPercent: _toDouble(item['HOLD_SHARES_RATIO']),
        netBuy: _toDouble(item['NET_BUY_AMT']),
        changePercent: _toDouble(item['CHANGE_RATE']),
      )).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getNorthboundBoardRank 失败: $e');
      return [];
    }
  }

  /// 个股北向持仓历史
  Future<List<NorthboundStockHold>> getNorthboundStockHold(String code, {int days = 60}) async {
    final pureCode = code.replaceAll(RegExp(r'[^0-9]'), '');
    final params = {
      'sortColumns': 'TRADE_DATE',
      'sortTypes': '-1',
      'pageSize': '$days',
      'pageNumber': '1',
      'reportName': 'RPT_MUTUAL_HOLDSTOCKNDATE_STA',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(SECURITY_CODE="$pureCode")',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.northboundHistory);
      final response = await _dio.get(ApiEndpoints.northboundHistory, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => NorthboundStockHold(
        date: DateTime.tryParse(item['TRADE_DATE']?.toString() ?? '') ?? DateTime.now(),
        holdShares: _toDouble(item['HOLD_SHARES']),
        holdMarketValue: _toDouble(item['HOLD_MARKET_CAP']),
        holdPercent: _toDouble(item['A_SHARES_RATIO']),
        freePercent: _toDouble(item['FREE_SHARES_RATIO']),
      )).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getNorthboundStockHold 失败: $e');
      return [];
    }
  }

  // ──────────── 龙虎榜扩展 ────────────

  /// 龙虎榜个股上榜统计
  Future<List<DragonTigerStatItem>> getDragonTigerStats({int days = 90, int limit = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final params = {
      'sortColumns': 'TOTAL_TIMES',
      'sortTypes': '-1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': 'RPT_BILLBOARD_TRADEALL',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(TRADE_DATE>=\'$start\')(TRADE_DATE<=\'$end\')',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.dragonTiger);
      final response = await _dio.get(ApiEndpoints.dragonTiger, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) {
        final code = (item['SECURITY_CODE'] ?? '').toString();
        final market = code.startsWith('6') ? 'sh' : 'sz';
        return DragonTigerStatItem(
          code: '$market$code',
          name: item['SECURITY_NAME_ABBR']?.toString() ?? '',
          totalTimes: (item['TOTAL_TIMES'] as num?)?.toInt() ?? 0,
          recentTimes: (item['RECENT_TIMES'] as num?)?.toInt() ?? 0,
          totalNetBuy: _toDouble(item['BILLBOARD_NET_AMT']) / 10000,
          latestChange: _toDouble(item['CHANGE_RATE']),
        );
      }).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getDragonTigerStats 失败: $e');
      return [];
    }
  }

  /// 龙虎榜机构买卖每日统计
  Future<List<DragonTigerOrgItem>> getDragonTigerOrgTrade({int days = 5}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final params = {
      'sortColumns': 'TRADE_DATE,NET_BUY_AMT',
      'sortTypes': '-1,-1',
      'pageSize': '100',
      'pageNumber': '1',
      'reportName': 'RPT_ORGANIZATION_TRADE_DETAILS',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(TRADE_DATE>=\'$start\')(TRADE_DATE<=\'$end\')',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.dragonTiger);
      final response = await _dio.get(ApiEndpoints.dragonTiger, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => DragonTigerOrgItem(
        orgName: item['OPERATEDEPT_NAME']?.toString() ?? item['ORG_NAME']?.toString() ?? '',
        buyAmount: _toDouble(item['BUY_AMT']) / 10000,
        sellAmount: _toDouble(item['SELL_AMT']) / 10000,
        netAmount: _toDouble(item['NET_BUY_AMT']) / 10000,
        buyPercent: _toDouble(item['BUY_AMT_RATIO']),
        sellPercent: _toDouble(item['SELL_AMT_RATIO']),
      )).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getDragonTigerOrgTrade 失败: $e');
      return [];
    }
  }

  /// 龙虎榜活跃营业部排行
  Future<List<DragonTigerOrgItem>> getDragonTigerDeptRank({int days = 30, int limit = 20}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final params = {
      'sortColumns': 'TOTAL_BUYAMT',
      'sortTypes': '-1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': 'RPT_RATEDEPT_RETURNT_RANKING',
      'columns': 'ALL',
      'source': 'WEB',
      'client': 'WEB',
      'filter': '(TRADE_DATE>=\'$start\')(TRADE_DATE<=\'$end\')',
    };

    try {
      await RateLimiter.instance.waitByUrl(ApiEndpoints.dragonTiger);
      final response = await _dio.get(ApiEndpoints.dragonTiger, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] == null) return [];
      final rows = data['result']['data'] as List? ?? [];

      return rows.map((item) => DragonTigerOrgItem(
        orgName: item['OPERATEDEPT_NAME']?.toString() ?? '',
        buyAmount: _toDouble(item['TOTAL_BUYAMT']) / 10000,
        sellAmount: _toDouble(item['TOTAL_SELLAMT']) / 10000,
        netAmount: _toDouble(item['TOTAL_NETAMT']) / 10000,
        buyPercent: _toDouble(item['BUY_RATIO']),
        sellPercent: _toDouble(item['SELL_RATIO']),
      )).toList();
    } catch (e) {
      AppLog.instance.error('SentimentApi', 'getDragonTigerDeptRank 失败: $e');
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
