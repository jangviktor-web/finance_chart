import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

class KdjPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  KdjPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (indicators.k.isEmpty) return;

    final kData = indicators.k;
    final dData = indicators.d;
    final jData = indicators.j;

    // KDJ 范围通常是 0-100
    const minVal = 0.0;
    const maxVal = 100.0;

    final valueToY = (double value) {
      return size.height * (1 - (value - minVal) / (maxVal - minVal));
    };

    final totalWidth = candleWidth + ChartConfig.candleSpacing;

    // 绘制超买超卖线
    final zonePaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;

    // 80 超买线
    final y80 = valueToY(80);
    canvas.drawLine(Offset(0, y80), Offset(size.width, y80), zonePaint);

    // 20 超卖线
    final y20 = valueToY(20);
    canvas.drawLine(Offset(0, y20), Offset(size.width, y20), zonePaint);

    // 绘制 K 线
    _drawLine(canvas, size, kData, visibleStart, visibleEnd, totalWidth, valueToY, AppColors.kdjK);

    // 绘制 D 线
    _drawLine(canvas, size, dData, visibleStart, visibleEnd, totalWidth, valueToY, AppColors.kdjD);

    // 绘制 J 线
    _drawLine(canvas, size, jData, visibleStart, visibleEnd, totalWidth, valueToY, AppColors.kdjJ);

    // 绘制标签
    _drawLabel(canvas, size, 'KDJ(9,3,3)');
  }

  void _drawLine(Canvas canvas, Size size, List<double> data, int start, int end,
      double totalWidth, double Function(double) valueToY, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    for (int i = start; i < end && i < data.length; i++) {
      if (!data[i].isFinite) continue;
      final x = (i - start) * totalWidth + totalWidth / 2;
      final y = valueToY(data[i]);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Size size, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(4, 2));
  }

  @override
  bool shouldRepaint(covariant KdjPainter oldDelegate) {
    return !identical(oldDelegate.indicators, indicators) ||
        oldDelegate.visibleStart != visibleStart ||
        oldDelegate.visibleEnd != visibleEnd ||
        oldDelegate.candleWidth != candleWidth;
  }
}
