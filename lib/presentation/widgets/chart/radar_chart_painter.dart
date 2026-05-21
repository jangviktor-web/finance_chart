import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/models/stock_score.dart';

/// 雷达图 Painter — 多股评分对比
class RadarChartPainter extends CustomPainter {
  final List<StockScore> scores;
  final List<Color> colors;

  static const _labels = StockScore.dimensionLabels;
  static const _dimCount = 5;

  RadarChartPainter({
    required this.scores,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;
    final angleStep = 2 * pi / _dimCount;
    final startAngle = -pi / 2; // 从顶部开始

    // ── 网格线（4层） ──
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int layer = 1; layer <= 4; layer++) {
      final r = radius * layer / 4;
      gridPaint.color = AppColors.divider;
      final path = Path();
      for (int i = 0; i <= _dimCount; i++) {
        final angle = startAngle + angleStep * (i % _dimCount);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      canvas.drawPath(path, gridPaint);

      // 层级标签（25/50/75/100）
      if (layer % 2 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${layer * 25}',
            style: TextStyle(color: AppColors.axisLabel, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(center.dx + 2, center.dy - r - 2));
      }
    }

    // ── 轴线 ──
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.divider;
    for (int i = 0; i < _dimCount; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, end, axisPaint);
    }

    // ── 维度标签 ──
    for (int i = 0; i < _dimCount; i++) {
      final angle = startAngle + angleStep * i;
      final labelR = radius + 18;
      final x = center.dx + labelR * cos(angle);
      final y = center.dy + labelR * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // ── 数据多边形 ──
    for (int s = 0; s < scores.length; s++) {
      final score = scores[s];
      final color = colors[s % colors.length];
      final values = score.values;

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.15);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;

      final path = Path();
      for (int i = 0; i < _dimCount; i++) {
        final angle = startAngle + angleStep * i;
        final r = radius * (values[i] / 100).clamp(0.0, 1.0);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      // 数据点
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      for (int i = 0; i < _dimCount; i++) {
        final angle = startAngle + angleStep * i;
        final r = radius * (values[i] / 100).clamp(0.0, 1.0);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(RadarChartPainter old) {
    return !identical(scores, old.scores) || scores.length != old.scores.length;
  }
}
