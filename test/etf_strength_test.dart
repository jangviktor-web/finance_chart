import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_chart/data/models/kline_data.dart';
import 'package:finance_chart/domain/services/etf_strength.dart';

/// 由收盘价序列构造 KlineData 列表（open=high=low=close，便于只验证 close 逻辑）。
/// 第 i 根时间为 2024-01-01 + i 天，供 [EtfRotation.dropTodayBar] 用例使用。
List<KlineData> _klines(List<double> closes) {
  return [
    for (int i = 0; i < closes.length; i++)
      KlineData(
        time: DateTime(2024, 1, 1).add(Duration(days: i)),
        open: closes[i],
        close: closes[i],
        high: closes[i],
        low: closes[i],
        volume: 0,
      ),
  ];
}

EtfStrengthInput _input(String code, List<double> closes) =>
    EtfStrengthInput(code: code, name: code, klines: _klines(closes));

/// 按每期固定收益率 r 生成 n 根收盘价（复利）。
List<double> _grow(double r, int n) {
  final c = <double>[];
  double p = 100;
  for (int i = 0; i < n; i++) {
    c.add(p);
    p *= (1 + r);
  }
  return c;
}

/// 45 根：24 根 130 → 1 根 100 → 20 根 104。
///
/// 用于「趋势筛」：ret20 = 104/100−1 = **+4%**（收益筛通过），
/// 但 MA28 = (7×130 + 100 + 20×104)/28 = 110.36 > 104 ⇒ **跌破 MA28**。
List<double> _belowMa28ButPositive() => [
      ...List.filled(24, 130.0),
      100.0,
      ...List.filled(20, 104.0),
    ];

/// 45 根：24 根 100 → 1 根 120 → 20 根 108。
///
/// 用于「收益筛」：MA28 = (7×100 + 120 + 20×108)/28 = 106.43 < 108 ⇒ **站上 MA28**，
/// 但 ret20 = 108/120−1 = **−10%** ⇒ 收益筛不过。
List<double> _aboveMa28ButNegative() => [
      ...List.filled(24, 100.0),
      120.0,
      ...List.filled(20, 108.0),
    ];

