import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';

class DmiPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  DmiPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dmi = indicators.dmi;
    if (dmi == null) return;
    final pdi = dmi['pdi']!;
    final mdi = dmi['mdi']!;
    final adx = dmi['adx']!;
    final adxr = dmi['adxr']!;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    // DMI 范围 0-100
    double maxVal = 80;
    for (int i = visibleStart; i < visibleEnd && i < pdi.length; i++) {
      if (pdi[i] > maxVal) maxVal = pdi[i];
      if (mdi[i] > maxVal) maxVal = mdi[i];
      if (adx[i] > maxVal) maxVal = adx[i];
      if (adxr[i] > maxVal) maxVal = adxr[i];
    }
    maxVal += 10;
    final valueToY = (double v) => size.height * (1 - v / maxVal);

    helper.drawHorizontalLine(canvas, size, valueToY(20), AppColors.gridLine, 0.3);

    helper.drawLine(canvas, size, pdi, valueToY, AppColors.macdDif);
    helper.drawLine(canvas, size, mdi, valueToY, AppColors.macdDea);
    helper.drawLine(canvas, size, adx, valueToY, AppColors.ma20);
    helper.drawLine(canvas, size, adxr, valueToY, AppColors.kdjJ);

    helper.drawLabel(canvas, size, 'DMI(14)');
  }

  @override
  bool shouldRepaint(covariant DmiPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
