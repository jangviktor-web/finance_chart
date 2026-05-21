import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/kline_data.dart';
import '../../data/models/scan_result.dart';
import '../../data/datasources/market_api.dart';
import '../../data/repositories/market_repository.dart';

/// 全市场扫描服务 — 批量获取K线并检测买入信号
class MarketScanner {
  final MarketRepository _repo;
  final void Function(int current, int total, String code)? onProgress;

  MarketScanner({MarketRepository? repo, this.onProgress})
      : _repo = repo ?? MarketRepository();

  /// 扫描全市场 — 返回符合策略的潜力股
  Future<List<ScanResult>> scan(ScanConfig config) async {
    // 1. 获取全市场股票代码列表
    final stocks = await _getFullStockList();
    final filtered = _filterStocks(stocks, config);

    // 2. 批量扫描
    final results = <ScanResult>[];
    final total = filtered.length;
    final batchSize = 10;

    for (int i = 0; i < total; i += batchSize) {
      final batch = filtered.skip(i).take(batchSize).toList();
      final futures = batch.map((stock) async {
        onProgress?.call(i + batch.indexOf(stock) + 1, total, stock['code']!);
        try {
          final klines = await _repo.getKline(code: stock['code']!, period: 'day', count: 100);
          if (klines.length < 30) return null;
          return _analyzeStock(stock['code']!, stock['name']!, klines, config.strategy);
        } catch (_) {
          return null;
        }
      });

      final batchResults = await Future.wait(futures);
      for (final result in batchResults) {
        if (result != null) results.add(result);
      }
    }

    // 3. 按胜率排序
    results.sort((a, b) => b.winRate.compareTo(a.winRate));
    return results;
  }

  /// 分析单只股票，检测信号
  ScanResult? _analyzeStock(String code, String name, List<KlineData> klines, String strategy) {
    final i = klines.length - 1;

    // 尝试所有策略（或指定策略）
    final strategies = strategy == 'all'
        ? ['ma_cross', 'kdj_cross', 'rsi_oversold', 'macd_cross', 'volume_break']
        : [strategy];

    for (final s in strategies) {
      final signal = _detectSignal(klines, i, s);
      if (signal != null) {
        return ScanResult(
          code: code,
          name: name,
          price: klines.last.close,
          changePercent: klines.length >= 2
              ? (klines.last.close - klines[klines.length - 2].close) /
                  klines[klines.length - 2].close * 100
              : 0,
          signal: signal.$1,
          strategy: signal.$2,
          winRate: signal.$3,
          expectedRange: signal.$4,
          scanTime: DateTime.now(),
        );
      }
    }
    return null;
  }

  /// 检测买入信号
  (String, String, double, double)? _detectSignal(List<KlineData> klines, int i, String strategy) {
    switch (strategy) {
      case 'ma_cross':
        return _detectMACross(klines, i);
      case 'kdj_cross':
        return _detectKDJCross(klines, i);
      case 'rsi_oversold':
        return _detectRSIOversold(klines, i);
      case 'macd_cross':
        return _detectMACDCross(klines, i);
      case 'volume_break':
        return _detectVolumeBreak(klines, i);
    }
    return null;
  }

  (String, String, double, double)? _detectMACross(List<KlineData> klines, int i) {
    if (i < 20) return null;
    final ma5 = _ma(klines, i, 5);
    final ma20 = _ma(klines, i, 20);
    final prevMa5 = _ma(klines, i - 1, 5);
    final prevMa20 = _ma(klines, i - 1, 20);
    if (prevMa5 <= prevMa20 && ma5 > ma20) {
      return ('MA5上穿MA20金叉', 'MA均线交叉', 52.0, 1.5);
    }
    return null;
  }

  (String, String, double, double)? _detectKDJCross(List<KlineData> klines, int i) {
    if (i < 10) return null;
    final (k, d, j) = _kdj(klines, i);
    final (prevK, prevD, _) = _kdj(klines, i - 1);
    if (prevK <= prevD && k > d && j < 50) {
      return ('KDJ金叉超卖反弹', 'KDJ金叉', 48.0, 2.0);
    }
    return null;
  }

  (String, String, double, double)? _detectRSIOversold(List<KlineData> klines, int i) {
    if (i < 15) return null;
    final rsi = _rsi(klines, i, 14);
    final prevRsi = _rsi(klines, i - 1, 14);
    if (prevRsi < 35 && rsi >= 30) {
      return ('RSI超卖反弹', 'RSI超卖反弹', 50.0, 1.8);
    }
    return null;
  }

  (String, String, double, double)? _detectMACDCross(List<KlineData> klines, int i) {
    if (i < 30) return null;
    final (dif, dea) = _macd(klines, i);
    final (prevDif, prevDea) = _macd(klines, i - 1);
    if (prevDif <= prevDea && dif > dea) {
      return ('MACD金叉', 'MACD金叉', 51.0, 1.6);
    }
    return null;
  }

