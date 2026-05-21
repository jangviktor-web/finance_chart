import 'package:flutter/material.dart';
import '../../../data/models/kline_data.dart';
import '../../../app/theme.dart';

class CrosshairPainter extends CustomPainter {
  final Offset? position;
  final KlineData? kline;
  final double candleWidth;
  final int visibleStart;
  final int visibleEnd;
  final double Function(int)? indexToX;
  final double Function(double)? priceToY;
  final String period;

  CrosshairPainter({
    this.position,
    this.kline,
    required this.candleWidth,
    required this.visibleStart,
    this.indexToX,
    this.priceToY,
    required this.visibleEnd,
    this.period = 'day',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null || kline == null) return;

    final crosshairPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.5)
      ..strokeWidth = 0.5;

    // 垂直线
    canvas.drawLine(
      Offset(position!.dx, 0),
      Offset(position!.dx, size.height),
      crosshairPaint,
    );

    // 水平线
    canvas.drawLine(
      Offset(0, position!.dy),
      Offset(size.width, position!.dy),
      crosshairPaint,
    );

    // 绘制数据提示框
    _drawTooltip(canvas, size, position!, kline!);
  }

  void _drawTooltip(Canvas canvas, Size size, Offset pos, KlineData kline) {
    final tooltipWidth = 120.0;
    final tooltipHeight = 100.0;

    // 计算提示框位置 (避免超出边界)
    double tooltipX = pos.dx + 10;
    double tooltipY = pos.dy - tooltipHeight / 2;

    if (tooltipX + tooltipWidth > size.width) {
      tooltipX = pos.dx - tooltipWidth - 10;
    }
    if (tooltipY < 0) tooltipY = 0;
    if (tooltipY + tooltipHeight > size.height) {
      tooltipY = size.height - tooltipHeight;
    }

    // 绘制背景
    final bgPaint = Paint()
      ..color = AppColors.surface.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // 绘制边框
    final borderPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // 绘制文字
    final textStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 10,
    );

    final isIntraday = ['1m', '5m', '15m', '30m', '60m'].contains(period);
    final timeStr = isIntraday
        ? '${kline.time.month}/${kline.time.day} '
          '${kline.time.hour.toString().padLeft(2, '0')}:'
          '${kline.time.minute.toString().padLeft(2, '0')}'
        : '${kline.time.year}-${kline.time.month.toString().padLeft(2, '0')}-'
          '${kline.time.day.toString().padLeft(2, '0')}';

    final labels = [
      '时间: $timeStr',
      '开盘: ${kline.open.toStringAsFixed(2)}',
      '收盘: ${kline.close.toStringAsFixed(2)}',
      '最高: ${kline.high.toStringAsFixed(2)}',
      '最低: ${kline.low.toStringAsFixed(2)}',
    ];

    for (int i = 0; i < labels.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(tooltipX + 8, tooltipY + 8 + i * 16));
    }
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.kline != kline;
  }
}
