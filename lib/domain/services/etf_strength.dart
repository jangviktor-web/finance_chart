import 'dart:math' as math;

import '../../data/models/kline_data.dart';

/// ETF 轮动「稳强度」评分的输入项。
class EtfStrengthInput {
  final String code;
  final String name;
  final List<KlineData> klines;

  const EtfStrengthInput({
    required this.code,
    required this.name,
    required this.klines,
  });
}

/// ETF 轮动「稳强度」评分的输出项。
class EtfStrengthResult {
  final String code;
  final String name;
  final double score; // 最终分 0–100
  final double a; // 风险调整收益分量 0–100
  final double b; // 上涨天数占比 0–100
  final int rank; // 排名（非剔除项 1 起；剔除项排在后）
  final bool disqualified; // 是否被硬性剔除
  final String reason; // 剔除原因（未剔除为空串）

  const EtfStrengthResult({
    required this.code,
    required this.name,
    required this.score,
    required this.a,
    required this.b,
    required this.rank,
    required this.disqualified,
    required this.reason,
  });
}

/// ETF 轮动策略：约 N 只 ETF 池中，按「过去约 window 个交易日的稳强度」打分取前三。
///
/// 「稳」≠「强」：对累计收益按波动率做了惩罚（风险调整收益分量 A）。
/// 硬性剔除（打分前判，分数置 0 沉底）：
///   1) 近 3 个日收益中任一天 ≤ −5% → 剔除；
///   2) 累计收益处于池内前 10%（分位 ≥ 90）→ 剔除（池子 < 10 只时跳过）。
///
/// 纯函数、可单测：无网络、无 Flutter 依赖。
class EtfRotation {
  EtfRotation._();

  /// 对输入池做评分排名。
  ///
  /// [window] 回望交易日数，默认 22（约一个月交易日）。
  /// 返回按排名排序的列表：非剔除项在前（rank 1 起，按分降序），剔除项沉底。
  static List<EtfStrengthResult> rank(
    List<EtfStrengthInput> inputs, {
    int window = 22,
  }) {
    final entries = <_Calc>[];

    // ── 第一步：逐只计算原始指标 ──
    for (final input in inputs) {
      final klines = input.klines;

      if (klines.isEmpty) {
        entries.add(_Calc(
          code: input.code,
          name: input.name,
          disqualified: true,
          reason: '无行情数据',
        ));
        continue;
      }
      if (klines.length < window + 1) {
        entries.add(_Calc(
          code: input.code,
          name: input.name,
          disqualified: true,
          reason: '数据不足',
        ));
        continue;
      }

      final last = klines.length - 1;
      final cumulativeReturn = klines[last].close / klines[last - window].close - 1;

      final dailyReturns = <double>[];
      for (int i = last - window + 1; i <= last; i++) {
        dailyReturns.add(klines[i].close / klines[i - 1].close - 1);
      }

      final std = _populationStd(dailyReturns);
      // std≈0 时 riskAdjRaw 取 0，防止除以极小值爆炸
      final riskAdjRaw = std < 1e-6 ? 0.0 : cumulativeReturn / std;

      final upDays = dailyReturns.where((r) => r > 0).length;
      final b = upDays / window * 100;

      final last3 = dailyReturns.length >= 3
          ? dailyReturns.sublist(dailyReturns.length - 3)
          : dailyReturns;

      entries.add(_Calc(
        code: input.code,
        name: input.name,
        cumulativeReturn: cumulativeReturn,
        riskAdjRaw: riskAdjRaw,
        b: b,
        hasData: true,
        last3Returns: last3,
      ));
    }

    // ── 第二步：池内统计 + 硬性剔除 ──
    final valid = entries.where((e) => e.hasData).toList();

    if (valid.isNotEmpty) {
      // A 分量：对池内 riskAdjRaw 做 z-score，再缩放到 0–100（均值≈50）
      final rawValues = valid.map((e) => e.riskAdjRaw).toList();
      final mean = rawValues.reduce((a, b) => a + b) / rawValues.length;
      final std = _populationStd(rawValues);
      for (final e in valid) {
        final z = std < 1e-9 ? 0.0 : (e.riskAdjRaw - mean) / std;
        e.a = (50 + 10 * z).clamp(0.0, 100.0).toDouble();
      }

      // 规则 2：累计收益处于池内前 10%（分位 ≥ 90）→ 剔除（池子 < 10 只跳过）
      if (valid.length >= 10) {
        final sortedDesc = [...valid]
          ..sort((x, y) => y.cumulativeReturn.compareTo(x.cumulativeReturn));
        final k = (valid.length * 0.1).ceil();
        final cutoff = sortedDesc[k - 1].cumulativeReturn;
        for (final e in valid) {
          if (e.cumulativeReturn >= cutoff && !e.disqualified) {
            e.disqualified = true;
            e.reason = '短期涨幅过猛(池内前10%)';
          }
        }
      }

      // 规则 1：近 3 个日收益中任一天 ≤ −5% → 剔除（优先级高于规则 2）
      for (final e in valid) {
        if (e.last3Returns.any((r) => r <= -0.05)) {
          e.disqualified = true;
          e.reason = '近3日曾单日跌超5%';
        }
      }
    }

    // ── 第三步：最终分 ──
    for (final e in entries) {
      if (e.disqualified) {
        e.score = 0.0;
      } else if (e.hasData) {
        e.score = (0.7 * e.a + 0.3 * e.b).clamp(0.0, 100.0).toDouble();
      } else {
        e.score = 0.0;
      }
    }

    // ── 第四步：排名（非剔除在前降序，剔除沉底）──
    final qualified = entries.where((e) => !e.disqualified).toList()
      ..sort((x, y) => y.score.compareTo(x.score));
    final disqualified =
        entries.where((e) => e.disqualified).toList();

    final results = <EtfStrengthResult>[];
    for (int i = 0; i < qualified.length; i++) {
      final e = qualified[i];
      results.add(EtfStrengthResult(
        code: e.code,
        name: e.name,
        score: e.score,
        a: e.a,
        b: e.b,
        rank: i + 1,
        disqualified: false,
        reason: '',
      ));
    }
    for (int i = 0; i < disqualified.length; i++) {
      final e = disqualified[i];
      results.add(EtfStrengthResult(
        code: e.code,
        name: e.name,
        score: 0.0,
        a: e.a,
        b: e.b,
        rank: qualified.length + i + 1,
        disqualified: true,
        reason: e.reason,
      ));
    }
    return results;
  }

  /// 总体标准差（除以 N）。
  static double _populationStd(List<double> xs) {
    if (xs.isEmpty) return 0.0;
    final mean = xs.reduce((a, b) => a + b) / xs.length;
    var sumSq = 0.0;
    for (final x in xs) {
      sumSq += (x - mean) * (x - mean);
    }
    return math.sqrt(sumSq / xs.length);
  }
}

/// 评分中间态（可变，便于池内统计后回填）。
class _Calc {
  final String code;
  final String name;
  final bool hasData;

  double cumulativeReturn = 0.0;
  double riskAdjRaw = 0.0;
  double b = 0.0;
  double a = 0.0;
  double score = 0.0;
  late final List<double> last3Returns;

  bool disqualified;
  String reason;

  _Calc({
    required this.code,
    required this.name,
    this.hasData = false,
    this.disqualified = false,
    this.reason = '',
    this.cumulativeReturn = 0.0,
    this.riskAdjRaw = 0.0,
    this.b = 0.0,
    List<double>? last3Returns,
  }) : last3Returns = last3Returns ?? const [];
}
