import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class BiasPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  BiasPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final biasLines = indicators.biasLines;
    if (biasLines == null || biasLines.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 0;
    for (final line in biasLines) {
      for (int i = visibleStart; i < visibleEnd && i < line.length; i++) {
        if (line[i] < minVal) minVal = line[i];
        if (line[i] > maxVal) maxVal = line[i];
      }
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);

    final colors = [AppColors.ma5, AppColors.ma10, AppColors.ma20];
    for (int idx = 0; idx < biasLines.length && idx < colors.length; idx++) {
      helper.drawLine(canvas, size, biasLines[idx], valueToY, colors[idx]);
    }

    helper.drawLabel(canvas, size, 'BIAS(${indicators.biasPeriods?.join(",") ?? "6,12,24"})');
  }

  @override
  bool shouldRepaint(covariant BiasPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
