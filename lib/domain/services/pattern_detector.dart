import 'dart:math';
import 'dart:ui';
import '../../data/models/kline_data.dart';
import '../../data/models/pattern_result.dart';

/// 形态检测服务 — 基于 Zigzag 枢轴点
class PatternDetector {
  /// 检测所有形态
  List<PatternResult> detectAll(List<KlineData> klines) {
    if (klines.length < 30) return [];

    final pivots = _zigzag(klines, threshold: 0.05);
    if (pivots.length < 4) return [];

    final results = <PatternResult>[];

    // 按检测优先级运行
    results.addAll(_detectWBottom(klines, pivots));
    results.addAll(_detectTripleBottom(klines, pivots));
    results.addAll(_detectVReversal(klines, pivots));
    results.addAll(_detectCupHandle(klines, pivots));
    results.addAll(_detectDipBuy(klines, pivots));
    results.addAll(_detectHeadShoulder(klines, pivots));

    // 按置信度排序
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  // ════════════════════════════════════════════
  //  Zigzag 枢轴检测
  // ════════════════════════════════════════════

  /// Zigzag 枢轴点检测
  /// 返回 (index, price, isLow) 的列表
  List<_Pivot> _zigzag(List<KlineData> klines, {double threshold = 0.05}) {
    if (klines.isEmpty) return [];

    final pivots = <_Pivot>[];
    double lastPivotPrice = klines[0].close;
    bool lookingForLow = true;
    int lastPivotIdx = 0;

    for (int i = 1; i < klines.length; i++) {
      final change = (klines[i].close - lastPivotPrice) / lastPivotPrice;

      if (lookingForLow) {
        if (klines[i].close < lastPivotPrice) {
          lastPivotPrice = klines[i].close;
          lastPivotIdx = i;
        } else if (change > threshold) {
          // 找到低点，转为找高点
          pivots.add(_Pivot(lastPivotIdx, lastPivotPrice, true));
          lastPivotPrice = klines[i].close;
          lastPivotIdx = i;
          lookingForLow = false;
        }
      } else {
        if (klines[i].close > lastPivotPrice) {
          lastPivotPrice = klines[i].close;
          lastPivotIdx = i;
        } else if (change.abs() > threshold) {
          // 找到高点，转为找低点
          pivots.add(_Pivot(lastPivotIdx, lastPivotPrice, false));
          lastPivotPrice = klines[i].close;
          lastPivotIdx = i;
          lookingForLow = true;
        }
      }
    }
    // 添加最后一个枢轴
    pivots.add(_Pivot(lastPivotIdx, lastPivotPrice, lookingForLow));

    return pivots;
  }

  // ════════════════════════════════════════════
  //  形态检测器
  // ════════════════════════════════════════════

  /// W底 — 两个相近低点 + 颈线突破
  List<PatternResult> _detectWBottom(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];
    final lows = pivots.where((p) => p.isLow).toList();
    final highs = pivots.where((p) => !p.isLow).toList();

    for (int i = 0; i < lows.length - 1; i++) {
      for (int j = i + 1; j < lows.length; j++) {
        final low1 = lows[i];
        final low2 = lows[j];

        // 两个低点价格相近 (差距 < 3%)
        final lowDiff = (low1.price - low2.price).abs() / low1.price;
        if (lowDiff > 0.03) continue;

        // 两个低点间距至少 10 根 K 线
        if ((low2.index - low1.index) < 10) continue;

        // 中间必须有高点（颈线）
        final midHighs = highs.where((h) => h.index > low1.index && h.index < low2.index).toList();
        if (midHighs.isEmpty) continue;

        final neckline = midHighs.map((h) => h.price).reduce(max);
        final necklineIdx = midHighs.firstWhere((h) => h.price == neckline).index;

        // 计算置信度
        double confidence = 0.5;
        // 第二个低点略高于第一个 → 更强
        if (low2.price > low1.price * 0.98) confidence += 0.1;
        // 颈线突破
        if (low2.index + 1 < klines.length && klines[low2.index + 1].close > neckline) confidence += 0.2;
        // 时间跨度合理
        if (low2.index - low1.index > 15) confidence += 0.1;

        final pivotPoints = [
          Offset(low1.index.toDouble(), low1.price),
          Offset(necklineIdx.toDouble(), neckline),
          Offset(low2.index.toDouble(), low2.price),
        ];

        results.add(PatternResult(
          type: PatternType.wBottom,
          name: 'W底（双重底）',
          description: '两个相近低点形成支撑，颈线突破后看涨',
          confidence: confidence.clamp(0, 1),
          startIndex: low1.index,
          endIndex: low2.index,
          pivotPoints: pivotPoints,
          isBullish: true,
        ));
      }
    }
    return results;
  }

  /// V型反转 — 急跌急涨 + 放量
  List<PatternResult> _detectVReversal(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];

