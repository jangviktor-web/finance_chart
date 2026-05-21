import 'dart:math';
import '../../data/models/kline_data.dart';
import '../../data/models/indicator_data.dart';
import '../../data/models/indicator_params.dart';

class IndicatorCalculator {
  // 计算所有指标 — 支持自定义参数和按需计算
  IndicatorData calculateAll(
    List<KlineData> klines, {
    IndicatorParams? params,
    Set<String>? requestedIndicators,
    IndicatorData? existing,
  }) {
    if (klines.isEmpty) return IndicatorData.empty();

    params ??= const IndicatorParams();
    final closes = klines.map((k) => k.close).toList();
    final highs = klines.map((k) => k.high).toList();
    final lows = klines.map((k) => k.low).toList();
    final volumes = klines.map((k) => k.volume).toList();

    // 基础指标始终计算
    // MA
    final maLines = params.maPeriods.map((p) => ma(closes, p)).toList();

    // MACD
    final macdResult = macd(closes,
      short: params.macdShort, long: params.macdLong, signal: params.macdSignal);

    // KDJ
    final kdjResult = kdj(closes, highs, lows, period: params.kdjPeriod);

    // RSI
    final rsiResult = rsi(closes, params.rsiPeriod);

    // BOLL
    final bollResult = boll(closes, params.bollPeriod, params.bollMultiplier);

    var result = IndicatorData(
      maLines: maLines,
      maPeriods: params.maPeriods,
      dif: macdResult[0],
      dea: macdResult[1],
      macdHist: macdResult[2],
      k: kdjResult[0],
      d: kdjResult[1],
      j: kdjResult[2],
      rsi: rsiResult,
      bollMid: bollResult[0],
      bollUpper: bollResult[1],
      bollLower: bollResult[2],
      activeIndicators: {'MA', 'MACD', 'KDJ', 'RSI', 'BOLL'},
    );

    // 如果没有指定请求的指标，返回基础指标
    if (requestedIndicators == null || requestedIndicators.isEmpty) {
      return result;
    }

    // 按需计算扩展指标
    return calculateExtended(
      result, klines, closes, highs, lows, volumes, params, requestedIndicators,
    );
  }

