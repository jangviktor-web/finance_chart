import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

class RsiPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  RsiPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (indicators.rsi.isEmpty) return;

    final rsiData = indicators.rsi;

    // RSI 范围 0-100
    const minVal = 0.0;
    const maxVal = 100.0;

    final valueToY = (double value) {
      return size.height * (1 - (value - minVal) / (maxVal - minVal));
    };

    final totalWidth = candleWidth + ChartConfig.candleSpacing;

    // 绘制超买超卖参考线
    final zonePaint = Paint()
      ..strokeWidth = 0.5;

    // 70 超买线 (红色虚线)
    zonePaint.color = AppColors.down.withOpacity(0.5);
    _drawDashedLine(canvas, size, valueToY(70), zonePaint);

    // 50 中线 (灰色)
    zonePaint.color = AppColors.gridLine;
    _drawDashedLine(canvas, size, valueToY(50), zonePaint);

    // 30 超卖线 (绿色虚线)
    zonePaint.color = AppColors.up.withOpacity(0.5);
    _drawDashedLine(canvas, size, valueToY(30), zonePaint);

    // 绘制超买超卖区域
    final overboughtPaint = Paint()
      ..color = AppColors.down.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, valueToY(100), size.width, valueToY(70) - valueToY(100)),
      overboughtPaint,
    );

    final oversoldPaint = Paint()
      ..color = AppColors.up.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, valueToY(30), size.width, valueToY(0) - valueToY(30)),
      oversoldPaint,
    );

    // 绘制 RSI 曲线
    final rsiPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    for (int i = visibleStart; i < visibleEnd && i < rsiData.length; i++) {
      if (!rsiData[i].isFinite) continue;
      final x = (i - visibleStart) * totalWidth + totalWidth / 2;
      final y = valueToY(rsiData[i].clamp(minVal, maxVal));

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, rsiPaint);

    // 绘制标签
    _drawLabel(canvas, size, 'RSI(14)');

    // 绘制参考线数值
    _drawRefLabel(canvas, size, '70', valueToY(70), AppColors.down);
    _drawRefLabel(canvas, size, '30', valueToY(30), AppColors.up);
  }

  void _drawDashedLine(Canvas canvas, Size size, double y, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
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

  void _drawRefLabel(Canvas canvas, Size size, String text, double y, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color.withOpacity(0.6), fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 4, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant RsiPainter oldDelegate) {
    return !identical(oldDelegate.indicators, indicators) ||
        oldDelegate.visibleStart != visibleStart ||
        oldDelegate.visibleEnd != visibleEnd ||
        oldDelegate.candleWidth != candleWidth;
  }
}
