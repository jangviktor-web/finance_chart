import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class AtrPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  AtrPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.atr;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = double.maxFinite, maxVal = 0;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    if (minVal == double.maxFinite) minVal = 0;
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));
    helper.drawLine(canvas, size, data, valueToY, AppColors.ma20);
    helper.drawLabel(canvas, size, 'ATR(14)');
  }

  @override
  bool shouldRepaint(covariant AtrPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
