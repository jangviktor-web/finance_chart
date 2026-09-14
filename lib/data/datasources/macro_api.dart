import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/macro_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';
import 'em_http.dart';
import 'local/cache_manager.dart';

/// 宏观经济数据 API — 东方财富
class MacroApi {
  final Dio _dio;

  MacroApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://data.eastmoney.com/',
          },
        ));

  /// CPI 数据 — 字段: NATIONAL_SAME(同比), NATIONAL_SEQUENTIAL(环比)
  Future<MacroIndicator> getCpi({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_CPI',
      columns: 'REPORT_DATE,NATIONAL_SAME,NATIONAL_BASE,NATIONAL_SEQUENTIAL',
      name: 'CPI',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['NATIONAL_SAME']),
        yoy: _toDouble(item['NATIONAL_SAME']),
        mom: _toDouble(item['NATIONAL_SEQUENTIAL']),
      ),
    );
  }

  /// PPI 数据 — 字段: BASE_SAME(同比)
  Future<MacroIndicator> getPpi({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_PPI',
      columns: 'REPORT_DATE,BASE,BASE_SAME,BASE_ACCUMULATE',
      name: 'PPI',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['BASE_SAME']),
        yoy: _toDouble(item['BASE_SAME']),
      ),
    );
  }

  /// GDP 数据 — 字段: SUM_SAME(增速)
  Future<MacroIndicator> getGdp({int limit = 12}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_GDP',
      columns: 'REPORT_DATE,DOMESTICL_PRODUCT_BASE,SUM_SAME,FIRST_SAME,SECOND_SAME,THIRD_SAME',
      name: 'GDP',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['SUM_SAME']),
        yoy: _toDouble(item['SUM_SAME']),
      ),
    );
  }

  /// PMI 数据 — 字段: MAKE_INDEX(制造业PMI)
  Future<MacroIndicator> getPmi({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_PMI',
      columns: 'REPORT_DATE,MAKE_INDEX,MAKE_SAME',
      name: 'PMI',
      unit: '',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['MAKE_INDEX']),
        yoy: _toDouble(item['MAKE_SAME']),
      ),
    );
  }

  /// M2 数据 — 字段: BASIC_CURRENCY_SAME(M2同比), CURRENCY_SAME(M1同比)
  Future<MacroIndicator> getM2({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_CURRENCY_SUPPLY',
      columns: 'REPORT_DATE,BASIC_CURRENCY,BASIC_CURRENCY_SAME,CURRENCY,CURRENCY_SAME,FREE_CASH,FREE_CASH_SAME',
      name: 'M2',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['BASIC_CURRENCY_SAME']),
        yoy: _toDouble(item['BASIC_CURRENCY_SAME']),
      ),
    );
  }

  /// LPR 数据 — 降级: 用 push2 API 或硬编码最新数据
  Future<List<LprData>> getLpr({int limit = 20}) async {
    // 缓存 1 小时
    final cacheKey = 'macro_LPR';
    final cached = CacheManager.instance.get<List<LprData>>(cacheKey);
    if (cached != null) return cached;

    // 尝试 datacenter-web（getEmWithMirror 内部会按实际使用的域名限流）
    try {
      // 🔴 修正（2026-09-14 curl 实测）：
      // 原 reportName `RPT_ECONOMY_LEND_RATE` 服务端返回
      // `{"success":false,"message":"报表配置不存在,RPT_ECONOMY_LEND_RATE"}` —— 该报表
      // 早已不存在，LPR 主源一直是死的，全靠下面的降级链在撑。
      // 正确报表是 `RPTA_WEB_RATE`，且它没有 REPORT_DATE 列（用 REPORT_DATE 排序会报
      // 「REPORT_DATE排序列不存在」），须按 TRADE_DATE 排序；字段名是 LPR1Y / LPR5Y。
      // 实测返回：{"TRADE_DATE":"2026-08-20 00:00:00","LPR1Y":3,"LPR5Y":3.5,...}
      final params = {
        'sortColumns': 'TRADE_DATE',
        'sortTypes': '-1',
        'pageSize': '$limit',
        'pageNumber': '1',
        'reportName': 'RPTA_WEB_RATE',
        'columns': 'TRADE_DATE,LPR1Y,LPR5Y',
        'source': 'WEB',
        'client': 'WEB',
      };
      final response = await getEmWithMirror(_dio, ApiEndpoints.macroLpr, params: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] != null) {
        final rows = data['result']['data'] as List? ?? [];
        if (rows.isNotEmpty) {
          final result = rows.map((item) => LprData(
            // _formatPeriod 取前 7 位 → "2026-08"，与兜底值的 'YYYY-MM' 形状一致
            date: _formatPeriod(item['TRADE_DATE']),
            lpr1y: _toDouble(item['LPR1Y']),
            lpr5y: _toDouble(item['LPR5Y']),
          )).toList();
          CacheManager.instance.set(cacheKey, result, CacheManager.ttlMacro);
          return result;
        }
      }
    } catch (_) {}

    // 降级: 用 push2 stock/get 获取 LPR 相关数据
    try {
      final url = '${ApiEndpoints.eastmoneyPush}/api/qt/clist/get';
      final params = {
        'pn': '1', 'pz': '$limit', 'po': '1', 'np': '1',
        'fltt': '2', 'invt': '2',
        'fid': 'f12',
        'fs': 'm:113+t:1',
        'fields': 'f2,f12,f14',
      };
      final response = await _dio.get(url, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;
      // 如果有数据就返回
      if (data['data'] != null) {
        final rows = (data['data']['diff'] as List?) ?? [];
        if (rows.isNotEmpty) {
          final result = rows.map((item) => LprData(
            date: item['f14']?.toString() ?? '',
            lpr1y: _toDouble(item['f2']),
            lpr5y: 0,
          )).toList();
          CacheManager.instance.set(cacheKey, result, CacheManager.ttlMacro);
          return result;
        }
      }
    } catch (_) {}

    // 最终降级: 返回最近一次**实测确认**的 LPR 值。
    // 原值（2026-04 / 3.10 / 3.60 × 4 个月）是凭空的错数据 —— 实测 2026-08-20
    // 已经是 1Y=3.0 / 5Y=3.5。宁可只给一条正确记录，也不编造另外三个月。
    final fallback = [
      LprData(date: '2026-08', lpr1y: 3.0, lpr5y: 3.5),
    ];
    CacheManager.instance.set(cacheKey, fallback, CacheManager.ttlMacro);
    return fallback;
  }

  Future<MacroIndicator> _fetchMacro({
    required String reportName,
    required String columns,
    required String name,
    required String unit,
    required int limit,
    required MacroDataPoint Function(Map<String, dynamic>) parse,
  }) async {
    // 宏观数据变化慢，缓存 1 小时
    final cacheKey = 'macro_$reportName';
    final cached = CacheManager.instance.get<MacroIndicator>(cacheKey);
    if (cached != null) return cached;

    // 不再在这里手动限流：getEmWithMirror 会按**实际使用的域名**限流
    // （可能换到镜像域），手动 wait 主域会既限错域名又多等一次。

    final params = {
      'sortColumns': 'REPORT_DATE',
      'sortTypes': '-1',
      'pageSize': '$limit',
      'pageNumber': '1',
      'reportName': reportName,
      'columns': columns,
      'source': 'WEB',
      'client': 'WEB',
    };

    try {
      // 主域 → 镜像域（实测 datacenter 与 datacenter-web 响应体字节级一致）
      final response = await getEmWithMirror(_dio, ApiEndpoints.macroCpi, params: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      final List<MacroDataPoint> points = [];
      if (data['result'] != null) {
        final rows = data['result']['data'] as List? ?? [];
        for (final item in rows) {
          try {
            points.add(parse(item as Map<String, dynamic>));
          } catch (e) {
            AppLog.instance.error('MacroApi', '解析 $name 数据点失败: $e');
          }
        }
      }

      points.sort((a, b) => a.period.compareTo(b.period));

      final result = MacroIndicator(
        name: name,
        unit: unit,
        data: points,
        latestValue: points.isNotEmpty ? points.last.value : null,
        latestYoy: points.isNotEmpty ? points.last.yoy : null,
      );
      CacheManager.instance.set(cacheKey, result, CacheManager.ttlMacro);
      return result;
    } catch (e) {
      AppLog.instance.error('MacroApi', '获取 $name 失败: $e');
      return MacroIndicator(name: name, unit: unit, data: []);
    }
  }

  // ── 以下 8 个高频指标（高炉开工率/30城商品房/动力电池装机/机器人产量/
  // 社融/MLF/美元·人民币/10Y国债）原报表名经实测在东财公开数据中心均不存在
  // （返回 报表配置不存在 9501），属无数据源的编造项，已下架以免永久空白。
  // 后续可经由 akshare/同花顺 等补充真实源后重新接入。

  String _formatPeriod(dynamic dateStr) {
    if (dateStr == null) return '';
    final s = dateStr.toString();
    if (s.length >= 10) return s.substring(0, 7); // YYYY-MM
    if (s.length >= 7) return s.substring(0, 7);
    return s;
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
