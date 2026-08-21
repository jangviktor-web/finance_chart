import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';
import 'chart_viewport.dart';

/// BRAR 情绪指标 Painter — BR + AR 双线
class BrarPainter extends CustomPainter {
  final IndicatorData indicators;
  final ChartViewport viewport;

  BrarPainter({required this.indicators, required this.viewport})
      : super(repaint: viewport);

  int get visibleStart => viewport.visibleStart;
  int get visibleEnd => viewport.visibleEnd;
  double get candleWidth => viewport.candleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final brData = indicators.br;
    final arData = indicators.ar;
    if (brData == null || arData == null) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = double.infinity, maxVal = -double.infinity;
    for (int i = visibleStart; i < visibleEnd && i < brData.length; i++) {
      for (final v in [brData[i], arData[i < arData.length ? i : 0]]) {
        if (v == 0 || !v.isFinite) continue;
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }
    if (!minVal.isFinite || !maxVal.isFinite) return;
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(100), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, brData, valueToY, AppColors.macdDif);
    helper.drawLine(canvas, size, arData, valueToY, AppColors.macdDea);
    helper.drawLabel(canvas, size, 'BRAR(26)');
  }

  @override
  bool shouldRepaint(covariant BrarPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
