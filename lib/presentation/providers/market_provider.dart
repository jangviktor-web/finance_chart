import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/market_api.dart';
import '../../data/datasources/search_api.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/models/realtime_quote.dart';
import '../../data/models/kline_data.dart';
import '../../data/models/indicator_data.dart';
import '../../data/models/indicator_params.dart';
import '../../domain/services/indicator_calculator.dart';
import 'indicator_params_provider.dart';
import 'settings_provider.dart';

// ──────────── 依赖注入 ────────────

final marketApiProvider = Provider<MarketApi>((ref) {
  final settings = ref.watch(settingsProvider);
  return MarketApi(
    realtimeSource: settings.realtimeSource,
    klineSource: settings.klineSource,
  );
});
final searchApiProvider = Provider<SearchApi>((_) => SearchApi());
final indicatorCalculatorProvider = Provider<IndicatorCalculator>((_) => IndicatorCalculator());

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(
    marketApi: ref.watch(marketApiProvider),
    searchApi: ref.watch(searchApiProvider),
  );
});

// ──────────── 行情状态 ────────────

/// 实时行情状态
class MarketState {
  final RealtimeQuote quote;
  final List<KlineData> klines;
  final IndicatorData indicators;
  final bool isLoading;
  final String? error;
  final String period;

  MarketState({
    RealtimeQuote? quote,
    this.klines = const [],
    IndicatorData? indicators,
    this.isLoading = false,
    this.error,
    this.period = 'day',
  })  : quote = quote ?? const RealtimeQuote(code: '', name: '--', now: 0, yesterday: 0, high: 0, low: 0),
        indicators = indicators ?? IndicatorData.empty();

  MarketState copyWith({
    RealtimeQuote? quote,
    List<KlineData>? klines,
    IndicatorData? indicators,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? period,
  }) {
    return MarketState(
      quote: quote ?? this.quote,
      klines: klines ?? this.klines,
      indicators: indicators ?? this.indicators,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      period: period ?? this.period,
    );
  }
}

/// K 线数据 Provider（按 code 缓存，autoDispose 防止状态无限驻留）
final klineProvider = StateNotifierProvider.autoDispose.family<KlineNotifier, MarketState, String>((ref, code) {
  return KlineNotifier(ref, code);
});

class KlineNotifier extends StateNotifier<MarketState> {
  final Ref _ref;
  final String code;
  bool _disposed = false;

  KlineNotifier(this._ref, this.code) : super(MarketState()) {
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 守卫：autoDispose 后不再写入已销毁的 notifier
  void _updateState(MarketState next) {
    if (!_disposed) state = next;
  }

  Future<void> load({String period = 'day', int count = 200, bool forceRefresh = false}) async {
    _updateState(state.copyWith(isLoading: true, clearError: true, period: period));

    try {
      final repo = _ref.read(marketRepositoryProvider);
      final params = _ref.read(indicatorParamsProvider);

      final realtimeFuture = repo.getRealtime(code);
      final klineFuture = repo.getKline(code: code, period: period, count: count, forceRefresh: forceRefresh);

      final quote = await realtimeFuture;
      final klines = await klineFuture;
      // P0-3: 指标计算移入后台 isolate，避免主线程卡顿
      final indicators = await compute(
        calculateIndicatorsIsolate,
        (klines: klines, params: params, requested: null),
      );

      _updateState(state.copyWith(
        quote: quote,
        klines: klines,
        indicators: indicators,
        isLoading: false,
        period: period,
      ));
    } catch (e) {
      _updateState(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// 用新参数重新计算指标（不重新拉数据）
  Future<void> recalculateIndicators(IndicatorParams params) async {
    if (state.klines.isEmpty) return;
    final indicators = await compute(
      calculateIndicatorsIsolate,
      (klines: state.klines, params: params, requested: null),
    );
    _updateState(state.copyWith(indicators: indicators));
  }

  /// 按需请求扩展指标（惰性计算，后台 isolate）
  Future<void> requestIndicators(Set<String> indicatorNames) async {
    if (state.klines.isEmpty) return;
    final indicators = await compute(
      calculateIndicatorsIsolate,
      (klines: state.klines, params: _ref.read(indicatorParamsProvider), requested: indicatorNames),
    );
    _updateState(state.copyWith(indicators: indicators));
  }
}