  /// 按需计算扩展指标
  IndicatorData calculateExtended(
    IndicatorData base,
    List<KlineData> klines,
    List<double> closes,
    List<double> highs,
    List<double> lows,
    List<double> volumes,
    IndicatorParams params,
    Set<String> requested,
  ) {
    List<double>? cciData;
    List<double>? wrData;
    List<double>? atrData;
    List<List<double>>? biasLines;
    List<double>? obvData;
    Map<String, List<double>>? dmiData;
    List<double>? trixData;
    List<double>? trixSignalData;
    List<double>? vrData;
    List<double>? emvData;
    List<double>? bbiData;
    List<double>? mfiData;
    List<double>? asiData;
    List<double>? psyData;
    List<double>? crData;
    List<double>? dpoData;
    List<double>? brData;
    List<double>? arData;
    List<double>? dfmaDif;
    List<double>? dfmaDifma;
    List<double>? mtmData;
    List<double>? mtmSignalData;
    List<double>? massData;
    List<double>? rocData;
    List<double>? expmaShortData;
    List<double>? expmaLongData;
    Map<String, List<double>>? ktnData;
    Map<String, List<double>>? xsiiData;

    if (requested.contains('CCI')) cciData = cci(closes, highs, lows, params.cciPeriod);
    if (requested.contains('WR')) wrData = wr(closes, highs, lows, params.wrPeriod);
    if (requested.contains('ATR')) atrData = atr(highs, lows, closes, params.atrPeriod);
    if (requested.contains('BIAS')) biasLines = bias(closes, params.biasPeriods);
    if (requested.contains('OBV')) obvData = obv(closes, volumes);
    if (requested.contains('DMI')) dmiData = dmi(highs, lows, closes, params.dmiPeriod);
    if (requested.contains('TRIX')) {
      final trixResult = trix(closes, params.trixPeriod, params.trixSignal);
      trixData = trixResult[0];
      trixSignalData = trixResult[1];
    }
    if (requested.contains('VR')) vrData = vr(closes, volumes, params.vrPeriod);
    if (requested.contains('EMV')) emvData = emv(highs, lows, volumes);
    if (requested.contains('BBI')) bbiData = bbi(closes);
    if (requested.contains('MFI')) mfiData = mfi(closes, highs, lows, volumes, params.mfiPeriod);
    if (requested.contains('ASI')) asiData = asi(klines);
    if (requested.contains('PSY')) psyData = psy(closes, params.psyPeriod);
    if (requested.contains('CR')) crData = cr(highs, lows, closes, params.crPeriod);
    if (requested.contains('DPO')) dpoData = dpo(closes, params.dpoPeriod);
    if (requested.contains('BRAR')) {
      final brarResult = brar(klines);
      brData = brarResult[0];
      arData = brarResult[1];
    }
    if (requested.contains('DFMA')) {
      final dfmaResult = dfma(closes);
      dfmaDif = dfmaResult[0];
      dfmaDifma = dfmaResult[1];
    }
    if (requested.contains('MTM')) {
      final mtmResult = mtm(closes, params.mtmPeriod, params.mtmSignal);
      mtmData = mtmResult[0];
      mtmSignalData = mtmResult[1];
    }
    if (requested.contains('MASS')) massData = mass(highs, lows, params.massPeriod1, params.massPeriod2);
    if (requested.contains('ROC')) rocData = roc(closes, params.rocPeriod);
    if (requested.contains('EXPMA')) {
      final expmaResult = expma(closes, params.expmaShort, params.expmaLong);
      expmaShortData = expmaResult[0];
      expmaLongData = expmaResult[1];
    }
    if (requested.contains('KTN')) ktnData = ktn(closes, highs, lows, params.ktnPeriod, params.ktnMultiplier);
    if (requested.contains('XSII')) xsiiData = xsii(closes, highs, lows);

    return base.merge(
      cci: cciData,
      wr: wrData,
      atr: atrData,
      biasLines: biasLines,
      biasPeriods: params.biasPeriods,
      obv: obvData,
      dmi: dmiData,
      trix: trixData,
      trixSignal: trixSignalData,
      vr: vrData,
      emv: emvData,
      bbi: bbiData,
      mfi: mfiData,
      asi: asiData,
      psy: psyData,
      cr: crData,
      dpo: dpoData,
      br: brData,
      ar: arData,
      dfmaDif: dfmaDif,
      dfmaDifma: dfmaDifma,
      mtm: mtmData,
      mtmSignal: mtmSignalData,
      mass: massData,
      roc: rocData,
      expmaShort: expmaShortData,
      expmaLong: expmaLongData,
      ktn: ktnData,
      xsii: xsiiData,
      newActiveIndicators: requested,
    );
  }

  // ════════════════════════════════════════════
  //  基础工具函数
  // ════════════════════════════════════════════

