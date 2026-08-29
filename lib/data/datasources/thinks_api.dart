import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/sentiment_data.dart';
import '../models/ths_extra_data.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';

/// 同花顺金融数据服务（HiThink Financial-API）REST 客户端（BYOK 直连模式）
///
/// 官方仓库：https://github.com/HiThink-Tech/Financial-API
/// 契约：Base URL = https://fuyao.aicubes.cn，认证 = HTTP Header `X-api-key: <用户自己的Key>`，
///       数据端点均为 GET，成功判定 = HTTP 200 且响应 `code == 0`，信封 `{code, message, request_id, data}`。
///
/// 合规要点（与东方财富妙想 Key 一致）：Key 仅来自用户设备安全存储，绝不硬编码、不代理转发、不上日志。
/// 用户按自己的同花顺套餐配额使用，超限由服务端返回 4001（退避重试）。
class ThinksApi {
  static const _baseUrl = 'https://fuyao.aicubes.cn';
  static const _authHeader = 'X-api-key';

  final Dio _dio;
  String _apiKey;

  ThinksApi({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? '',
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              responseType: ResponseType.json,
            ));

  /// 更新 API Key（用户自备的同花顺统一 Key）
  void updateApiKey(String key) => _apiKey = key;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// 通用 GET 请求，统一处理信封与错误码
  /// 返回 `{'ok': true, 'data': ...}` 或 `{'ok': false, 'error': '...'}`
  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> params) async {
    if (_apiKey.isEmpty) {
      return {'ok': false, 'error': '同花顺 API Key 未配置'};
    }

    await RateLimiter.instance.wait('fuyao.aicubes.cn');
    try {
      final response = await _dio.get(
        path,
        queryParameters: params,
        options: Options(headers: {_authHeader: _apiKey}),
      );

      final data = response.data is String ? json.decode(response.data) : response.data;
      if (data is! Map<String, dynamic>) {
        return {'ok': false, 'error': '响应格式异常'};
      }

      final code = data['code'];
      // 成功：HTTP 200 且 code == 0
      if (code == 0) {
        return {'ok': true, 'data': data['data']};
      }

      // 业务错误码映射
      final msg = data['message']?.toString() ?? '未知错误';
      if (code == 2001) return {'ok': false, 'error': '鉴权失败：请检查 Key 是否存在且格式正确'};
      if (code == 2003) return {'ok': false, 'error': 'Key 无效或无权限：请到 fuyao.aicubes.cn/admin 检查授权'};
      if (code == 4001) return {'ok': false, 'error': '请求过于频繁（限流），请稍后再试'};
      if (code == 3001) return {'ok': false, 'error': '标的不存在，请先用代码搜索消歧'};
      if (code != null && code >= 5000) return {'ok': false, 'error': '服务端异常（$msg），请稍后重试'};
      return {'ok': false, 'error': msg};
    } on DioException catch (e) {
      AppLog.instance.error('ThinksApi', '请求失败: ${e.type} ${e.message}');
      return {'ok': false, 'error': '网络错误：${e.message ?? e.type}'};
    } catch (e) {
      AppLog.instance.error('ThinksApi', '未知错误: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// 标的代码/名称搜索（消歧），返回 TickerItem 列表
  /// 例：searchTicker('600519') → 贵州茅台(600519.SH)
  /// [assetType] 资产类别过滤，逗号分隔：a-share / fund-otc / fund-etf / fund-lof / fund-reits
  Future<List<Map<String, dynamic>>> searchTicker(String query, {int limit = 5, String? assetType}) async {
    final params = <String, dynamic>{
      'q': query,
      'limit': limit,
    };
    if (assetType != null) params['asset_type'] = assetType;
    final res = await _get('/api/meta/tickers/search', params);
    if (!res['ok']) return [];
    final data = res['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map && data['item'] is List) {
      return (data['item'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// A 股最新行情快照（支持多标的中文逗号分隔），返回原始 data
  Future<Map<String, dynamic>> getSnapshot(List<String> thscodes) async {
    if (thscodes.isEmpty) return {'ok': false, 'error': '未提供标的代码'};
    return _get('/api/a-share/prices/snapshot', {
      'thscodes': thscodes.join(','),
    });
  }

  /// A 股历史 K 线（日线 1d），返回原始 data（{timestamp, item:[...]}）
  /// 注意：同花顺历史接口仅支持 interval=1d，start/end 为毫秒时间戳，窗口 ≤ 10 年
  Future<Map<String, dynamic>> getHistorical({
    required String thscode,
    required int startMs,
    required int endMs,
    String adjust = 'forward',
  }) async {
    return _get('/api/a-share/prices/historical', {
      'thscode': thscode,
      'interval': '1d',
      'start': startMs,
      'end': endMs,
      'adjust': adjust,
    });
  }

  /// A 股利润表（多期序列）
  /// period: 'annual' | 'quarterly'；limit 最近 N 期(1-20)；或传 startMs/endMs 区间
  Future<Map<String, dynamic>> getIncomeStatements({
    required String thscode,
    String period = 'annual',
    int limit = 4,
    int? startMs,
    int? endMs,
  }) async {
    final params = <String, dynamic>{
      'thscode': thscode,
      'period': period,
    };
    if (startMs != null && endMs != null) {
      params['start'] = startMs;
      params['end'] = endMs;
    } else {
      params['limit'] = limit;
    }
    return _get('/api/a-share/financials/income-statements', params);
  }

  /// A 股资产负债表（多期序列）
  Future<Map<String, dynamic>> getBalanceSheets({
    required String thscode,
    String period = 'annual',
    int limit = 4,
    int? startMs,
    int? endMs,
  }) async {
    final params = <String, dynamic>{
      'thscode': thscode,
      'period': period,
    };
    if (startMs != null && endMs != null) {
      params['start'] = startMs;
      params['end'] = endMs;
    } else {
      params['limit'] = limit;
    }
    return _get('/api/a-share/financials/balance-sheets', params);
  }

  /// A 股现金流量表（多期序列）
  Future<Map<String, dynamic>> getCashFlowStatements({
    required String thscode,
    String period = 'annual',
    int limit = 4,
    int? startMs,
    int? endMs,
  }) async {
    final params = <String, dynamic>{
      'thscode': thscode,
      'period': period,
    };
    if (startMs != null && endMs != null) {
      params['start'] = startMs;
      params['end'] = endMs;
    } else {
      params['limit'] = limit;
    }
    return _get('/api/a-share/financials/cash-flow-statements', params);
  }

  /// A 股财务指标（单报告期五类指标）
  /// report 格式 'YYYY-[1-4]'：1=一季报、2=中报、3=三季报、4=年报。例 '2024-4'。
  /// 返回 {thscode, report, abilities[]}，abilities 为五类指标数组。
  Future<Map<String, dynamic>> getIndicators({
    required String thscode,
    required String report,
  }) async {
    return _get('/api/a-share/financials/indicators', {
      'thscode': thscode,
      'report': report,
    });
  }

  // ──────────── 公募基金 ────────────

  /// 基金基本资料
  Future<Map<String, dynamic>> getFundProfile(String fundType, String thscode) async {
    return _get('/api/fund/profile/detail', {'fund_type': fundType, 'thscode': thscode});
  }

  /// 基金区间收益（固定区间：近一周~成立以来）
  Future<Map<String, dynamic>> getFundReturns(String fundType, String thscode) async {
    return _get('/api/fund/performance/returns', {'fund_type': fundType, 'thscode': thscode});
  }

  /// 基金最新净值 + 区间序列
  /// range: week/month/tmonth/hyear/year/twoyear/tyear/fyear；省略只返回最新点
  Future<Map<String, dynamic>> getFundNav(String fundType, String thscode, {String range = 'year'}) async {
    return _get('/api/fund/performance/nav', {
      'fund_type': fundType,
      'thscode': thscode,
      'range': range,
      'nav_type': 'unit,adj',
    });
  }

  /// 基金定期披露重仓股
  Future<Map<String, dynamic>> getFundHoldings(String fundType, String thscode) async {
    return _get('/api/fund/portfolio/holdings', {'fund_type': fundType, 'thscode': thscode});
  }

  /// A 股集合竞价快照（单只或多只，逗号分隔 thscode）
  /// stage: 'live' 竞价实时阶段 / 'final' 竞价终态（默认）
  /// 返回原始 data：{timestamp, auction_phase, data_status, total, item[]}
  Future<Map<String, dynamic>> getAuctionSnapshot(
    List<String> thscodes, {
    String stage = 'final',
  }) async {
    return _get('/api/a-share/auction/snapshot', {
      'thscodes': thscodes.join(','),
      'stage': stage,
    });
  }

  // ──────────── 特色数据（情绪类容灾源）────────────
  // 以下三个端点用于东财情绪数据被设备 IP 限流/失败时回退，
  // 返回 App 既有模型 LimitStock / DragonTigerItem，直接对接 sentiment_screen。

  /// 涨停池（同花顺容灾源）
  /// 字段：thscode(600519.SH), name, last_price, price_change_ratio_pct,
  ///       limit_up_time(HHMMSS), limit_up_reason, continue_day_cnt, seal_money
  Future<List<LimitStock>> getLimitUpPoolThs({int limit = 80}) async {
    final res = await _get('/api/a-share/special-data/limit-up-pool', {'limit': limit});
    if (!res['ok']) return [];
    final data = res['data'];
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return LimitStock(
        code: _thsCode(m['thscode'] ?? m['ticker']),
        name: _str(m['name']),
        price: _num(m['last_price']),
        changePercent: _num(m['price_change_ratio_pct']),
        limitType: '涨停',
        lastTime: _thsTime(_str(m['limit_up_time'])),
        flowAmount: _num(m['seal_money']),
      );
    }).toList();
  }

  /// 跌停池（同花顺容灾源）
  Future<List<LimitStock>> getLimitDownPoolThs({int limit = 80}) async {
    final res = await _get('/api/a-share/special-data/limit-down-pool', {'limit': limit});
    if (!res['ok']) return [];
    final data = res['data'];
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return LimitStock(
        code: _thsCode(m['thscode'] ?? m['ticker']),
        name: _str(m['name']),
        price: _num(m['last_price']),
        changePercent: _num(m['price_change_ratio_pct']),
        limitType: '跌停',
        firstTime: _thsTime(_str(m['first_limit_time'])),
        lastTime: _thsTime(_str(m['last_limit_time'])),
      );
    }).toList();
  }

  /// 龙虎榜（同花顺容灾源）
  /// [boardType] all/org/hot_money；[date] 可选 YYYY-MM-DD
  Future<List<DragonTigerItem>> getDragonTigerThs({String boardType = 'all', String? date}) async {
    final params = <String, dynamic>{'board_type': boardType};
    if (date != null) params['date'] = date;
    final res = await _get('/api/a-share/special-data/dragon-tiger-list', params);
    if (!res['ok']) return [];
    final data = res['data'];
    final items = (data is Map && data['stock_items'] is List)
        ? data['stock_items'] as List
        : const <dynamic>[];
    final tradeDate = _str(data is Map ? data['trade_date'] : '');
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return DragonTigerItem(
        code: _thsCode(m['thscode'] ?? m['ticker']),
        name: _str(m['name']),
        changePercent: _num(m['change']),
        closePrice: 0,
        netBuy: _num(m['net_value']) / 10000,
        totalBuy: _num(m['buy_value']) / 10000,
        totalSell: _num(m['sell_value']) / 10000,
        reason: _str(m['limit_reason']),
        date: _parseDate(tradeDate),
      );
    }).toList();
  }

  // ── THS 响应字段辅助 ──
  static String _thsCode(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty) return '';
    if (s.contains('.')) {
      final parts = s.split('.');
      final ticker = parts[0];
      final suffix = parts[1].toUpperCase();
      final market = suffix == 'SH' ? 'sh' : 'sz';
      return '$market$ticker';
    }
    return s.startsWith('6') ? 'sh$s' : 'sz$s';
  }

  static String _str(dynamic v) => v?.toString() ?? '';

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _thsTime(String s) {
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(digits) ?? 0;
  }

  static DateTime _parseDate(String s) {
    if (s.isEmpty) return DateTime.now();
    return DateTime.tryParse(s.replaceAll('/', '-')) ?? DateTime.now();
  }

  // ──────────── 特色数据（情绪 / 热度扩展）────────────

  /// 连板天梯（近 30 交易日梯队矩阵）
  Future<List<LadderDay>> getLimitUpLadder() async {
    final res = await _get('/api/a-share/special-data/limit-up-ladder', {});
    if (!res['ok']) return [];
    final data = res['data'];
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    const boardKeys = {
      'two_board': 2,
      'three_board': 3,
      'four_board': 4,
      'five_board': 5,
      'six_board': 6,
      'seven_over': 7,
    };
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      final date = _str(m['date']);
      final boards = m['boards'] is Map ? m['boards'] as Map : const <String, dynamic>{};
      final stocks = <LadderStock>[];
      boards.forEach((key, val) {
        if (val is List) {
          final fallbackNum = boardKeys[key] ?? 0;
          for (final s in val) {
            if (s is Map) {
              stocks.add(LadderStock(
                code: toAppCode(s['thscode'] ?? s['ticker']),
                name: _str(s['name']),
                boardNum: (s['board_num'] as num?)?.toInt() ?? fallbackNum,
                signLevel: _str(s['sign_level']),
                sealNextDay: s['seal_nextday']?.toString(),
              ));
            }
          }
        }
      });
      return LadderDay(date: date, stocks: stocks);
    }).toList();
  }

  /// 当日全市场个股异动原因（可选标签过滤，如 'LIMIT_UP,LIMIT_DOWN'）
  Future<List<AnomalyItem>> getAnomalyList({String? tagCodes}) async {
    final params = <String, dynamic>{};
    if (tagCodes != null && tagCodes.isNotEmpty) params['tag_codes'] = tagCodes;
    final res = await _get('/api/a-share/special-data/anomaly-analysis-list', params);
    if (!res['ok']) return [];
    return _parseAnomaly(res['data']);
  }

  /// 单股 / 批量异动原因（App 内部代码列表，自动转 thscode）
  Future<List<AnomalyItem>> getAnomalyStock(List<String> appCodes) async {
    if (appCodes.isEmpty) return [];
    final thscodes = appCodes.map((c) => toThsCode(c)).join(',');
    final res = await _get('/api/a-share/special-data/anomaly-analysis-stock', {'thscodes': thscodes});
    if (!res['ok']) return [];
    return _parseAnomaly(res['data']);
  }

  List<AnomalyItem> _parseAnomaly(dynamic data) {
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      final rawKeywords = m['keyword_list'];
      final keywords = rawKeywords is List ? rawKeywords.map((k) => k.toString()).toList() : const <String>[];
      return AnomalyItem(
        stockName: _str(m['stock_name']),
        analysisContent: _str(m['analysis_content']),
        keywords: keywords,
        code: toAppCode(m['thscode']),
        tagName: _str(m['tag_name']),
      );
    }).toList();
  }

  /// 飙升榜
  Future<List<RankStockItem>> getSkyrocketList({String period = 'day'}) async {
    final res = await _get('/api/a-share/special-data/skyrocket-list', {'period': period});
    if (!res['ok']) return [];
    return _parseRank(res['data']);
  }

  /// 热股榜（24 小时榜 day / 分时榜 hour）
  Future<List<RankStockItem>> getHotStockList({String period = 'day'}) async {
    final res = await _get('/api/a-share/special-data/hot-stock-list', {'period': period});
    if (!res['ok']) return [];
    return _parseRank(res['data']);
  }

  List<RankStockItem> _parseRank(dynamic data) {
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return RankStockItem(
        code: toAppCode(m['thscode'] ?? m['ticker']),
        name: _str(m['name']),
        rank: (m['rank'] as num?)?.toInt() ?? 0,
        heat: _num(m['heat']),
        rankChange: (m['rank_change'] as num?)?.toInt() ?? 0,
        rankTrend: _str(m['rank_trend']),
      );
    }).toList();
  }

  /// 估值快照（PE/PB/PS/PCF），App 内部代码列表自动转 thscode
  Future<List<ValuationSnapshot>> getValuationSnapshot(List<String> appCodes) async {
    if (appCodes.isEmpty) return [];
    final thscodes = appCodes.map((c) => toThsCode(c)).join(',');
    final res = await _get('/api/a-share/valuations/snapshot', {'thscodes': thscodes});
    if (!res['ok']) return [];
    final data = res['data'];
    final items = (data is Map && data['item'] is List) ? data['item'] as List : const <dynamic>[];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return ValuationSnapshot(
        code: toAppCode(m['thscode'] ?? m['ticker']),
        name: _str(m['name']),
        peTtm: _nullableNum(m['pe_ttm']),
        peMrq: _nullableNum(m['pe_mrq']),
        pbMrq: _nullableNum(m['pb_mrq']),
        psTtm: _nullableNum(m['ps_ttm']),
        pcfTtm: _nullableNum(m['pcf_ttm']),
      );
    }).toList();
  }

  // ── 代码互转辅助 ──
  /// '600519.SH' → 'sh600519'（App 内部代码）
  static String toAppCode(dynamic v) => _thsCode(v);

  /// 'sh600519' / '600519' → '600519.SH'（同花顺请求格式）
  static String toThsCode(String code) {
    final s = code.replaceAll(RegExp(r'[^0-9A-Za-z.]'), '');
    if (s.contains('.')) return s.toUpperCase();
    final pure = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (pure.length != 6) return s.toUpperCase();
    final suffix = pure.startsWith('6')
        ? 'SH'
        : (pure.startsWith('8') || pure.startsWith('4'))
            ? 'BJ'
            : 'SZ';
    return '$pure.$suffix';
  }

  static double? _nullableNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 测试连通性：用 600519 搜索，返回可读结果字符串（供 UI 展示）
  Future<String> testConnection() async {
    if (_apiKey.isEmpty) return '请先在上方填入同花顺 API Key';
    final items = await searchTicker('600519', limit: 1);
    if (items.isEmpty) return '连接成功，但未返回数据（可能 Key 权限不足）';
    final first = items.first;
    final name = first['name']?.toString() ?? first['secu_name']?.toString() ?? '未知';
    final code = first['thscode']?.toString() ?? first['ts_code']?.toString() ?? '';
    return '连接成功 ✓ 示例：$name ($code)';
  }
}
