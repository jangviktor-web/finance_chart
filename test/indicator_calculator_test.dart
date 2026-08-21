import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/data/models/indicator_data.dart';
import 'package:finance_chart/data/models/indicator_params.dart';
import 'package:finance_chart/data/models/kline_data.dart';
import 'package:finance_chart/domain/services/indicator_calculator.dart';

void main() {
  final calc = IndicatorCalculator();

  group('MA 简单移动平均', () {
    test('精确计算窗口均值，预热期补零', () {
      final result = calc.ma(<double>[1, 2, 3, 4, 5], 3);
      expect(result, <double>[0, 0, 2, 3, 4]);
    });

    test('数据不足周期时全零', () {
      final result = calc.ma(<double>[1, 2], 3);
      expect(result, <double>[0, 0]);
    });
  });

  group('EMA 指数移动平均', () {
    test('首值取原值，后续按乘数递推', () {
      final result = calc.ema(<double>[1, 2, 3], 2);
      expect(result[0], 1);
      expect(result[1], closeTo(5 / 3, 1e-9));
      expect(result[2], closeTo(23 / 9, 1e-9));
    });
  });

  group('MACD', () {
    test('DIF/DEA/柱长度与输入一致，首柱为 0', () {
      final closes = <double>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final result = calc.macd(closes, short: 2, long: 3, signal: 2);
      expect(result.length, 3);
      for (final line in result) {
        expect(line.length, closes.length);
      }
      expect(result[2][0], 0);
    });

    test('常数序列 MACD 全零', () {
      final closes = List<double>.filled(10, 5.0);
      final result = calc.macd(closes);
      for (final v in result[0]) {
        expect(v, closeTo(0, 1e-9));
      }
    });
  });

  group('KDJ', () {
    test('恒定价格下 RSV=50，K/D/J 均稳定在 50', () {
      final closes = List<double>.filled(10, 10.0);
      final highs = List<double>.filled(10, 10.0);
      final lows = List<double>.filled(10, 10.0);
      final result = calc.kdj(closes, highs, lows, period: 9);
      expect(result[0].every((v) => (v - 50).abs() < 1e-9), isTrue);
      expect(result[1].every((v) => (v - 50).abs() < 1e-9), isTrue);
      expect(result[2].every((v) => (v - 50).abs() < 1e-9), isTrue);
    });
  });

  group('RSI', () {
    test('单调上涨序列 RSI=100（预热期后）', () {
      final result = calc.rsi(<double>[1, 2, 3, 4, 5, 6, 7, 8], 2);
      for (int i = 2; i < result.length; i++) {
        expect(result[i], closeTo(100, 1e-9));
      }
    });

    test('单调下跌序列 RSI=0（预热期后）', () {
      final result = calc.rsi(<double>[8, 7, 6, 5, 4, 3, 2, 1], 2);
      for (int i = 2; i < result.length; i++) {
        expect(result[i], closeTo(0, 1e-9));
      }
    });
  });

  group('BOLL', () {
    test('上下轨 = 中轨 ± 标准差 × 倍数', () {
      final result = calc.boll(<double>[1, 2, 3], 2, 2.0);
      expect(result[0][1], closeTo(1.5, 1e-9));
      expect(result[1][1], closeTo(2.5, 1e-9));
      expect(result[2][1], closeTo(0.5, 1e-9));
      expect(result[0][2], closeTo(2.5, 1e-9));
      expect(result[1][2], closeTo(3.5, 1e-9));
      expect(result[2][2], closeTo(1.5, 1e-9));
    });
  });

  group('calculateAll', () {
    List<KlineData> buildKlines(int n) {
      return List.generate(n, (i) {
        final base = 10.0 + i;
        return KlineData(
          time: DateTime(2026, 1, 1).add(Duration(days: i)),
          open: base,
          close: base + 0.5,
          high: base + 1,
          low: base - 1,
          volume: 1000.0 + i,
          amount: 0,
        );
      });
    }

    test('空数据返回空指标', () {
      final result = calc.calculateAll(<KlineData>[]);
      expect(result.dif, isEmpty);
      expect(result.rsi, isEmpty);
      expect(result.activeIndicators, isEmpty);
    });

    test('基础指标始终计算', () {
      final result = calc.calculateAll(buildKlines(30));
      expect(result.maLines.length, IndicatorParams().maPeriods.length);
      expect(result.dif.length, 30);
      expect(result.dea.length, 30);
      expect(result.macdHist.length, 30);
      expect(result.rsi.length, 30);
      expect(result.activeIndicators, containsAll({'MA', 'MACD', 'KDJ', 'RSI', 'BOLL'}));
    });

    test('按需计算扩展指标', () {
      final result = calc.calculateAll(buildKlines(60), requestedIndicators: {'CCI'});
      expect(result.cci, isNotNull);
      expect(result.cci!.length, 60);
      expect(result.activeIndicators, contains('CCI'));
    });

    test('isolate 入口函数结果与直接计算一致（P0-3）', () {
      final klines = buildKlines(40);
      final direct = calc.calculateAll(klines);
      final viaIsolate = calculateIndicatorsIsolate(
        (klines: klines, params: const IndicatorParams(), requested: null),
      );
      expect(viaIsolate.dif.length, direct.dif.length);
      expect(viaIsolate.macdHist.last, closeTo(direct.macdHist.last, 1e-9));
      expect(viaIsolate.activeIndicators, direct.activeIndicators);
    });
  });
}
