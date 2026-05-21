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

/// K 线数据 Provider（按 code 缓存）
final klineProvider = StateNotifierProvider.family<KlineNotifier, MarketState, String>((ref, code) {
  return KlineNotifier(ref, code);
});

class KlineNotifier extends StateNotifier<MarketState> {
  final Ref _ref;
  final String code;

  KlineNotifier(this._ref, this.code) : super(MarketState()) {
    load();
  }

  Future<void> load({String period = 'day', int count = 200}) async {
    state = state.copyWith(isLoading: true, clearError: true, period: period);

    try {
      final repo = _ref.read(marketRepositoryProvider);
      final calculator = _ref.read(indicatorCalculatorProvider);
      final params = _ref.read(indicatorParamsProvider);

      final realtimeFuture = repo.getRealtime(code);
      final klineFuture = repo.getKline(code: code, period: period, count: count);

      final quote = await realtimeFuture;
      final klines = await klineFuture;
      final indicators = calculator.calculateAll(klines, params: params);

      state = state.copyWith(
        quote: quote,
        klines: klines,
        indicators: indicators,
        isLoading: false,
        period: period,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 用新参数重新计算指标（不重新拉数据）
  void recalculateIndicators(IndicatorParams params) {
    if (state.klines.isEmpty) return;
    final calculator = _ref.read(indicatorCalculatorProvider);
    final indicators = calculator.calculateAll(state.klines, params: params);
    state = state.copyWith(indicators: indicators);
  }

  /// 按需请求扩展指标（惰性计算）
  void requestIndicators(Set<String> indicatorNames) {
    if (state.klines.isEmpty) return;
    final calculator = _ref.read(indicatorCalculatorProvider);
    final params = _ref.read(indicatorParamsProvider);
    final indicators = calculator.calculateAll(
      state.klines,
      params: params,
      requestedIndicators: indicatorNames,
      existing: state.indicators,
    );
    state = state.copyWith(indicators: indicators);
  }
}
