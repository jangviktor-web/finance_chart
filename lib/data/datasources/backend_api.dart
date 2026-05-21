import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/errors/api_exception.dart';

/// Python 后端 API 客户端
/// 用于调用 FastAPI 后端的 akshare 数据、回测、形态识别等功能
class BackendApi {
  final Dio _dio;
  String _baseUrl;

  BackendApi({String? baseUrl, Dio? dio})
      : _baseUrl = baseUrl ?? 'http://10.0.2.2:8000',
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        ));

  String get baseUrl => _baseUrl;

  set baseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  // ──────────── 行情数据 ────────────

  /// 获取后端 K 线数据（akshare 源）
  Future<Map<String, dynamic>> getKline(String code, {
    String period = 'day',
    int count = 200,
  }) async {
    return _get('/api/v1/market/$code/kline?period=$period&count=$count');
  }

  /// 获取板块资金流向
  Future<Map<String, dynamic>> getSectorFlow() async {
    return _get('/api/v1/market/sector_flow');
  }

  /// 获取行业排名
  Future<Map<String, dynamic>> getIndustryRank() async {
    return _get('/api/v1/market/industry_rank');
  }

  // ──────────── 技术指标 ────────────

  /// 获取高级技术指标 (ATR/TRIX/DMI/CCI/WR/BIAS/OBV 等)
  Future<Map<String, dynamic>> getIndicators(String code, {
    List<String> indicators = const ['ATR', 'TRIX', 'DMI', 'CCI', 'WR', 'BIAS', 'OBV'],
  }) async {
    return _post('/api/v1/indicators/$code', {
      'indicators': indicators,
    });
  }

  // ──────────── 形态识别 ────────────

  /// 形态识别
  Future<Map<String, dynamic>> getPatterns(String code, {
    List<String> patterns = const ['w_bottom', 'v_reversal', 'cup_handle', 'triple_bottom', 'dip_buy'],
  }) async {
    return _post('/api/v1/patterns/$code', {
      'patterns': patterns,
    });
  }

  // ──────────── 策略回测 ────────────

  /// 运行策略回测
  Future<Map<String, dynamic>> runBacktest({
    required String code,
    required String strategy,
    String? startDate,
    String? endDate,
    double initialCapital = 100000,
  }) async {
    return _post('/api/v1/backtest', {
      'codes': [code],
      'strategy': strategy,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'initial_capital': initialCapital,
    });
  }

  // ──────────── 市场情绪 ────────────

  /// 涨停池
  Future<Map<String, dynamic>> getLimitUpPool({String? date, int limit = 30}) async {
    return _get('/api/v1/sentiment/limit_up?limit=$limit${date != null ? '&date=$date' : ''}');
  }

  /// 跌停池
  Future<Map<String, dynamic>> getLimitDownPool({String? date, int limit = 30}) async {
    return _get('/api/v1/sentiment/limit_down?limit=$limit${date != null ? '&date=$date' : ''}');
  }

  /// 龙虎榜
  Future<Map<String, dynamic>> getDragonTiger({int days = 5, int limit = 30}) async {
    return _get('/api/v1/sentiment/dragon_tiger?days=$days&limit=$limit');
  }

  /// 北向资金
  Future<Map<String, dynamic>> getNorthbound({String symbol = '北向', int days = 30}) async {
    return _get('/api/v1/sentiment/northbound?symbol=$symbol&days=$days');
  }

  /// 融资融券
  Future<Map<String, dynamic>> getMargin({int days = 30}) async {
    return _get('/api/v1/sentiment/margin?days=$days');
  }

  // ──────────── 个股深度 ────────────

  /// 股东人数变化
  Future<Map<String, dynamic>> getShareholders(String code) async {
    return _get('/api/v1/stock/$code/shareholders');
  }

  /// 估值数据
  Future<Map<String, dynamic>> getValuation(String code) async {
    return _get('/api/v1/stock/$code/valuation');
  }

  /// 大宗交易
  Future<Map<String, dynamic>> getBlockTrades(String code, {int limit = 20}) async {
    return _get('/api/v1/stock/$code/block_trades?limit=$limit');
  }

  // ──────────── AI 功能 ────────────

  /// AI 诊断
  Future<Map<String, dynamic>> aiDiagnose(String code, {String? question}) async {
    return _post('/api/v1/ai/diagnose', {
      'code': code,
      if (question != null) 'question': question,
    });
  }

  /// AI 选股
  Future<Map<String, dynamic>> aiSelect(String query, {
    String market = 'A股',
    int topN = 10,
  }) async {
    return _post('/api/v1/ai/select', {
      'query': query,
      'market': market,
      'top_n': topN,
    });
  }

  // ──────────── 多股对比 ────────────

  /// 多股对比评分
  Future<Map<String, dynamic>> compareStocks(List<String> codes, {
    List<String> dimensions = const ['valuation', 'momentum', 'volatility', 'trend'],
  }) async {
    return _post('/api/v1/compare', {
      'codes': codes,
      'dimensions': dimensions,
    });
  }

  // ──────────── 底层请求 ────────────

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get('$_baseUrl$path');
      final data = response.data is String
          ? json.decode(response.data as String)
          : response.data;

      if (data is Map<String, dynamic> && data.containsKey('code')) {
        if (data['code'] != 0) {
          throw ApiException(
            data['message']?.toString() ?? '后端错误',
            statusCode: data['code'] as int?,
            source: path,
          );
        }
        return data['data'] as Map<String, dynamic>? ?? {};
      }

      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        '后端请求失败: ${e.message}',
        source: path,
      );
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post('$_baseUrl$path', data: body);
      final data = response.data is String
          ? json.decode(response.data as String)
          : response.data;

      if (data is Map<String, dynamic> && data.containsKey('code')) {
        if (data['code'] != 0) {
          throw ApiException(
            data['message']?.toString() ?? '后端错误',
            statusCode: data['code'] as int?,
            source: path,
          );
        }
        return data['data'] as Map<String, dynamic>? ?? {};
      }

      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        '后端请求失败: ${e.message}',
        source: path,
      );
    }
  }
}
