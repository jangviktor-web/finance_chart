import '../../data/models/kline_data.dart';
import '../../data/models/indicator_data.dart';
import '../../data/models/stock_score.dart';

/// 多维评分引擎 — 纯 Dart 计算，无需网络
class ScoringEngine {
  /// 计算单只股票的 5 维评分
  static StockScore calculate({
    required String code,
    required String name,
    required List<KlineData> klines,
    required IndicatorData indicators,
  }) {
    if (klines.isEmpty) {
      return StockScore(
        code: code, name: name,
        valuation: 50, momentum: 50, volatility: 50, trend: 50, volume: 50,
      );
    }

    return StockScore(
      code: code,
      name: name,
      valuation: _calcValuation(klines, indicators),
      momentum: _calcMomentum(indicators),
      volatility: _calcVolatility(klines, indicators),
      trend: _calcTrend(klines, indicators),
      volume: _calcVolume(klines, indicators),
    );
  }

  /// 估值：BOLL 位置 + RSI 超卖加分
  static double _calcValuation(List<KlineData> klines, IndicatorData ind) {
    double score = 50;
    final close = klines.last.close;

    // BOLL 位置：下轨附近=低估(高分)，上轨附近=高估(低分)
    if (ind.bollLower.isNotEmpty && ind.bollUpper.isNotEmpty) {
      final lower = ind.bollLower.last;
      final upper = ind.bollUpper.last;
      final range = upper - lower;
      if (range > 0) {
        final position = (close - lower) / range; // 0=下轨, 1=上轨
        // 越接近下轨分越高（低估），越接近上轨分越低（高估）
        score = (1 - position) * 60 + 20;
      }
    }

    // RSI 超卖加分
    if (ind.rsi.isNotEmpty) {
      final rsi = ind.rsi.last;
      if (rsi < 30) score += 15;      // 超卖，加分
      else if (rsi < 40) score += 8;
      else if (rsi > 70) score -= 15; // 超买，减分
      else if (rsi > 60) score -= 8;
    }

    return _clamp(score);
  }

  /// 动量：ROC + MTM + KDJ
  static double _calcMomentum(IndicatorData ind) {
    double score = 50;

    // ROC 变动速率
    if (ind.roc != null && ind.roc!.isNotEmpty) {
      final roc = ind.roc!.last;
      if (roc > 5) score += 20;
      else if (roc > 2) score += 12;
      else if (roc > 0) score += 5;
      else if (roc < -5) score -= 20;
      else if (roc < -2) score -= 12;
      else score -= 5;
    }

    // MTM 动量
    if (ind.mtm != null && ind.mtm!.isNotEmpty) {
      final mtm = ind.mtm!.last;
      if (mtm > 0) score += 10;
      else score -= 10;
    }

    // KDJ 金叉/死叉
    if (ind.k.isNotEmpty && ind.d.isNotEmpty) {
      final k = ind.k.last;
      final d = ind.d.last;
      if (k > d && k < 80) score += 10;  // 金叉且未超买
      else if (k < d && k > 20) score -= 10; // 死叉且未超卖
    }

    return _clamp(score);
  }

  /// 波动：ATR/价格 + BOLL 带宽（低波动高分）
  static double _calcVolatility(List<KlineData> klines, IndicatorData ind) {
    double score = 50;
    final close = klines.last.close;
    if (close <= 0) return score;

    // ATR/价格比 — 波动率
    if (ind.atr != null && ind.atr!.isNotEmpty) {
      final atrPct = ind.atr!.last / close * 100;
      if (atrPct < 1.5) score += 20;       // 低波动
      else if (atrPct < 3) score += 10;
      else if (atrPct > 6) score -= 20;    // 高波动
      else if (atrPct > 4) score -= 10;
    }

    // BOLL 带宽 — 收窄=蓄势
    if (ind.bollUpper.isNotEmpty && ind.bollLower.isNotEmpty && ind.bollMid.isNotEmpty) {
      final bandwidth = (ind.bollUpper.last - ind.bollLower.last) / ind.bollMid.last * 100;
      if (bandwidth < 5) score += 15;      // 极度收窄
      else if (bandwidth < 10) score += 8;
      else if (bandwidth > 20) score -= 10;
    }

    return _clamp(score);
  }

