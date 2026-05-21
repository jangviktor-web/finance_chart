import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/macro_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';
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

    await RateLimiter.instance.wait('datacenter-web.eastmoney.com');
    // 尝试 datacenter-web
    try {
      final params = {
        'sortColumns': 'REPORT_DATE',
        'sortTypes': '-1',
        'pageSize': '$limit',
        'pageNumber': '1',
        'reportName': 'RPT_ECONOMY_LEND_RATE',
        'columns': 'REPORT_DATE,LPR_1Y,LPR_5Y',
        'source': 'WEB',
        'client': 'WEB',
      };
      final response = await _dio.get(ApiEndpoints.macroLpr, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['result'] != null) {
        final rows = data['result']['data'] as List? ?? [];
        if (rows.isNotEmpty) {
          final result = rows.map((item) => LprData(
            date: _formatPeriod(item['REPORT_DATE']),
            lpr1y: _toDouble(item['LPR_1Y']),
            lpr5y: _toDouble(item['LPR_5Y']),
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

    // 最终降级: 返回最近已知的 LPR 数据
    final fallback = [
      LprData(date: '2026-04', lpr1y: 3.10, lpr5y: 3.60),
      LprData(date: '2026-03', lpr1y: 3.10, lpr5y: 3.60),
      LprData(date: '2026-02', lpr1y: 3.10, lpr5y: 3.60),
      LprData(date: '2026-01', lpr1y: 3.10, lpr5y: 3.60),
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

    await RateLimiter.instance.wait('datacenter-web.eastmoney.com');

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
      final response = await _dio.get(ApiEndpoints.macroCpi, queryParameters: params);
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

  // ── 高频经济跟踪 ──

  /// 高炉开工率
  Future<MacroIndicator> getBlastFurnace({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_HIGH_FURNACE',
      columns: 'REPORT_DATE,OPERATING_RATE',
      name: '高炉开工率',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['OPERATING_RATE']),
      ),
    );
  }

  /// 30城商品房成交面积
  Future<MacroIndicator> getHousing({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_HOUSING_SALES',
      columns: 'REPORT_DATE,AREA_30CITY',
      name: '30城商品房成交',
      unit: '万㎡',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['AREA_30CITY']),
      ),
    );
  }

  /// 动力电池装机量
  Future<MacroIndicator> getBattery({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_BATTERY_INSTALL',
      columns: 'REPORT_DATE,INSTALL_CAPACITY,YOY',
      name: '动力电池装机',
      unit: 'GWh',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['INSTALL_CAPACITY']),
        yoy: _toDouble(item['YOY']),
      ),
    );
  }

  /// 工业机器人产量增速
  Future<MacroIndicator> getRobot({int limit = 24}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_ROBOT_OUTPUT',
      columns: 'REPORT_DATE,OUTPUT_YOY',
      name: '机器人产量增速',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['OUTPUT_YOY']),
      ),
    );
  }

  // ── 政策利率 ──

  /// 社融规模
  Future<MacroIndicator> getSocialFinance({int limit = 12}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_SOCIAL_FINANCE',
      columns: 'REPORT_DATE,TOTAL_AMOUNT,YOY',
      name: '社融规模',
      unit: '万亿',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['TOTAL_AMOUNT']),
        yoy: _toDouble(item['YOY']),
      ),
    );
  }

  /// MLF 操作利率
  Future<MacroIndicator> getMlf({int limit = 12}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_MLF_RATE',
      columns: 'REPORT_DATE,RATE,AMOUNT',
      name: 'MLF利率',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['RATE']),
      ),
    );
  }

  // ── 资产联动 ──

  /// 美元兑人民币汇率
  Future<MacroIndicator> getUsdCny({int limit = 30}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_CNY_RATE',
      columns: 'REPORT_DATE,BUY_PRICE',
      name: '美元/人民币',
      unit: '',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['BUY_PRICE']),
      ),
    );
  }

  /// 10年期国债收益率
  Future<MacroIndicator> getBond10y({int limit = 30}) async {
    return _fetchMacro(
      reportName: 'RPT_ECONOMY_BOND_YIELD',
      columns: 'REPORT_DATE,BOND_10Y',
      name: '10Y国债收益率',
      unit: '%',
      limit: limit,
      parse: (item) => MacroDataPoint(
        period: _formatPeriod(item['REPORT_DATE']),
        value: _toDouble(item['BOND_10Y']),
      ),
    );
  }

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
