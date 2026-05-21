import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/indicator_params.dart';

/// 指标参数状态管理
final indicatorParamsProvider = StateNotifierProvider<IndicatorParamsNotifier, IndicatorParams>(
  (ref) => IndicatorParamsNotifier(),
);

class IndicatorParamsNotifier extends StateNotifier<IndicatorParams> {
  IndicatorParamsNotifier() : super(const IndicatorParams());

  void updateMaPeriods(List<int> periods) {
    state = state.copyWith(maPeriods: periods);
  }

  void updateMacd({int? short, int? long, int? signal}) {
    state = state.copyWith(
      macdShort: short ?? state.macdShort,
      macdLong: long ?? state.macdLong,
      macdSignal: signal ?? state.macdSignal,
    );
  }

  void updateRsi(int period) {
    state = state.copyWith(rsiPeriod: period);
  }

  void updateKdj(int period) {
    state = state.copyWith(kdjPeriod: period);
  }

  void updateBoll({int? period, double? multiplier}) {
    state = state.copyWith(
      bollPeriod: period ?? state.bollPeriod,
      bollMultiplier: multiplier ?? state.bollMultiplier,
    );
  }

  void updateCci(int period) {
    state = state.copyWith(cciPeriod: period);
  }

  void updateWr(int period) {
    state = state.copyWith(wrPeriod: period);
  }

  void updateAtr(int period) {
    state = state.copyWith(atrPeriod: period);
  }

  void updateBias(List<int> periods) {
    state = state.copyWith(biasPeriods: periods);
  }

  void updateDmi(int period) {
    state = state.copyWith(dmiPeriod: period);
  }

  void updateTrix({int? period, int? signal}) {
    state = state.copyWith(
      trixPeriod: period ?? state.trixPeriod,
      trixSignal: signal ?? state.trixSignal,
    );
  }

  void updateVr(int period) {
    state = state.copyWith(vrPeriod: period);
  }

  void updateMfi(int period) {
    state = state.copyWith(mfiPeriod: period);
  }

  void updateRoc(int period) {
    state = state.copyWith(rocPeriod: period);
  }

  void updateExpma({int? short, int? long}) {
    state = state.copyWith(
      expmaShort: short ?? state.expmaShort,
      expmaLong: long ?? state.expmaLong,
    );
  }

  void updateKtn({int? period, double? multiplier}) {
    state = state.copyWith(
      ktnPeriod: period ?? state.ktnPeriod,
      ktnMultiplier: multiplier ?? state.ktnMultiplier,
    );
  }

  void updateParams(IndicatorParams params) {
    state = params;
  }

  void reset() {
    state = const IndicatorParams();
  }
}
