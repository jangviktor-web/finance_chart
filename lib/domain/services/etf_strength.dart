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
///
/// score 是**纯比值**「20 日涨幅 ÷ 波动率」（规格二节口径），
/// 不归一化：它可能为负、也可能远大于 100，量纲为「涨幅/波动率」。
class EtfStrengthResult {
  final String code;
  final String name;
  final double score; // 稳强度 = 20日涨幅 / 波动率（无量纲比值）
  final double cumulativeReturn; // 20 日涨幅（小数，如 0.048 = +4.8%）
  final double volatility; // 日收益**样本**标准差（小数，已施加 0.3% 地板）
  final bool aboveMa28; // 趋势筛结果：现价是否站上 MA28
  final int rank; // 排名（非剔除项 1 起；剔除项排在后）
  final bool disqualified; // 是否被硬性剔除
  final String reason; // 剔除原因（未剔除为空串）

  const EtfStrengthResult({
    required this.code,
    required this.name,
    required this.score,
    required this.cumulativeReturn,
    required this.volatility,
    required this.aboveMa28,
    required this.rank,
    required this.disqualified,
    required this.reason,
  });

  /// 是否同时通过「买入候选」的两道筛（规格四节）。
  ///
  /// ⚠️ 与 [rank] 无关：排名照常输出全部有效标的，但能当候选的必须
  /// ① 站上 MA28（现价 ≥ `mean(c[-28:])`）且 ② 20 日涨幅 > 0。
  bool get passesBuyFilters =>
      !disqualified && aboveMa28 && cumulativeReturn > 0;

  /// 未成为买入候选的原因（已是候选或已被剔除时为空串）。
  String get blockReason {
    if (disqualified || passesBuyFilters) return '';
    if (!aboveMa28) return '跌破MA28';
    return '20日涨幅≤0';
  }
}

/// 「上榜 / 出榜」对比结果，用于调仓提示。
class EtfRotationDiff {
  final List<String> entered; // 本次新上榜（上次不在，本次在）
  final List<String> exited; // 本次出榜（上次在，本次不在）
  final bool hasBaseline; // 是否存在上次快照（首次运行为 false）

  const EtfRotationDiff({
    required this.entered,
    required this.exited,
    required this.hasBaseline,
  });

  bool get isEmpty => entered.isEmpty && exited.isEmpty;
}

/// ETF 轮动策略（《ETF 轮动 · App 对齐规格 v2》2026-09-18）。
///
/// 打分（规格二节，数据为日线**前复权**收盘序列 `c`，升序）：
/// ```
/// ret20 = (c[-1] / c[-21] - 1) × 100
/// rets  = 最后 20 个日收益率
/// vol   = std(rets, ddof=1)          // 样本标准差
/// score = ret20 / max(vol, 0.3)
/// ```
/// 即本类内部的 `score = cumulativeReturn / max(σ样本, 0.003)`
/// —— 分子分母同为「百分比」还是同为「小数」不影响比值，故沿用小数存储。
///
/// 三条硬性红线（规格三节，任一触发即剔除、分数置 0 沉底）：
///   ① 近 3 个日收益中任一天 ≤ −5% → 剔除（"刚挨过刀"）；
///   ② 20 日涨幅 > +40% → 剔除（绝对阈值，"涨太猛=别人准备走的位置"）；
///   ③ 偏离 MA20 > +12% → 剔除（乖离过高，均值回归风险）。
///
/// 买入候选的两道筛（规格四节）：趋势筛「现价 ≥ MA28」+ 收益筛「ret20 > 0」，
/// 按分数降序遍历跳过不合格者取前 [defaultTopN]；全池无一合格即「全弱空仓」。
///
/// 纯函数、可单测：无网络、无 Flutter 依赖。
class EtfRotation {
  EtfRotation._();

  /// 默认回望交易日数（规格二节：20 个交易日）。
  static const int defaultWindow = 20;

  /// 趋势筛的均线周期（规格四节：MA28）。
  static const int defaultMaTrendWindow = 28;

  /// 买入候选数量（规格四节：前 3 只）。
  static const int defaultTopN = 3;

  /// 波动率地板：0.3%（规格二节：`vol = max(vol, 0.3)`）。
  static const double minVolatility = 0.003;

  /// 红线②阈值：20 日涨幅 > +40% → 剔除（绝对阈值，非池内相对排名）。
  static const double _maxCumulativeReturn = 0.40;

  /// 红线③阈值：偏离 MA20 > +12% → 剔除。
  static const double _maxMa20Deviation = 0.12;