  (String, String, double, double)? _detectVolumeBreak(List<KlineData> klines, int i) {
    if (i < 6) return null;
    final avgVol = klines.sublist(i - 5, i).map((k) => k.volume).reduce((a, b) => a + b) / 5;
    if (avgVol <= 0) return null;
    final ratio = klines[i].volume / avgVol;
    final change = (klines[i].close - klines[i - 1].close) / klines[i - 1].close;
    if (ratio > 2 && change > 0.02) {
      return ('放量突破涨幅>2%', '放量突破', 45.0, 2.5);
    }
    return null;
  }

  double _ma(List<KlineData> klines, int end, int period) {
    if (end < period - 1) return 0;
    double sum = 0;
    for (int i = end; i > end - period; i--) {
      sum += klines[i].close;
    }
    return sum / period;
  }

  (double, double, double) _kdj(List<KlineData> klines, int i) {
    if (i < 8) return (50, 50, 50);
    double k = 50, d = 50;
    for (int j = i - 8; j <= i && j < klines.length; j++) {
      double high = klines[j].high;
      double low = klines[j].low;
      for (int h = j - 8; h < j && h >= 0; h++) {
        if (klines[h].high > high) high = klines[h].high;
        if (klines[h].low < low) low = klines[h].low;
      }
      final rsv = high > low ? (klines[j].close - low) / (high - low) * 100 : 50;
      k = k * 2 / 3 + rsv / 3;
      d = d * 2 / 3 + k / 3;
    }
    final j = 3 * k - 2 * d;
    return (k, d, j);
  }

  double _rsi(List<KlineData> klines, int i, int period) {
    if (i < period) return 50;
    double gain = 0, loss = 0;
    for (int j = i - period + 1; j <= i; j++) {
      final diff = klines[j].close - klines[j - 1].close;
      if (diff > 0) gain += diff;
      else loss -= diff;
    }
    final avgGain = gain / period;
    final avgLoss = loss / period;
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - 100 / (1 + rs);
  }

  (double, double) _macd(List<KlineData> klines, int i) {
    double ema12 = klines[0].close;
    double ema26 = klines[0].close;
    double dea = 0;
    for (int j = 1; j <= i && j < klines.length; j++) {
      ema12 = ema12 * 11 / 13 + klines[j].close * 2 / 13;
      ema26 = ema26 * 25 / 27 + klines[j].close * 2 / 27;
      final dif = ema12 - ema26;
      if (j == 1) {
        dea = dif;
      } else {
        dea = dea * 8 / 10 + dif * 2 / 10;
      }
    }
    final dif = ema12 - ema26;
    return (dif, dea);
  }

  /// 从东方财富获取全市场股票列表（Dio + 重试 + 备用域名降级）
  Future<List<Map<String, String>>> _getFullStockList() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://quote.eastmoney.com/',
        'Accept': 'application/json, text/plain, */*',
      },
    ));

    final stocks = <Map<String, String>>[];
    // 市场列表: (market, plate, label)
    final markets = [('1', '2', '沪市主板'), ('0', '6', '深市主板'), ('0', '80', '创业板')];

    for (final (market, plate, label) in markets) {
      await _fetchListWithRetry(dio, stocks, market, plate, label);
    }
    return stocks;
  }

  /// 带重试 + 备用域名降级的股票列表获取
  Future<void> _fetchListWithRetry(
    Dio dio,
    List<Map<String, String>> stocks,
    String market,
    String plate,
    String label,
  ) async {
    // 主域名 + 备用域名
    final hosts = ['push2.eastmoney.com', 'push3.eastmoney.com'];

    for (final host in hosts) {
      bool success = false;
      for (int retry = 0; retry < 2; retry++) {
        try {
          final params = {
            'pn': '1',
            'pz': '3000',
            'po': '1',
            'np': '1',
            'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
            'fltt': '2',
            'invt': '2',
            'fid': 'f3',
            'fs': 'm:$market+t:$plate+f:!50',
            'fields': 'f12,f14',
          };

          final response = await dio.get(
            'https://$host/api/qt/clist/get',
            queryParameters: params,
          );
          final data = response.data is String ? json.decode(response.data) : response.data;
          final diff = data['data']?['diff'];

          if (diff is List) {
            for (final item in diff) {
              final code = item['f12']?.toString() ?? '';
              final name = item['f14']?.toString() ?? '';
              if (code.isNotEmpty && name.isNotEmpty) {
                final prefix = market == '1' ? 'sh' : 'sz';
                stocks.add({'code': '$prefix$code', 'name': name});
              }
            }
            success = true;
            break;
          }
        } catch (_) {
          if (retry < 1) await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (success) break;
    }
  }

  /// 过滤股票
  List<Map<String, String>> _filterStocks(
    List<Map<String, String>> stocks,
    ScanConfig config,
  ) {
    return stocks.where((s) {
      final name = s['name']!;
      final code = s['code']!;

      if (config.filterST && (name.contains('ST') || name.contains('*ST'))) return false;
      if (config.filterSTAR && code.contains('688')) return false;
      if (config.filterChiNext && code.contains('300')) return false;

      return true;
    }).toList();
  }
}
