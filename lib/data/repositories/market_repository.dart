import '../datasources/market_api.dart';
import '../datasources/search_api.dart';
import '../models/kline_data.dart';
import '../models/realtime_quote.dart';

/// 行情数据仓库 — 整合多个数据源
class MarketRepository {
  final MarketApi _marketApi;
  final SearchApi _searchApi;

  MarketRepository({
    MarketApi? marketApi,
    SearchApi? searchApi,
  })  : _marketApi = marketApi ?? MarketApi(),
        _searchApi = searchApi ?? SearchApi();

  /// 获取实时行情
  Future<RealtimeQuote> getRealtime(String code) {
    return _marketApi.getRealtime(code);
  }

  /// 批量获取实时行情
  Future<List<RealtimeQuote>> getBatchRealtime(List<String> codes) async {
    final results = await Future.wait(
      codes.map((c) => getRealtime(c).catchError((_) => RealtimeQuote.empty())),
    );
    return results;
  }

  /// 获取 K 线数据
  Future<List<KlineData>> getKline({
    required String code,
    String period = 'day',
    int count = 200,
    bool forceRefresh = false,
  }) {
    return _marketApi.getKline(code: code, period: period, count: count, forceRefresh: forceRefresh);
  }

  /// 搜索股票
  Future<List<SearchResult>> search(String keyword) {
    return _searchApi.search(keyword);
  }
}
