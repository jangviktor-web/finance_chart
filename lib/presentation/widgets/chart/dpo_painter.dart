import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

/// DPO 去趋势价格震荡器 Painter — 以 0 为中轴
class DpoPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  DpoPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.dpo;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 0;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      if (!data[i].isFinite) continue;
      if (data[i] < minVal) minVal = data[i];
      if (data[i] > maxVal) maxVal = data[i];
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, data, valueToY, AppColors.macdDif);
    helper.drawLabel(canvas, size, 'DPO(20)');
  }

  @override
  bool shouldRepaint(covariant DpoPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