    for (int i = 1; i < pivots.length - 1; i++) {
      final prev = pivots[i - 1];
      final cur = pivots[i];
      final next = pivots[i + 1];

      // 必须是 高→低→高 的结构
      if (prev.isLow || !cur.isLow || next.isLow) continue;

      // 下跌幅度 > 8%
      final drop = (prev.price - cur.price) / prev.price;
      if (drop < 0.08) continue;

      // 反弹幅度 > 下跌的 60%
      final rebound = (next.price - cur.price) / (prev.price - cur.price);
      if (rebound < 0.6) continue;

      // 检查是否放量
      double confidence = 0.4;
      if (cur.index > 0) {
        final avgVol = klines.sublist(max(0, cur.index - 10), cur.index)
            .map((k) => k.volume).fold(0.0, (a, b) => a + b) / 10;
        if (klines[cur.index].volume > avgVol * 1.5) confidence += 0.2;
      }

      // 快速反转（5-15 根 K 线）
      final duration = next.index - prev.index;
      if (duration >= 5 && duration <= 15) confidence += 0.2;

      results.add(PatternResult(
        type: PatternType.vReversal,
        name: 'V型反转',
        description: '急跌后快速反弹，成交量放大确认反转',
        confidence: confidence.clamp(0, 1),
        startIndex: prev.index,
        endIndex: next.index,
        pivotPoints: [
          Offset(prev.index.toDouble(), prev.price),
          Offset(cur.index.toDouble(), cur.price),
          Offset(next.index.toDouble(), next.price),
        ],
        isBullish: true,
      ));
    }
    return results;
  }

  /// 杯柄形态 — U型底 + 右侧小回调
  List<PatternResult> _detectCupHandle(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];
    final lows = pivots.where((p) => p.isLow).toList();
    final highs = pivots.where((p) => !p.isLow).toList();

    for (int i = 0; i < lows.length; i++) {
      final cupBottom = lows[i];

      // 找杯口左右的高点
      final leftHighs = highs.where((h) => h.index < cupBottom.index && h.index > cupBottom.index - 60).toList();
      final rightHighs = highs.where((h) => h.index > cupBottom.index && h.index < cupBottom.index + 60).toList();
      if (leftHighs.isEmpty || rightHighs.isEmpty) continue;

      final leftRim = leftHighs.reduce((a, b) => a.price > b.price ? a : b);
      final rightRim = rightHighs.reduce((a, b) => a.price > b.price ? a : b);

      // 杯口两端价格相近
      final rimDiff = (leftRim.price - rightRim.price).abs() / leftRim.price;
      if (rimDiff > 0.05) continue;

      // 杯底深度合理 (10%-35%)
      final cupDepth = (leftRim.price - cupBottom.price) / leftRim.price;
      if (cupDepth < 0.10 || cupDepth > 0.35) continue;

      // 杯的持续时间 (20-60 根 K 线)
      final cupDuration = rightRim.index - leftRim.index;
      if (cupDuration < 20 || cupDuration > 60) continue;

      double confidence = 0.5;
      // U型底比 V 型底更好
      final bottomArea = klines.sublist(max(0, cupBottom.index - 3), min(klines.length, cupBottom.index + 4));
      final nearBottom = bottomArea.where((k) => (k.close - cupBottom.price).abs() / cupBottom.price < 0.02).length;
      if (nearBottom >= 3) confidence += 0.15;

      // 右侧是否有小回调（柄）
      final handleHighs = rightHighs.where((h) => h.index > rightRim.index - 5).toList();
      if (handleHighs.isNotEmpty) confidence += 0.1;

      results.add(PatternResult(
        type: PatternType.cupHandle,
        name: '杯柄形态',
        description: 'U型底部形成杯体，右侧小回调形成杯柄，看涨延续',
        confidence: confidence.clamp(0, 1),
        startIndex: leftRim.index,
        endIndex: rightRim.index,
        pivotPoints: [
          Offset(leftRim.index.toDouble(), leftRim.price),
          Offset(cupBottom.index.toDouble(), cupBottom.price),
          Offset(rightRim.index.toDouble(), rightRim.price),
        ],
        isBullish: true,
      ));
    }
    return results;
  }

  /// 三重底 — 三个相近低点 + 阻力突破
  List<PatternResult> _detectTripleBottom(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];
    final lows = pivots.where((p) => p.isLow).toList();

    for (int i = 0; i < lows.length - 2; i++) {
      final l1 = lows[i];
      final l2 = lows[i + 1];
      final l3 = lows[i + 2];

      // 三个低点价格相近 (差距 < 4%)
      final avgLow = (l1.price + l2.price + l3.price) / 3;
      if ((l1.price - avgLow).abs() / avgLow > 0.04) continue;
      if ((l2.price - avgLow).abs() / avgLow > 0.04) continue;
      if ((l3.price - avgLow).abs() / avgLow > 0.04) continue;

      // 间距合理
      if (l2.index - l1.index < 8 || l3.index - l2.index < 8) continue;

      // 中间必须有反弹高点
      final midHighs = pivots.where((p) => !p.isLow && p.index > l1.index && p.index < l3.index).toList();
      if (midHighs.length < 2) continue;

      double confidence = 0.55;
      // 三个低点逐步抬高 → 更强
      if (l3.price >= l2.price && l2.price >= l1.price) confidence += 0.15;

      results.add(PatternResult(
        type: PatternType.tripleBottom,
        name: '三重底',
        description: '三次测试支撑均获支撑，突破阻力后看涨',
        confidence: confidence.clamp(0, 1),
        startIndex: l1.index,
        endIndex: l3.index,
        pivotPoints: [
          Offset(l1.index.toDouble(), l1.price),
          Offset(l2.index.toDouble(), l2.price),
          Offset(l3.index.toDouble(), l3.price),
        ],
        isBullish: true,
      ));
    }
    return results;
  }

  /// 回踩买入 — 跌至支撑位 + 缩量
  List<PatternResult> _detectDipBuy(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];
    final n = klines.length;
    if (n < 60) return results;

    // 计算 MA20
    final ma20 = List<double>.filled(n, 0);
    for (int i = 19; i < n; i++) {
      double sum = 0;
      for (int j = i - 19; j <= i; j++) sum += klines[j].close;
      ma20[i] = sum / 20;
    }

    // 检查最近是否有回踩 MA20 的情况
    final lookback = min(20, pivots.length);
    for (int i = pivots.length - lookback; i < pivots.length; i++) {
      if (i < 0) continue;
      final pivot = pivots[i];
      if (!pivot.isLow) continue;

      // 低点接近 MA20 (差距 < 2%)
      if (pivot.index >= n || ma20[pivot.index] == 0) continue;
      final distToMA = (pivot.price - ma20[pivot.index]).abs() / ma20[pivot.index];
      if (distToMA > 0.02) continue;

      // 检查缩量
      double confidence = 0.4;
      if (pivot.index >= 5) {
        final avgVol = klines.sublist(max(0, pivot.index - 10), pivot.index)
            .map((k) => k.volume).fold(0.0, (a, b) => a + b) / 10;
        if (klines[pivot.index].volume < avgVol * 0.7) confidence += 0.2;
      }

      // 前期有上涨趋势
      if (pivot.index >= 20) {
        if (klines[pivot.index].close > klines[pivot.index - 20].close * 1.05) confidence += 0.15;
      }

      results.add(PatternResult(
        type: PatternType.dipBuy,
        name: '回踩买入',
        description: '价格回踩均线支撑位，缩量企稳，逢低买入机会',
        confidence: confidence.clamp(0, 1),
        startIndex: max(0, pivot.index - 10),
        endIndex: pivot.index,
        pivotPoints: [
          Offset(pivot.index.toDouble(), pivot.price),
          Offset(pivot.index.toDouble(), ma20[pivot.index]),
        ],
        isBullish: true,
      ));
    }
    return results;
  }

  /// 头肩顶 — 三峰中峰最高 + 颈线跌破
  List<PatternResult> _detectHeadShoulder(List<KlineData> klines, List<_Pivot> pivots) {
    final results = <PatternResult>[];
    final highs = pivots.where((p) => !p.isLow).toList();

    for (int i = 0; i < highs.length - 2; i++) {
      final leftShoulder = highs[i];
      final head = highs[i + 1];
      final rightShoulder = highs[i + 2];

      // 头部必须最高
      if (head.price <= leftShoulder.price || head.price <= rightShoulder.price) continue;

      // 两肩高度相近
      final shoulderDiff = (leftShoulder.price - rightShoulder.price).abs() / leftShoulder.price;
      if (shoulderDiff > 0.05) continue;

      // 间距合理
      if (head.index - leftShoulder.index < 5 || rightShoulder.index - head.index < 5) continue;

      // 找颈线（两个低点）
      final lowsBetween = pivots.where((p) =>
          p.isLow && p.index > leftShoulder.index && p.index < rightShoulder.index).toList();
      if (lowsBetween.length < 2) continue;

      final neckline = (lowsBetween[0].price + lowsBetween[1].price) / 2;

      double confidence = 0.5;
      // 两肩几乎等高
      if (shoulderDiff < 0.02) confidence += 0.15;
      // 头部明显高于两肩
      final headAbove = (head.price - leftShoulder.price) / leftShoulder.price;
      if (headAbove > 0.03) confidence += 0.1;

      results.add(PatternResult(
        type: PatternType.headShoulder,
        name: '头肩顶',
        description: '三峰形态，中峰最高，颈线跌破后看跌',
        confidence: confidence.clamp(0, 1),
        startIndex: leftShoulder.index,
        endIndex: rightShoulder.index,
        pivotPoints: [
          Offset(leftShoulder.index.toDouble(), leftShoulder.price),
          Offset(head.index.toDouble(), head.price),
          Offset(rightShoulder.index.toDouble(), rightShoulder.price),
        ],
        isBullish: false,
      ));
    }
    return results;
  }
}

/// 枢轴点
class _Pivot {
  final int index;
  final double price;
  final bool isLow;

  const _Pivot(this.index, this.price, this.isLow);
}
