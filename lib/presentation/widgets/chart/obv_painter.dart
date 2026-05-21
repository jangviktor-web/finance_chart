import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class ObvPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  ObvPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.obv;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = double.maxFinite, maxVal = -double.maxFinite;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    if (minVal == double.maxFinite) minVal = 0;
    if (maxVal == -double.maxFinite) maxVal = 0;
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    // 面积填充
    final zeroY = valueToY(0);
    helper.drawArea(canvas, size, data, valueToY, AppColors.primary, zeroY);

    helper.drawLine(canvas, size, data, valueToY, AppColors.primary);
    helper.drawLabel(canvas, size, 'OBV');
  }

  @override
  bool shouldRepaint(covariant ObvPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