  /// 红线①阈值：近 3 日任一日收益 ≤ −5% → 剔除。
  ///
  /// 原为裸字面量 `-0.05`，不可发现且无文档；提成命名常量以免调整时漏改。
  static const double _maxSingleDayDrop = -0.05;

  /// MA20（红线③）的均线周期（规格明确为 20 日）。
  static const int _maWindow = 20;

  /// 对输入池做评分排名。
  ///
  /// [window] 回望交易日数，默认 20（规格口径）。
  /// [maTrendWindow] 趋势筛均线周期，默认 28（规格口径）；参数化仅为便于单测。
  /// 返回按排名排序的列表：非剔除项在前（rank 1 起，按分降序），剔除项沉底。
  static List<EtfStrengthResult> rank(
    List<EtfStrengthInput> inputs, {
    int window = defaultWindow,
    int maTrendWindow = defaultMaTrendWindow,
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
      // 算分要 window+1 根；趋势筛要 maTrendWindow 根。两者取大。
      final minBars = math.max(window + 1, maTrendWindow);
      if (klines.length < minBars) {
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

      // 波动率：日收益**样本**标准差（ddof=1，规格二节），施加 0.3% 地板。
      // 地板顺带消掉了「零波动 → 除零」，无需再对纯零波动做极值特判。
      final volatility = math.max(_sampleStd(dailyReturns), minVolatility);
      final scoreRaw = cumulativeReturn / volatility;

      final last3 = dailyReturns.length >= 3
          ? dailyReturns.sublist(dailyReturns.length - 3)
          : dailyReturns;

      // MA20 乖离（红线③）。
      double ma20Deviation = 0.0;
      final ma20 = _mean(klines, last, _maWindow);
      if (ma20 > 0) ma20Deviation = klines[last].close / ma20 - 1;

      // 趋势筛（MA28）：现价 ≥ 均值 → 才有资格进候选。
      final maTrend = _mean(klines, last, maTrendWindow);
      final aboveMaTrend = maTrend <= 0 || klines[last].close >= maTrend;

      entries.add(_Calc(
        code: input.code,
        name: input.name,
        cumulativeReturn: cumulativeReturn,
        volatility: volatility,
        scoreRaw: scoreRaw,
        hasData: true,
        last3Returns: last3,
        ma20Deviation: ma20Deviation,
        aboveMaTrend: aboveMaTrend,
      ));
    }

    // ── 第二步：硬性剔除（三条红线）──
    final valid = entries.where((e) => e.hasData).toList();

    if (valid.isNotEmpty) {
      // 红线②：20 日涨幅 > +40% → 剔除（绝对阈值）。
      // 旧版用「池内前 10%」相对阈值，低收益行情下会把温和领涨者误杀，已废弃。
      for (final e in valid) {
        if (e.cumulativeReturn > _maxCumulativeReturn) {
          e.disqualified = true;
          e.reason = '涨幅过猛(>+40%)';
        }
      }

      // 红线③：偏离 MA20 > +12% → 剔除。
      for (final e in valid) {
        if (e.ma20Deviation > _maxMa20Deviation) {
          e.disqualified = true;
          e.reason = '偏离MA20过大(>+12%)';
        }
      }

      // 红线①：近 3 个日收益中任一天 ≤ −5% → 剔除（最后写入，reason 优先级最高）
      for (final e in valid) {
        if (e.last3Returns.any((r) => r <= _maxSingleDayDrop)) {
          e.disqualified = true;
          e.reason = '近3日曾单日跌超5%';
        }
      }
    }

    // ── 第三步：最终分（剔除项置 0 作哨兵值）──
    for (final e in entries) {
      if (e.disqualified || !e.hasData) {
        e.score = 0.0;
      } else {
        e.score = e.scoreRaw;
      }
    }

    // ── 第四步：排名（非剔除在前降序，剔除沉底）──
    final qualified = entries.where((e) => !e.disqualified).toList()
      ..sort((x, y) => y.score.compareTo(x.score));
    final disqualified = entries.where((e) => e.disqualified).toList();

    final results = <EtfStrengthResult>[];
    for (int i = 0; i < qualified.length; i++) {
      final e = qualified[i];
      results.add(EtfStrengthResult(
        code: e.code,
        name: e.name,
        score: e.score,
        cumulativeReturn: e.cumulativeReturn,
        volatility: e.volatility,
        aboveMa28: e.aboveMaTrend,
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
        cumulativeReturn: e.cumulativeReturn,
        volatility: e.volatility,
        aboveMa28: false,
        rank: qualified.length + i + 1,
        disqualified: true,
        reason: e.reason,
      ));
    }
    return results;
  }

  /// 买入候选（规格四节）：按分数从高到低遍历，跳过不过筛者，取前 [topN]。
  ///
  /// [results] 需为 [rank] 的返回值（已按分降序）。返回可能为空 → 全弱空仓。
  static List<EtfStrengthResult> buyCandidates(
    List<EtfStrengthResult> results, {
    int topN = defaultTopN,
  }) {
    return results
        .where((r) => !r.disqualified && r.passesBuyFilters)
        .take(topN)
        .toList();
  }

  /// 买入候选的代码列表（按分数降序），用于调仓对比。
  static List<String> candidateCodes(
    List<EtfStrengthResult> results, {
    int topN = defaultTopN,
  }) =>
      buyCandidates(results, topN: topN).map((r) => r.code).toList();

  /// 「全弱空仓」判定（规格四节）：全池**无一只**同时满足两道筛 → 建议空仓。
  ///
  /// 池内无任何有效标的（全取数失败）时返回 false —— 那是「无数据」，
  /// 与「有数据但没有一只能买」是两种语义，不混为一谈。
  static bool suggestCash(List<EtfStrengthResult> results) {
    if (results.every((r) => r.disqualified)) return false;
    return buyCandidates(results).isEmpty;
  }

  /// 对比「本次候选」与「上次候选快照」，给出上榜 / 出榜（调仓提示）。
  ///
  /// [previous] 为空视为无基准（首次运行），返回 `hasBaseline: false`。
  static EtfRotationDiff diffTopN({
    required List<String> current,
    required List<String> previous,
  }) {
    if (previous.isEmpty) {
      return const EtfRotationDiff(entered: [], exited: [], hasBaseline: false);
    }
    final prev = previous.toSet();
    final cur = current.toSet();
    return EtfRotationDiff(
      entered: current.where((c) => !prev.contains(c)).toList(),
      exited: previous.where((c) => !cur.contains(c)).toList(),
      hasBaseline: true,
    );
  }

  /// 丢弃「今天」这根可能尚未收盘的日线（规格五节 2）。
  ///
  /// 盘中（当地 15:00 之前）上游可能已吐出当日的半根 K 线；它会同时污染
  /// ret20 与「近 3 日」红线，故在算分前剔除。收盘后（≥15:00）原样返回。
  ///
  /// [now] 仅供单测注入；生产传 null 取系统时间。
  static List<KlineData> dropTodayBar(
    List<KlineData> klines, {
    DateTime? now,
  }) {
    if (klines.isEmpty) return klines;
    final n = now ?? DateTime.now();
    if (n.hour >= 15) return klines; // 已收盘，当日 bar 为终值
    final kept = klines
        .where((k) =>
            k.time.year != n.year ||
            k.time.month != n.month ||
            k.time.day != n.day)
        .toList();
    // 保守兜底：若全部被滤掉（异常数据），原样返回而非交出空序列
    return kept.isEmpty ? klines : kept;
  }

  /// 最近 [n] 根收盘价的均值（不足 [n] 根时返回 0，调用方据此跳过该判据）。
  static double _mean(List<KlineData> klines, int last, int n) {
    if (n <= 0 || last + 1 < n) return 0.0;
    double sum = 0;
    for (int i = last - n + 1; i <= last; i++) {
      sum += klines[i].close;
    }
    return sum / n;
  }

  /// 样本标准差（ddof=1，除以 N−1）—— 规格二节 `std(rets, ddof=1)`。
  ///
  /// 与总体标准差（除以 N）只差常数因子 √(20/19)，不影响排名，
  /// 但为了让分数与规格基准逐位一致，这里必须用样本口径。
  static double _sampleStd(List<double> xs) {
    if (xs.length < 2) return 0.0;
    final mean = xs.reduce((a, b) => a + b) / xs.length;
    var sumSq = 0.0;
    for (final x in xs) {
      sumSq += (x - mean) * (x - mean);
    }
    return math.sqrt(sumSq / (xs.length - 1));
  }
}

/// 评分中间态（可变，便于池内统计后回填）。
class _Calc {
  final String code;
  final String name;
  final bool hasData;

  double cumulativeReturn = 0.0;
  double volatility = 0.0;
  double scoreRaw = 0.0;
  double score = 0.0;
  final double ma20Deviation;
  final bool aboveMaTrend;
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
    this.volatility = 0.0,
    this.scoreRaw = 0.0,
    this.ma20Deviation = 0.0,
    this.aboveMaTrend = false,
    List<double>? last3Returns,
  }) : last3Returns = last3Returns ?? const [];
}
