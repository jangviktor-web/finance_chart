import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class CciPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  CciPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.cci;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth,
      visibleStart: visibleStart,
      visibleEnd: visibleEnd,
    );

    // CCI 范围通常是 -100 到 +100，但可超出
    double minVal = -100, maxVal = 100;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    // 零轴
    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);
    // +100 / -100 参考线
    helper.drawHorizontalLine(canvas, size, valueToY(100), AppColors.gridLine, 0.3);
    helper.drawHorizontalLine(canvas, size, valueToY(-100), AppColors.gridLine, 0.3);

    // CCI 线
    helper.drawLine(canvas, size, data, valueToY, AppColors.macdDif);

    helper.drawLabel(canvas, size, 'CCI(14)');
  }

  @override
  bool shouldRepaint(covariant CciPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