  // MA 简单移动平均
  List<double> ma(List<double> data, int period) {
    if (data.length < period) return List.filled(data.length, 0);
    final result = List<double>.filled(data.length, 0);
    double sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i];
      if (i >= period) sum -= data[i - period];
      if (i >= period - 1) result[i] = sum / period;
    }
    return result;
  }

  // EMA 指数移动平均
  List<double> ema(List<double> data, int period) {
    if (data.isEmpty) return [];
    final result = List<double>.filled(data.length, 0);
    final multiplier = 2.0 / (period + 1);
    result[0] = data[0];
    for (int i = 1; i < data.length; i++) {
      result[i] = (data[i] - result[i - 1]) * multiplier + result[i - 1];
    }
    return result;
  }

  // SMA 简单移动平均（中国式，带权重）
  List<double> _sma(List<double> data, int period, [double weight = 1]) {
    if (data.isEmpty) return [];
    final result = List<double>.filled(data.length, 0);
    result[0] = data[0];
    for (int i = 1; i < data.length; i++) {
      result[i] = (weight * data[i] + (period - weight) * result[i - 1]) / period;
    }
    return result;
  }

  // 标准差
  List<double> _std(List<double> data, int period) {
    final result = List<double>.filled(data.length, 0);
    for (int i = period - 1; i < data.length; i++) {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) sum += data[j];
      final avg = sum / period;
      double varSum = 0;
      for (int j = i - period + 1; j <= i; j++) varSum += (data[j] - avg) * (data[j] - avg);
      result[i] = sqrt(varSum / period);
    }
    return result;
  }

  // ════════════════════════════════════════════
  //  基础指标 (已有)
  // ════════════════════════════════════════════

  // MACD: [DIF, DEA, MACD柱]
  List<List<double>> macd(List<double> closes, {int short = 12, int long = 26, int signal = 9}) {
    final emaShort = ema(closes, short);
    final emaLong = ema(closes, long);
    final dif = List<double>.generate(closes.length, (i) => emaShort[i] - emaLong[i]);
    final dea = ema(dif, signal);
    final macdHist = List<double>.generate(closes.length, (i) => (dif[i] - dea[i]) * 2);
    return [dif, dea, macdHist];
  }

  // KDJ: [K, D, J]
  List<List<double>> kdj(List<double> closes, List<double> highs, List<double> lows, {int period = 9}) {
    final n = closes.length;
    final k = List<double>.filled(n, 50);
    final d = List<double>.filled(n, 50);
    final j = List<double>.filled(n, 50);
    for (int i = 0; i < n; i++) {
      final start = max(0, i - period + 1);
      double highest = highs[start];
      double lowest = lows[start];
      for (int idx = start; idx <= i; idx++) {
        if (highs[idx] > highest) highest = highs[idx];
        if (lows[idx] < lowest) lowest = lows[idx];
      }
      final rsv = highest != lowest ? (closes[i] - lowest) / (highest - lowest) * 100 : 50.0;
      if (i == 0) {
        k[i] = rsv;
        d[i] = rsv;
      } else {
        k[i] = (2 / 3) * k[i - 1] + (1 / 3) * rsv;
        d[i] = (2 / 3) * d[i - 1] + (1 / 3) * k[i];
      }
      j[i] = 3 * k[i] - 2 * d[i];
    }
    return [k, d, j];
  }

  // RSI
  List<double> rsi(List<double> closes, int period) {
    if (closes.length < 2) return List.filled(closes.length, 0);
    final result = List.filled(closes.length, 0.0);
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period && i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      if (change > 0) avgGain += change; else avgLoss -= change;
    }
    avgGain /= period;
    avgLoss /= period;
    if (period < closes.length) {
      result[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    for (int i = period + 1; i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      final gain = change > 0 ? change : 0;
      final loss = change < 0 ? -change : 0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      result[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    return result;
  }

  // BOLL: [MID, UPPER, LOWER]
  List<List<double>> boll(List<double> closes, int period, double multiplier) {
    final n = closes.length;
    final mid = List<double>.filled(n, 0);
    final upper = List<double>.filled(n, 0);
    final lower = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      if (i < period - 1) continue;
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) sum += closes[j];
      final m = sum / period;
      mid[i] = m;
      double variance = 0;
      for (int j = i - period + 1; j <= i; j++) variance += (closes[j] - m) * (closes[j] - m);
      final std = sqrt(variance / period);
      upper[i] = m + std * multiplier;
      lower[i] = m - std * multiplier;
    }
    return [mid, upper, lower];
  }

  // ════════════════════════════════════════════
  //  扩展指标 (MyTT 移植)
  // ════════════════════════════════════════════

  /// CCI 顺势指标 — (tp - MA(tp)) / (0.015 * MeanDev(tp))
  List<double> cci(List<double> closes, List<double> highs, List<double> lows, int period) {
    final n = closes.length;
    final tp = List<double>.generate(n, (i) => (highs[i] + lows[i] + closes[i]) / 3);
    final tpMa = ma(tp, period);
    final result = List<double>.filled(n, 0);
    for (int i = period - 1; i < n; i++) {
      double meanDev = 0;
      for (int j = i - period + 1; j <= i; j++) meanDev += (tp[j] - tpMa[i]).abs();
      meanDev /= period;
      result[i] = meanDev == 0 ? 0 : (tp[i] - tpMa[i]) / (0.015 * meanDev);
    }
    return result;
  }

  /// WR 威廉指标 — (HH - Close) / (HH - LL) * -100
  List<double> wr(List<double> closes, List<double> highs, List<double> lows, int period) {
    final n = closes.length;
    final result = List<double>.filled(n, 0);
    for (int i = period - 1; i < n; i++) {
      double hh = highs[i - period + 1];
      double ll = lows[i - period + 1];
      for (int j = i - period + 1; j <= i; j++) {
        if (highs[j] > hh) hh = highs[j];
        if (lows[j] < ll) ll = lows[j];
      }
      result[i] = hh == ll ? -50 : (hh - closes[i]) / (hh - ll) * -100;
    }
    return result;
  }

  /// ATR 真实波幅 — EMA(TR, period)
  List<double> atr(List<double> highs, List<double> lows, List<double> closes, int period) {
    final n = closes.length;
    final tr = List<double>.filled(n, 0);
    tr[0] = highs[0] - lows[0];
    for (int i = 1; i < n; i++) {
      tr[i] = max(highs[i] - lows[i], max((highs[i] - closes[i - 1]).abs(), (lows[i] - closes[i - 1]).abs()));
    }
    return ema(tr, period);
  }

  /// BIAS 乖离率 — (close - MA) / MA * 100
  List<List<double>> bias(List<double> closes, List<int> periods) {
    return periods.map((period) {
      final maData = ma(closes, period);
      return List<double>.generate(closes.length, (i) {
        return maData[i] == 0 ? 0 : (closes[i] - maData[i]) / maData[i] * 100;
      });
    }).toList();
  }

  /// OBV 能量潮 — 累积 sign(close-prevClose) * volume
  List<double> obv(List<double> closes, List<double> volumes) {
    final n = closes.length;
    final result = List<double>.filled(n, 0);
    result[0] = volumes[0];
    for (int i = 1; i < n; i++) {
      if (closes[i] > closes[i - 1]) {
        result[i] = result[i - 1] + volumes[i];
      } else if (closes[i] < closes[i - 1]) {
        result[i] = result[i - 1] - volumes[i];
      } else {
        result[i] = result[i - 1];
      }
    }
    return result;
  }

  /// DMI 趋向指标 — PDI/MDI/ADX/ADXR
  Map<String, List<double>> dmi(List<double> highs, List<double> lows, List<double> closes, int period) {
    final n = closes.length;
    final pdm = List<double>.filled(n, 0);
    final mdm = List<double>.filled(n, 0);
    final tr = List<double>.filled(n, 0);

    for (int i = 1; i < n; i++) {
      final upMove = highs[i] - highs[i - 1];
      final downMove = lows[i - 1] - lows[i];
      pdm[i] = (upMove > downMove && upMove > 0) ? upMove : 0;
      mdm[i] = (downMove > upMove && downMove > 0) ? downMove : 0;
      tr[i] = max(highs[i] - lows[i], max((highs[i] - closes[i - 1]).abs(), (lows[i] - closes[i - 1]).abs()));
    }

    final adxPdm = ema(pdm, period);
    final adxMdm = ema(mdm, period);
    final atrData = ema(tr, period);

    final pdi = List<double>.filled(n, 0);
    final mdi = List<double>.filled(n, 0);
    final dx = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      pdi[i] = atrData[i] == 0 ? 0 : adxPdm[i] / atrData[i] * 100;
      mdi[i] = atrData[i] == 0 ? 0 : adxMdm[i] / atrData[i] * 100;
      final sum = pdi[i] + mdi[i];
      dx[i] = sum == 0 ? 0 : (pdi[i] - mdi[i]).abs() / sum * 100;
    }

    final adx = ema(dx, period);
    final adxr = List<double>.generate(n, (i) {
      final prev = max(0, i - period);
      return (adx[i] + adx[prev]) / 2;
    });

    return {'pdi': pdi, 'mdi': mdi, 'adx': adx, 'adxr': adxr};
  }

  /// TRIX 三重指数平滑平均线
  List<List<double>> trix(List<double> closes, int period, int signalPeriod) {
    final ema1 = ema(closes, period);
    final ema2 = ema(ema1, period);
    final ema3 = ema(ema2, period);
    final n = closes.length;
    final trixLine = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      trixLine[i] = ema3[i - 1] == 0 ? 0 : (ema3[i] - ema3[i - 1]) / ema3[i - 1] * 100;
    }
    final signal = ma(trixLine, signalPeriod);
    return [trixLine, signal];
  }

  /// VR 成交量比率
  List<double> vr(List<double> closes, List<double> volumes, int period) {
    final n = closes.length;
    final result = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      double upVol = 0, downVol = 0, eqVol = 0;
      final start = max(1, i - period + 1);
      for (int j = start; j <= i; j++) {
        if (closes[j] > closes[j - 1]) upVol += volumes[j];
        else if (closes[j] < closes[j - 1]) downVol += volumes[j];
        else eqVol += volumes[j];
      }
      final denominator = downVol + eqVol / 2;
      result[i] = denominator == 0 ? 100 : (upVol + eqVol / 2) / denominator * 100;
    }
    return result;
  }

  /// EMV 简易波动指标
  List<double> emv(List<double> highs, List<double> lows, List<double> volumes) {
    final n = highs.length;
    final emvRaw = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      final midMove = (highs[i] + lows[i]) / 2 - (highs[i - 1] + lows[i - 1]) / 2;
      final boxRatio = volumes[i] / (highs[i] - lows[i]);
      emvRaw[i] = boxRatio == 0 ? 0 : midMove / boxRatio;
    }
    return ma(emvRaw, 14);
  }

  /// BBI 多空指标 — MA(3)+MA(6)+MA(12)+MA(24) / 4
  List<double> bbi(List<double> closes) {
    final ma3 = ma(closes, 3);
    final ma6 = ma(closes, 6);
    final ma12 = ma(closes, 12);
    final ma24 = ma(closes, 24);
    return List<double>.generate(closes.length, (i) => (ma3[i] + ma6[i] + ma12[i] + ma24[i]) / 4);
  }

  /// MFI 资金流量指标 — 类 RSI 但以 tp*volume 加权
  List<double> mfi(List<double> closes, List<double> highs, List<double> lows, List<double> volumes, int period) {
    final n = closes.length;
    final tp = List<double>.generate(n, (i) => (highs[i] + lows[i] + closes[i]) / 3);
    final mf = List<double>.generate(n, (i) => tp[i] * volumes[i]);
    final result = List<double>.filled(n, 50);
    for (int i = period; i < n; i++) {
      double posMf = 0, negMf = 0;
      for (int j = i - period + 1; j <= i; j++) {
        if (tp[j] > tp[j - 1]) posMf += mf[j]; else negMf += mf[j];
      }
      result[i] = negMf == 0 ? 100 : 100 - 100 / (1 + posMf / negMf);
    }
    return result;
  }

  /// ASI 振动升降指标
  List<double> asi(List<KlineData> klines) {
    final n = klines.length;
    final result = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      final cur = klines[i];
      final prev = klines[i - 1];
      final r = _asiR(cur.open, cur.high, cur.low, prev.close);
      final k = max((cur.high - prev.close).abs(), (cur.low - prev.close).abs());
      final l = max((cur.high - cur.low).abs(), 0.0001);
      final si = r == 0 ? 0 : 50 * (cur.close - prev.close + (cur.close - cur.open) / 2 + (prev.close - prev.open) / 2) / r * (k / l);
      result[i] = result[i - 1] + si;
    }
    return result;
  }

  double _asiR(double open, double high, double low, double prevClose) {
    final a = (high - prevClose).abs();
    final b = (low - prevClose).abs();
    final c = (high - (low - (open - prevClose).abs())).abs();
    return max(a, max(b, c));
  }

  /// PSY 心理线 — 上涨天数 / 周期 * 100
  List<double> psy(List<double> closes, int period) {
    final n = closes.length;
    final result = List<double>.filled(n, 0);
    for (int i = period; i < n; i++) {
      int upDays = 0;
      for (int j = i - period + 1; j <= i; j++) {
        if (closes[j] > closes[j - 1]) upDays++;
      }
      result[i] = upDays / period * 100;
    }
    return result;
  }

  /// CR 带状能量线 — pivot = 前一bar的(H+L+C)/3
  List<double> cr(List<double> highs, List<double> lows, List<double> closes, int period) {
    final n = closes.length;
    final pivot = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      pivot[i] = (highs[i - 1] + lows[i - 1] + closes[i - 1]) / 3;
    }
    final result = List<double>.filled(n, 0);
    for (int i = period; i < n; i++) {
      double upSum = 0, downSum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        if (pivot[j] == 0) continue;
        if (highs[j] > pivot[j]) upSum += highs[j] - pivot[j];
        if (pivot[j] > lows[j]) downSum += pivot[j] - lows[j];
      }
      result[i] = downSum == 0 ? 100 : upSum / downSum * 100;
    }
    return result;
  }

  /// DPO 去趋势价格震荡器
  List<double> dpo(List<double> closes, int period) {
    final n = closes.length;
    final maData = ma(closes, period);
    final shift = period ~/ 2 + 1;
    final result = List<double>.filled(n, 0);
    for (int i = shift; i < n; i++) {
      result[i] = closes[i] - maData[i - shift];
    }
    return result;
  }

  /// BRAR 情绪指标 — [BR, AR]
  List<List<double>> brar(List<KlineData> klines) {
    final n = klines.length;
    final br = List<double>.filled(n, 100);
    final ar = List<double>.filled(n, 100);
    const period = 26;
    for (int i = period; i < n; i++) {
      double brUp = 0, brDown = 0, arUp = 0, arDown = 0;
      for (int j = i - period + 1; j <= i; j++) {
        final prev = klines[j - 1];
        final cur = klines[j];
        if (cur.high > prev.close) brUp += cur.high - prev.close;
        if (prev.close > cur.low) brDown += prev.close - cur.low;
        arUp += max(0, cur.high - cur.open);
        arDown += max(0, cur.open - cur.low);
      }
      br[i] = brDown == 0 ? 100 : brUp / brDown * 100;
      ar[i] = arDown == 0 ? 100 : arUp / arDown * 100;
    }
    return [br, ar];
  }

  /// DFMA 平行线差指标 — [DIF, DIFMA]
  List<List<double>> dfma(List<double> closes) {
    final ma10 = ma(closes, 10);
    final ma50 = ma(closes, 50);
    final n = closes.length;
    final dif = List<double>.generate(n, (i) => ma10[i] - ma50[i]);
    final difma = ma(dif, 10);
    return [dif, difma];
  }

  /// MTM 动量指标 — [MTM, Signal]
  List<List<double>> mtm(List<double> closes, int period, int signalPeriod) {
    final n = closes.length;
    final mtmLine = List<double>.filled(n, 0);
    for (int i = period; i < n; i++) {
      mtmLine[i] = closes[i] - closes[i - period];
    }
    final signal = ma(mtmLine, signalPeriod);
    return [mtmLine, signal];
  }

  /// MASS 梅斯线 — 标准公式：Diff=EMA(H-L,9), MASS=SUM(EMA(Diff,9)/EMA(EMA(Diff,9),9), period)
  List<double> mass(List<double> highs, List<double> lows, int period1, int period2) {
    final n = highs.length;
    final diff = List<double>.generate(n, (i) => highs[i] - lows[i]);
    final ema1 = ema(diff, period1);           // EMA(H-L, 9)
    final ema2 = ema(ema1, period1);           // EMA(EMA(H-L, 9), 9) — 双平滑
    final ratio = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      ratio[i] = ema2[i] == 0 ? 0 : ema1[i] / ema2[i];
    }
    // MASS = sum(ratio, period2)
    final result = List<double>.filled(n, 0);
    for (int i = period2 - 1; i < n; i++) {
      double sum = 0;
      for (int j = i - period2 + 1; j <= i; j++) sum += ratio[j];
      result[i] = sum;
    }
    return result;
  }

  /// ROC 变动速率
  List<double> roc(List<double> closes, int period) {
    final n = closes.length;
    final result = List<double>.filled(n, 0);
    for (int i = period; i < n; i++) {
      result[i] = closes[i - period] == 0 ? 0 : (closes[i] - closes[i - period]) / closes[i - period] * 100;
    }
    return result;
  }

  /// EXPMA 指数平均数 — [Short, Long]
  List<List<double>> expma(List<double> closes, int shortPeriod, int longPeriod) {
    return [ema(closes, shortPeriod), ema(closes, longPeriod)];
  }

  /// KTN 肯特纳通道 — {upper, lower, middle}
  Map<String, List<double>> ktn(List<double> closes, List<double> highs, List<double> lows, int period, double multiplier) {
    final n = closes.length;
    final atrData = atr(highs, lows, closes, period);
    final midEma = ema(closes, period);
    final upper = List<double>.filled(n, 0);
    final lower = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      upper[i] = midEma[i] + atrData[i] * multiplier;
      lower[i] = midEma[i] - atrData[i] * multiplier;
    }
    return {'upper': upper, 'lower': lower, 'middle': midEma};
  }

  /// XSII 薛斯通道II — {a, b, c, d}
  Map<String, List<double>> xsii(List<double> closes, List<double> highs, List<double> lows) {
    final n = closes.length;
    final ma1 = ma(closes, 3);
    final ma2 = ma(closes, 9);
    final ma3 = ma(closes, 18);
    final ma4 = ma(closes, 56);
    return {'a': ma1, 'b': ma2, 'c': ma3, 'd': ma4};
  }
}
