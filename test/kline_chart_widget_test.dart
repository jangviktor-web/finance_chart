import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/data/models/indicator_data.dart';
import 'package:finance_chart/data/models/kline_data.dart';
import 'package:finance_chart/presentation/widgets/chart/kline_chart_widget.dart';

List<KlineData> buildKlines(int n) {
  return List.generate(n, (i) {
    final base = 10.0 + i * 0.1;
    return KlineData(
      time: DateTime(2026, 1, 1).add(Duration(days: i)),
      open: base,
      close: base + 0.05,
      high: base + 0.2,
      low: base - 0.2,
      volume: 1000.0 + i * 10,
      amount: 0,
    );
  });
}

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 640,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('空数据时显示占位文案', (tester) async {
    await tester.pumpWidget(wrap(KlineChartWidget(
      klines: const [],
      indicators: IndicatorData.empty(),
    )));
    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('有数据时正常渲染且不抛错', (tester) async {
    await tester.pumpWidget(wrap(KlineChartWidget(
      klines: buildKlines(60),
      indicators: IndicatorData.empty(),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('滑动/缩放手势不抛错', (tester) async {
    await tester.pumpWidget(wrap(KlineChartWidget(
      klines: buildKlines(60),
      indicators: IndicatorData.empty(),
    )));
    await tester.pump();

    // 单指滑动
    await tester.drag(find.byType(KlineChartWidget), const Offset(-80, 0));
    await tester.pump();
    // 双指缩放
    final gesture = await tester.createGesture();
    await gesture.down(const Offset(180, 300));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('长按十字线模式可进出且不抛错', (tester) async {
    await tester.pumpWidget(wrap(KlineChartWidget(
      klines: buildKlines(60),
      indicators: IndicatorData.empty(),
    )));
    await tester.pump();

    final center = tester.getCenter(find.byType(KlineChartWidget));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600)); // 触发长按
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