  /// 趋势：MA 排列 + MACD + DMI
  static double _calcTrend(List<KlineData> klines, IndicatorData ind) {
    double score = 50;

    // MA 多头排列：MA5 > MA10 > MA20 > MA60
    if (ind.maLines.length >= 4) {
      final ma5 = ind.maLines[0];
      final ma10 = ind.maLines[1];
      final ma20 = ind.maLines[2];
      final ma60 = ind.maLines[3];
      if (ma5.isNotEmpty && ma10.isNotEmpty && ma20.isNotEmpty && ma60.isNotEmpty) {
        int bullCount = 0;
        if (ma5.last > ma10.last) bullCount++;
        if (ma10.last > ma20.last) bullCount++;
        if (ma20.last > ma60.last) bullCount++;
        // 3=多头排列, 0=空头排列
        score += (bullCount - 1) * 10; // -10, 0, +10, +20
      }
    }

    // MACD 柱状图方向
    if (ind.macdHist.length >= 2) {
      final curr = ind.macdHist.last;
      final prev = ind.macdHist[ind.macdHist.length - 2];
      if (curr > 0 && curr > prev) score += 12;       // 红柱放大
      else if (curr > 0) score += 5;                   // 红柱
      else if (curr < 0 && curr < prev) score -= 12;   // 绿柱放大
      else score -= 5;                                  // 绿柱
    }

    // DMI ADX 趋势强度
    if (ind.dmi != null) {
      final adx = ind.dmi!['adx'];
      final pdi = ind.dmi!['pdi'];
      final mdi = ind.dmi!['mdi'];
      if (adx != null && adx.isNotEmpty && pdi != null && pdi.isNotEmpty && mdi != null && mdi.isNotEmpty) {
        if (adx.last > 25 && pdi.last > mdi.last) score += 10; // 强上升趋势
        else if (adx.last > 25 && pdi.last < mdi.last) score -= 10; // 强下降趋势
      }
    }

    // 价格在 MA20 之上
    if (klines.isNotEmpty && ind.maLines.length >= 3 && ind.maLines[2].isNotEmpty) {
      if (klines.last.close > ind.maLines[2].last) score += 5;
      else score -= 5;
    }

    return _clamp(score);
  }

  /// 量能：OBV 趋势 + MFI + 成交量变化
  static double _calcVolume(List<KlineData> klines, IndicatorData ind) {
    double score = 50;

    // OBV 趋势：5日线性回归斜率
    if (ind.obv != null && ind.obv!.length >= 5) {
      final recent = ind.obv!.sublist(ind.obv!.length - 5);
      final slope = _linearSlope(recent);
      if (slope > 0) score += 15;
      else score -= 15;
    }

    // MFI 资金流量
    if (ind.mfi != null && ind.mfi!.isNotEmpty) {
      final mfi = ind.mfi!.last;
      if (mfi > 80) score += 10;       // 资金强势
      else if (mfi > 50) score += 5;
      else if (mfi < 20) score -= 10;  // 资金弱势
      else score -= 5;
    }

    // 成交量放大（近5日 vs 近20日）
    if (klines.length >= 20) {
      double avg5 = 0, avg20 = 0;
      for (int i = klines.length - 5; i < klines.length; i++) {
        avg5 += klines[i].volume;
      }
      for (int i = klines.length - 20; i < klines.length; i++) {
        avg20 += klines[i].volume;
      }
      avg5 /= 5;
      avg20 /= 20;
      if (avg20 > 0) {
        final ratio = avg5 / avg20;
        if (ratio > 1.5) score += 10;   // 明显放量
        else if (ratio > 1.1) score += 5;
        else if (ratio < 0.6) score -= 10; // 严重缩量
        else if (ratio < 0.8) score -= 5;
      }
    }

    return _clamp(score);
  }

  /// 简单线性回归斜率
  static double _linearSlope(List<double> values) {
    final n = values.length;
    if (n < 2) return 0;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return 0;
    return (n * sumXY - sumX * sumY) / denom;
  }

  static double _clamp(double v) => v.clamp(0, 100);
}
