import 'package:flutter/material.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

/// 指标 Painter 公共工具类
class IndicatorPainterHelper {
  final double candleWidth;
  final int visibleStart;
  final int visibleEnd;

  IndicatorPainterHelper({
    required this.candleWidth,
    required this.visibleStart,
    required this.visibleEnd,
  });

  double get totalWidth => candleWidth + ChartConfig.candleSpacing;

  /// 绘制折线
  void drawLine(Canvas canvas, Size size, List<double> data,
      double Function(double) valueToY, Color color, {double strokeWidth = 1}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path();
    bool started = false;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      final x = (i - visibleStart) * totalWidth + totalWidth / 2;
      final y = valueToY(data[i]);
      if (!started) { path.moveTo(x, y); started = true; }
      else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  /// 绘制水平参考线
  void drawHorizontalLine(Canvas canvas, Size size, double y, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  /// 绘制标签
  void drawLabel(Canvas canvas, Size size, String label) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, const Offset(4, 2));
  }

  /// 绘制面积填充
  void drawArea(Canvas canvas, Size size, List<double> data,
      double Function(double) valueToY, Color color, double zeroY) {
    final path = Path();
    path.moveTo(0, zeroY);
    bool started = false;
    for (int i = visibleStart; i < visibleEnd && i < data.length; i++) {
      final x = (i - visibleStart) * totalWidth + totalWidth / 2;
      final y = valueToY(data[i]);
      if (!started) { path.lineTo(x, y); started = true; }
      else { path.lineTo(x, y); }
    }
    final lastX = (min(visibleEnd, data.length) - visibleStart - 1) * totalWidth + totalWidth / 2;
    path.lineTo(lastX, zeroY);
    path.close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.15));
  }

  int min(int a, int b) => a < b ? a : b;
}
