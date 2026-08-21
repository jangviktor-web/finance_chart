import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';
import 'chart_viewport.dart';

/// PSY 心理线 Painter — 范围 0~100，50 为中轴
class PsyPainter extends CustomPainter {
  final IndicatorData indicators;
  final ChartViewport viewport;

  PsyPainter({required this.indicators, required this.viewport})
      : super(repaint: viewport);

  int get visibleStart => viewport.visibleStart;
  int get visibleEnd => viewport.visibleEnd;
  double get candleWidth => viewport.candleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.psy;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 100;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] != 0 && data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(50), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, data, valueToY, AppColors.macdDif);
    helper.drawLabel(canvas, size, 'PSY(12)');
  }

  @override
  bool shouldRepaint(covariant PsyPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
