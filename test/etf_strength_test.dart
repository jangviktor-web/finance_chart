import 'package:flutter_test/flutter_test.dart';

import '../lib/data/models/kline_data.dart';
import '../lib/domain/services/etf_strength.dart';

/// 由收盘价序列构造 KlineData 列表（open=high=low=close，便于只验证 close 逻辑）。
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

void main() {
  // ── 排序正确性：「稳」强于「猛」──
  test('稳强度排序：低波动上行 > 高波动 > 下行', () {
    // window=5 → 需 6 根
    final steadyUp = _input('A', [100, 101, 102, 103, 104, 105]); // 低波动上行
    final declining = _input('B', [100, 99, 98, 97, 96, 95]); // 下行
    final volatile = _input('C', [100, 130, 95, 105, 107, 108]); // 高波动但近3日温和

    final results = EtfRotation.rank([steadyUp, declining, volatile], window: 5);

    // 全部未剔除
    expect(results.every((r) => !r.disqualified), isTrue);
    // 排序：A(最稳) > C > B(下行)
    expect(results[0].code, 'A');
    expect(results[1].code, 'C');
    expect(results[2].code, 'B');
    // 分数单调递减
    for (int i = 1; i < results.length; i++) {
      expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
    }
    // rank 从 1 起
    expect(results[0].rank, 1);
    expect(results[2].rank, 3);
  });

  // ── 近 3 日单日跌超 5% → 分数归零 ──
  test('近3日曾单日跌超5% 被剔除且分数为0', () {
    final bad = _input('X', [100, 100, 100, 100, 94, 100]); // 第4日日收益 -6%
    final steadyUp = _input('A', [100, 101, 102, 103, 104, 105]);
    final volatile = _input('C', [100, 130, 95, 105, 107, 108]);

    final results = EtfRotation.rank([bad, steadyUp, volatile], window: 5);
    final x = results.firstWhere((r) => r.code == 'X');

    expect(x.disqualified, isTrue);
    expect(x.score, 0.0);
    expect(x.reason, contains('跌超5%'));
    // 其余未受影响
    expect(results.where((r) => r.code != 'X').every((r) => !r.disqualified), isTrue);
  });

  // ── 池内前 10% 涨幅剔除（池子 >= 10）──
  test('短期涨幅过猛(池内前10%) 被剔除', () {
    final inputs = <EtfStrengthInput>[];
    // 11 只，每只日收益恒定且为正（无 -5% 日），累计收益随 j 递增
    for (int j = 0; j < 11; j++) {
      final r = 0.001 * (j + 1);
      final closes = <double>[];
      double p = 100;
      for (int i = 0; i < 6; i++) {
        closes.add(p);
        p *= (1 + r);
      }
      inputs.add(_input('E$j', closes));
    }

    final results = EtfRotation.rank(inputs, window: 5);
    final top = results.firstWhere((r) => r.code == 'E10');
    final low = results.firstWhere((r) => r.code == 'E0');

    expect(top.disqualified, isTrue);
    expect(top.reason, contains('涨幅过猛'));
    expect(top.score, 0.0);
    expect(low.disqualified, isFalse);
  });

  // ── 边界：数据不足 / 无行情 ──
  test('空行情与数据不足均标记并沉底', () {
    final empty = EtfStrengthInput(code: 'Z', name: 'Z', klines: const []);
    final short = _input('Y', [100, 101, 102]); // < window+1

    final results = EtfRotation.rank([empty, short], window: 5);

    expect(results.every((r) => r.disqualified && r.score == 0.0), isTrue);
    expect(results.any((r) => r.reason == '无行情数据'), isTrue);
    expect(results.any((r) => r.reason == '数据不足'), isTrue);
  });

  // ── 池子 < 10 时跳过前 10% 规则 ──
  test('池子<10 时不触发涨幅剔除', () {
    final inputs = <EtfStrengthInput>[];
    for (int j = 0; j < 5; j++) {
      final r = 0.001 * (j + 1);
      final closes = <double>[];
      double p = 100;
      for (int i = 0; i < 6; i++) {
        closes.add(p);
        p *= (1 + r);
      }
      inputs.add(_input('E$j', closes));
    }
    final results = EtfRotation.rank(inputs, window: 5);
    expect(results.every((r) => !r.disqualified), isTrue);
  });

  // ── 回归：零波动方向正确性（验证者指出的测试盲区）──
  // 旧守卫 std<1e-6 把「零波动平稳上涨」的 riskAdjRaw 强制置 0（最低），方向反了。
  // 修正后：零波动 = 最稳 = 最高风险调整收益。
  test('零波动平稳上涨 的 A 分量高于 同累计收益但大起大落', () {
    // X：恒定 10% 上涨 → 日收益 std 恰好为 0
    final x = _input('X', [100, 110, 121, 133.1, 146.41, 161.051]);
    // Y：与 X 同累计收益(≈0.61051)，但前两段大开大合、末段温和（含一个 +94% 收尾）
    final y = _input('Y', [100, 200, 80, 82, 83, 161.051]);

    final results = EtfRotation.rank([x, y], window: 5);
    final rx = results.firstWhere((r) => r.code == 'X');
    final ry = results.firstWhere((r) => r.code == 'Y');

    // 两者均未剔除（避免被规则干扰）
    expect(rx.disqualified, isFalse);
    expect(ry.disqualified, isFalse);
    // 零波动的 X 风险调整收益分量高于大起大落的 Y（稳者更高）
    expect(rx.a, greaterThan(ry.a));
    // 总分也更高
    expect(rx.score, greaterThan(ry.score));
  });
}