void main() {
  // ── 规格一/二/四节：常量口径 ──
  test('常量口径：窗口 20 / 趋势筛 MA28 / 候选 3 / 波动率地板 0.3%', () {
    expect(EtfRotation.defaultWindow, 20);
    expect(EtfRotation.defaultMaTrendWindow, 28);
    expect(EtfRotation.defaultTopN, 3);
    expect(EtfRotation.minVolatility, 0.003);
  });

  // ── 规格二节：波动率必须用样本标准差（ddof=1），不是总体标准差 ──
  test('波动率取样本标准差(ddof=1)：数值与总体标准差可区分', () {
    // 收盘 100 → 102 → 102 → 104.04 → 104.04 → 106.1208
    // 日收益 = [+2%, 0, +2%, 0, +2%]；20 日涨幅 = +6.1208%
    final r = EtfRotation.rank(
      [_input('S', [100, 102, 102, 104.04, 104.04, 106.1208])],
      window: 5,
      maTrendWindow: 5,
    ).single;

    expect(r.disqualified, isFalse);
    // 样本 std = sqrt(4.8e-4/4) = 0.0109545；总体 std = sqrt(4.8e-4/5) = 0.0097980
    expect(r.volatility, closeTo(0.0109545, 1e-6));
    expect(r.volatility, isNot(closeTo(0.0097980, 1e-5)));
    expect(r.cumulativeReturn, closeTo(0.061208, 1e-6));
    // score = 0.061208 / 0.0109545 ≈ 5.588（若用总体标准差则为 6.247）
    expect(r.score, closeTo(5.588, 0.01));
  });

  // ── 排序正确性：「稳」强于「猛」──
  test('稳强度排序：低波动上行 > 高波动 > 下行', () {
    final steadyUp = _input('A', [100, 101, 102, 103, 104, 105]);
    final declining = _input('B', [100, 99, 98, 97, 96, 95]);
    final volatile = _input('C', [100, 130, 95, 105, 107, 108]);

    final results = EtfRotation.rank([steadyUp, declining, volatile],
        window: 5, maTrendWindow: 5);

    expect(results.every((r) => !r.disqualified), isTrue);
    expect(results[0].code, 'A');
    expect(results[1].code, 'C');
    expect(results[2].code, 'B');
    for (int i = 1; i < results.length; i++) {
      expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
    }
    expect(results[0].rank, 1);
    expect(results[2].rank, 3);
  });

  // ── 红线①：近 3 日单日跌超 5% ──
  test('红线①：近3日曾单日跌超5% 被剔除且分数为0', () {
    final bad = _input('X', [100, 100, 100, 100, 94, 100]);
    final steadyUp = _input('A', [100, 101, 102, 103, 104, 105]);
    final volatile = _input('C', [100, 130, 95, 105, 107, 108]);

    final results = EtfRotation.rank([bad, steadyUp, volatile],
        window: 5, maTrendWindow: 5);
    final x = results.firstWhere((r) => r.code == 'X');

    expect(x.disqualified, isTrue);
    expect(x.score, 0.0);
    expect(x.reason, contains('跌超5%'));
    expect(results.where((r) => r.code != 'X').every((r) => !r.disqualified),
        isTrue);
  });

  // ── 红线②：20 日涨幅 > +40% 剔除（绝对阈值）；温和领涨不再被误杀 ──
  test('红线②：涨幅>+40% 被剔除，温和领涨者不被误杀', () {
    final inputs = <EtfStrengthInput>[
      for (int j = 0; j < 11; j++) _input('E$j', _grow(0.001 * (j + 1), 6)),
      _input('HOT', _grow(0.08, 6)), // 5 期累计 +46.9% > +40%
    ];

    final results =
        EtfRotation.rank(inputs, window: 5, maTrendWindow: 5);
    final hot = results.firstWhere((r) => r.code == 'HOT');
    final leader = results.firstWhere((r) => r.code == 'E10');

    expect(hot.disqualified, isTrue);
    expect(hot.reason, contains('涨幅过猛'));
    expect(hot.score, 0.0);
    // 关键回归：旧「池内前10%」会把涨幅最高的温和标的踢掉，现在不会
    expect(leader.disqualified, isFalse);
  });

  // ── 红线③：偏离 MA20 > +12% ──
  test('红线③：偏离MA20>+12% 被剔除', () {
    final spike = _input('SP', [for (int i = 0; i < 20; i++) 100.0, 120.0]);
    final flat = _input('FL', [for (int i = 0; i < 21; i++) 100.0]);

    final results = EtfRotation.rank([spike, flat], window: 5, maTrendWindow: 5);
    final s = results.firstWhere((r) => r.code == 'SP');
    final f = results.firstWhere((r) => r.code == 'FL');

    expect(s.disqualified, isTrue);
    expect(s.reason, contains('MA20'));
    expect(s.score, 0.0);
    expect(f.disqualified, isFalse);
  });

  // ── 边界语义：②③ 严格大于，① 含等号 ──
  test('红线边界：② >+40% 严格、③ >+12% 严格、① ≤-5% 含等号', () {
    final over2 = _input('R2A', [100, 100, 100, 100, 100, 140.001]);
    final near2 = _input('R2B', [100, 100, 100, 100, 100, 139.999]);
    final over3 = _input('R3A', [for (int i = 0; i < 20; i++) 100.0, 112.8]);
    final near3 = _input('R3B', [for (int i = 0; i < 20; i++) 100.0, 112.6]);
    final over1 = _input('R1A', [100, 100, 100, 100, 100, 94.9]);
    final near1 = _input('R1B', [100, 100, 100, 100, 100, 95.1]);

    final res = EtfRotation.rank(
        [over2, near2, over3, near3, over1, near1],
        window: 5,
        maTrendWindow: 5);
    final dq = {for (final r in res) r.code: r.disqualified};

    expect(dq['R2A'], isTrue, reason: '+40.001% 应触发红线②');
    expect(dq['R2B'], isFalse, reason: '+39.999% 不应触发红线②');
    expect(dq['R3A'], isTrue, reason: 'MA20乖离 +12.08% 应触发红线③');
    expect(dq['R3B'], isFalse, reason: 'MA20乖离 +11.90% 不应触发红线③');
    expect(dq['R1A'], isTrue, reason: '−5.1% 应触发红线①');
    expect(dq['R1B'], isFalse, reason: '−4.9% 不应触发红线①');
  });

  // ── P1-2 回归：波动率地板 max(σ, 0.3%) ──
  test('波动率地板：零波动被抬到 0.3%，且方向正确（最稳=最高分）', () {
    final x = _input('X', [100, 102, 104.04, 106.1208, 108.243216, 110.40808]);
    final y = _input('Y', [100, 130, 90, 92, 95, 110.40808]);

    final results = EtfRotation.rank([x, y], window: 5, maTrendWindow: 5);
    final rx = results.firstWhere((r) => r.code == 'X');
    final ry = results.firstWhere((r) => r.code == 'Y');

    expect(rx.disqualified, isFalse);
    expect(ry.disqualified, isFalse);
    expect(rx.volatility, closeTo(EtfRotation.minVolatility, 1e-9));
    expect(rx.score, greaterThan(ry.score));
  });

  // ── 规格四节 · 趋势筛：跌破 MA28 不得成为候选（但排名照常输出）──
  test('趋势筛：站上MA28 才有候选资格，跌破者仍参与排名', () {
    final up = _input('UP', _grow(0.005, 45));
    final below = _input('BELOW', _belowMa28ButPositive());

    final results = EtfRotation.rank([up, below]); // 真实默认口径 window20 / MA28

    expect(results.length, 2);
    final rUp = results.firstWhere((r) => r.code == 'UP');
    final rBelow = results.firstWhere((r) => r.code == 'BELOW');

    // 两者都是有效标的、都参与排名
    expect(results.every((r) => !r.disqualified), isTrue);
    // BELOW 的 ret20 为正（+4%）却跌破 MA28
    expect(rBelow.cumulativeReturn, closeTo(0.04, 1e-9));
    expect(rBelow.aboveMa28, isFalse);
    expect(rBelow.passesBuyFilters, isFalse);
    expect(rBelow.blockReason, '跌破MA28');
    // UP 站上 MA28 且涨幅为正 → 是候选
    expect(rUp.aboveMa28, isTrue);
    expect(rUp.passesBuyFilters, isTrue);
    expect(rUp.blockReason, isEmpty);
    // 候选不含 BELOW，但排名里仍在
    expect(EtfRotation.candidateCodes(results), ['UP']);
  });

  // ── 规格四节 · 收益筛：ret20 ≤ 0 不得成为候选 ──
  test('收益筛：站上MA28 但 20 日涨幅≤0 不得成为候选', () {
    final r = EtfRotation.rank([_input('NEG', _aboveMa28ButNegative())]).single;

    expect(r.disqualified, isFalse);
    expect(r.aboveMa28, isTrue);
    expect(r.cumulativeReturn, lessThan(0));
    expect(r.passesBuyFilters, isFalse);
    expect(r.blockReason, '20日涨幅≤0');
    expect(EtfRotation.buyCandidates([r]), isEmpty);
  });

  // ── 规格四节 · 候选取前 3：按分降序跳过不合格者 ──
  test('候选取前3：跳过不合格者后取前三，不足则按实际数量', () {
    // 分数从高到低：BIG(大涨幅/低波动) 与 3 只温和上行 + 1 只跌破 MA28
    final inputs = <EtfStrengthInput>[
      _input('C1', _grow(0.012, 45)),
      _input('C2', _grow(0.010, 45)),
      _input('C3', _grow(0.008, 45)),
      _input('BELOW', _belowMa28ButPositive()),
    ];
    final results = EtfRotation.rank(inputs);
    final cands = EtfRotation.buyCandidates(results);

    expect(cands.length, 3);
    expect(cands.map((r) => r.code), ['C1', 'C2', 'C3']);
    expect(cands.every((r) => r.passesBuyFilters), isTrue);
    // 分数降序
    for (int i = 1; i < cands.length; i++) {
      expect(cands[i - 1].score, greaterThanOrEqualTo(cands[i].score));
    }
    // 只取 2 只时按实际数量
    expect(EtfRotation.buyCandidates(results, topN: 2).length, 2);
  });

  // ── 规格四节 · 全弱空仓：全池无一只同时过两道筛 ──
  test('全弱空仓：全池无一合格 → true；有一只合格 → false', () {
    // 全部跌破 MA28（ret20 有正有负）→ 无候选 → 空仓
    final allBelow = [
      EtfStrengthInput(code: 'A', name: 'A', klines: _klines(_belowMa28ButPositive())),
      EtfStrengthInput(code: 'B', name: 'B', klines: _klines(_aboveMa28ButNegative())),
    ];
    expect(EtfRotation.suggestCash(EtfRotation.rank(allBelow)), isTrue);

    // 全池普跌（ret20 全负）→ 空仓
    final allDown = <EtfStrengthInput>[
      _input('D1', _grow(-0.005, 45)),
      _input('D2', _grow(-0.006, 45)),
      _input('D3', _grow(-0.007, 45)),
    ];
    expect(EtfRotation.suggestCash(EtfRotation.rank(allDown)), isTrue);

    // 混入一只上行标的 → 有候选 → 不空仓
    final mixed = <EtfStrengthInput>[...allDown, _input('U1', _grow(0.004, 45))];
    expect(EtfRotation.suggestCash(EtfRotation.rank(mixed)), isFalse);

    // 池内无任何有效标的 → false（「无数据」≠「全弱」，由 UI 单独提示）
    expect(EtfRotation.suggestCash(EtfRotation.rank(const [])), isFalse);
  });

  // ── 数据不足：需同时满足 window+1 与 MA28 ──
  test('数据不足：空行情 / 少于 MA28 根均标记并沉底', () {
    final empty = EtfStrengthInput(code: 'Z', name: 'Z', klines: const []);
    final short = _input('Y', [100, 101, 102]); // 3 根 < 21 也 < 28
    final mid = _input('M', _grow(0.001, 25)); // 25 根：够 ret20，不够 MA28

    final results = EtfRotation.rank([empty, short, mid]);

    expect(results.every((r) => r.disqualified && r.score == 0.0), isTrue);
    expect(results.any((r) => r.reason == '无行情数据'), isTrue);
    expect(results.where((r) => r.reason == '数据不足').length, 2);
  });

  // ── 规格五节 2：盘中丢弃当日未收盘的半根 K 线 ──
  test('盘中(15:00前)丢弃当日 bar，收盘后保留', () {
    final klines = _klines([100, 101, 102]); // 2024-01-01 / 02 / 03

    // 盘中：最后一根即今天 → 删掉
    expect(
      EtfRotation.dropTodayBar(klines, now: DateTime(2024, 1, 3, 10, 30)).length,
      2,
    );
    // 刚好 15:00 → 视为已收盘，保留
    expect(
      EtfRotation.dropTodayBar(klines, now: DateTime(2024, 1, 3, 15, 0)).length,
      3,
    );
    // 收盘后 → 保留
    expect(
      EtfRotation.dropTodayBar(klines, now: DateTime(2024, 1, 3, 23, 59)).length,
      3,
    );
    // 末根不是今天（次日盘前）→ 保留
    expect(
      EtfRotation.dropTodayBar(klines, now: DateTime(2024, 1, 4, 9, 0)).length,
      3,
    );
    // 空序列 → 原样返回，不抛
    expect(EtfRotation.dropTodayBar(const [], now: DateTime(2024, 1, 3, 10)),
        isEmpty);
  });

  // ── 规格五节 3：调仓提示（上榜 / 出榜）──
  test('调仓提示：diffTopN 给出上榜/出榜，首次无基准', () {
    // 首次运行：无基准，不提示上榜/出榜
    final first = EtfRotation.diffTopN(current: ['A', 'B', 'C'], previous: const []);
    expect(first.hasBaseline, isFalse);
    expect(first.entered, isEmpty);
    expect(first.exited, isEmpty);

    // [A,B,C] → [A,C,D]：新上榜 D，出榜 B
    final d = EtfRotation.diffTopN(
        current: ['A', 'C', 'D'], previous: const ['A', 'B', 'C']);
    expect(d.hasBaseline, isTrue);
    expect(d.entered, ['D']);
    expect(d.exited, ['B']);
    expect(d.isEmpty, isFalse);

    // 完全一致 → 空 diff（「较上次候选无变化，无需调仓」）
    final same = EtfRotation.diffTopN(
        current: ['A', 'B', 'C'], previous: const ['A', 'B', 'C']);
    expect(same.isEmpty, isTrue);

    // 上次快照比本次长（池子收缩场景）→ 多出的部分计入出榜
    final longer = EtfRotation.diffTopN(
        current: ['A', 'B', 'C'], previous: const ['A', 'B', 'C', 'D', 'E']);
    expect(longer.entered, isEmpty);
    expect(longer.exited, ['D', 'E']);
  });

  // ── 全负池：合格项分数均为负，UI 需走 maxScore<=0 分支 ──
  test('全负池：合格项分数均为负，供 UI 走 maxScore<=0 分支', () {
    final pool = <EtfStrengthInput>[
      _input('N1', _grow(-0.003, 45)),
      _input('N2', _grow(-0.005, 45)),
    ];
    final res = EtfRotation.rank(pool);
    final qualified = res.where((r) => !r.disqualified).toList();

    expect(qualified, isNotEmpty);
    expect(qualified.every((r) => r.score < 0), isTrue);
    expect(qualified.every((r) => r.cumulativeReturn < 0), isTrue);
    expect(qualified.map((r) => r.score).reduce(math.max), lessThan(0));
    expect(EtfRotation.suggestCash(res), isTrue);
  });
}
