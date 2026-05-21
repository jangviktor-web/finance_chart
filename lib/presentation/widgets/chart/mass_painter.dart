import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

/// MASS 梅斯线 Painter
class MassPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  MassPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.mass;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = double.infinity, maxVal = -double.infinity;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] == 0 || !data[i].isFinite) continue;
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    if (!minVal.isFinite || !maxVal.isFinite) return;
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(27), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, data, valueToY, AppColors.macdDif);
    helper.drawLabel(canvas, size, 'MASS(9,25)');
  }

  @override
  bool shouldRepaint(covariant MassPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
