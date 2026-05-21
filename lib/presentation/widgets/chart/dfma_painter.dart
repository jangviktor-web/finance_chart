import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

/// DFMA 平行线差指标 Painter — DIF + DIFMA 双线
class DfmaPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  DfmaPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final difData = indicators.dfmaDif;
    final difmaData = indicators.dfmaDifma;
    if (difData == null || difmaData == null) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 0;
    for (int i = visibleStart; i < visibleEnd && i < difData.length; i++) {
      for (final v in [difData[i], i < difmaData.length ? difmaData[i] : 0.0]) {
        if (!v.isFinite) continue;
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, difData, valueToY, AppColors.macdDif);
    helper.drawLine(canvas, size, difmaData, valueToY, AppColors.macdDea);
    helper.drawLabel(canvas, size, 'DFMA');
  }

  @override
  bool shouldRepaint(covariant DfmaPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
