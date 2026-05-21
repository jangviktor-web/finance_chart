import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class TrixPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  TrixPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trixData = indicators.trix;
    final signalData = indicators.trixSignal;
    if (trixData == null || trixData.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    double minVal = 0, maxVal = 0;
    for (int i = visibleStart; i < visibleEnd && i < trixData.length; i++) {
      if (trixData[i] < minVal) minVal = trixData[i];
      if (trixData[i] > maxVal) maxVal = trixData[i];
    }
    if (signalData != null) {
      for (int i = visibleStart; i < visibleEnd && i < signalData.length; i++) {
        if (signalData[i] < minVal) minVal = signalData[i];
        if (signalData[i] > maxVal) maxVal = signalData[i];
      }
    }
    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;
    if (maxVal == minVal) return;

    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(0), AppColors.gridLine, 0.5);
    helper.drawLine(canvas, size, trixData, valueToY, AppColors.macdDif);
    if (signalData != null) helper.drawLine(canvas, size, signalData, valueToY, AppColors.macdDea);

    helper.drawLabel(canvas, size, 'TRIX(12,9)');
  }

  @override
  bool shouldRepaint(covariant TrixPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
