import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';
import 'chart_viewport.dart';

class EmvPainter extends CustomPainter {
  final IndicatorData indicators;
  final ChartViewport viewport;

  EmvPainter({required this.indicators, required this.viewport})
      : super(repaint: viewport);

  int get visibleStart => viewport.visibleStart;
  int get visibleEnd => viewport.visibleEnd;
  double get candleWidth => viewport.candleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.emv;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 0;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, data, valueToY, AppColors.kdjK);
    helper.drawLabel(canvas, size, 'EMV(14)');
  }

  @override
  bool shouldRepaint(covariant EmvPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
