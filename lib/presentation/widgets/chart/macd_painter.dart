import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

class MacdPainter extends CustomPainter {
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  MacdPainter({
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (indicators.dif.isEmpty) return;

    final dif = indicators.dif;
    final dea = indicators.dea;
    final hist = indicators.macdHist;

    // 计算可见范围内的极值（过滤 NaN/Inf）
    double minVal = 0;
    double maxVal = 0;

    for (int i = visibleStart; i < visibleEnd && i < dif.length; i++) {
      final v = [dif[i], dea[i], hist[i]];
      for (final val in v) {
        if (!val.isFinite) continue;
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    if (maxVal == minVal) return;

    final padding = (maxVal - minVal) * 0.1;
    minVal -= padding;
    maxVal += padding;

    final valueToY = (double value) {
      return size.height * (1 - (value - minVal) / (maxVal - minVal));
    };

    final totalWidth = candleWidth + ChartConfig.candleSpacing;
    final zeroY = valueToY(0);

    // 绘制 MACD 柱状图
    for (int i = visibleStart; i < visibleEnd && i < hist.length; i++) {
      if (!hist[i].isFinite) continue;
      final x = (i - visibleStart) * totalWidth + totalWidth / 2;
      final barHeight = (hist[i] / (maxVal - minVal)) * size.height;

      final color = hist[i] >= 0 ? AppColors.up : AppColors.down;
      final paint = Paint()..color = color;

      if (hist[i] >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(x - candleWidth / 2, zeroY - barHeight.abs(), candleWidth, barHeight.abs()),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(x - candleWidth / 2, zeroY, candleWidth, barHeight.abs()),
          paint,
        );
      }
    }

    // 绘制 DIF 线
    _drawLine(canvas, size, dif, visibleStart, visibleEnd, totalWidth, valueToY, AppColors.macdDif);

    // 绘制 DEA 线
    _drawLine(canvas, size, dea, visibleStart, visibleEnd, totalWidth, valueToY, AppColors.macdDea);

    // 绘制零轴
    final zeroPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    // 绘制标签
    _drawLabel(canvas, size, 'MACD(12,26,9)');
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
  bool shouldRepaint(covariant MacdPainter oldDelegate) {
    return !identical(oldDelegate.indicators, indicators) ||
        oldDelegate.visibleStart != visibleStart ||
        oldDelegate.visibleEnd != visibleEnd ||
        oldDelegate.candleWidth != candleWidth;
  }
}
