import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../app/theme.dart';
import 'indicator_painter_helper.dart';
import 'chart_viewport.dart';

class MfiPainter extends CustomPainter {
  final IndicatorData indicators;
  final ChartViewport viewport;

  MfiPainter({required this.indicators, required this.viewport})
      : super(repaint: viewport);

  int get visibleStart => viewport.visibleStart;
  int get visibleEnd => viewport.visibleEnd;
  double get candleWidth => viewport.candleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final data = indicators.mfi;
    if (data == null || data.isEmpty) return;

    final helper = IndicatorPainterHelper(
      candleWidth: candleWidth, visibleStart: visibleStart, visibleEnd: visibleEnd,
    );

    // MFI 范围 0-100
    const minVal = 0.0;
    const maxVal = 100.0;
    final valueToY = (double v) => size.height * (1 - (v - minVal) / (maxVal - minVal));

    helper.drawHorizontalLine(canvas, size, valueToY(80), AppColors.gridLine, 0.5);
    helper.drawHorizontalLine(canvas, size, valueToY(20), AppColors.gridLine, 0.5);

    helper.drawLine(canvas, size, data, valueToY, AppColors.ma20);
    helper.drawLabel(canvas, size, 'MFI(14)');
  }

  @override
  bool shouldRepaint(covariant MfiPainter old) =>
      old.visibleStart != visibleStart || old.visibleEnd != visibleEnd || old.candleWidth != candleWidth;
}
