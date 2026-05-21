import 'package:flutter/material.dart';
import '../../../data/models/kline_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

class VolumePainter extends CustomPainter {
  final List<KlineData> klines;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;

  VolumePainter({
    required this.klines,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (klines.isEmpty) return;

    final visibleKlines = klines.sublist(visibleStart, visibleEnd);
    if (visibleKlines.isEmpty) return;

    // 找到最大成交量（过滤 NaN/Inf）
    double maxVolume = 0;
    for (final kline in visibleKlines) {
      if (kline.volume.isFinite && kline.volume > maxVolume) maxVolume = kline.volume;
    }

    if (maxVolume == 0) return;

    final totalWidth = candleWidth + ChartConfig.candleSpacing;

    // 绘制成交量柱
    for (int i = 0; i < visibleKlines.length; i++) {
      final kline = visibleKlines[i];
      if (!kline.volume.isFinite || kline.volume <= 0) continue;
      final x = i * totalWidth + totalWidth / 2;
      final barHeight = (kline.volume / maxVolume) * size.height * 0.9;

      final color = kline.isUp ? AppColors.up : AppColors.down;
      final paint = Paint()..color = color;

      canvas.drawRect(
        Rect.fromLTWH(
          x - candleWidth / 2,
          size.height - barHeight,
          candleWidth,
          barHeight,
        ),
        paint,
      );
    }

    // 绘制成交量标签
    _drawVolumeLabel(canvas, size, maxVolume);
  }

  void _drawVolumeLabel(Canvas canvas, Size size, double maxVolume) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: _formatVolume(maxVolume),
        style: TextStyle(
          color: AppColors.axisLabel,
          fontSize: ChartConfig.axisLabelFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 4, 2));
  }

  String _formatVolume(double volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(1)}亿';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(1)}万';
    }
    return volume.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant VolumePainter oldDelegate) {
    return !identical(oldDelegate.klines, klines) ||
        oldDelegate.visibleStart != visibleStart ||
        oldDelegate.visibleEnd != visibleEnd ||
        oldDelegate.candleWidth != candleWidth;
  }
}
