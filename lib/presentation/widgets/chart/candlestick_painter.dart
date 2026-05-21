import 'package:flutter/material.dart';
import '../../../data/models/kline_data.dart';
import '../../../data/models/indicator_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';

class CandlestickPainter extends CustomPainter {
  final List<KlineData> klines;
  final IndicatorData indicators;
  final int visibleStart;
  final int visibleEnd;
  final double candleWidth;
  final bool showMA;
  final bool showBOLL;
  final bool showBBI;
  final bool showEXPMA;
  final bool showKTN;
  final String period;

  CandlestickPainter({
    required this.klines,
    required this.indicators,
    required this.visibleStart,
    required this.visibleEnd,
    required this.candleWidth,
    this.showMA = true,
    this.showBOLL = false,
    this.showBBI = false,
    this.showEXPMA = false,
    this.showKTN = false,
    this.period = 'day',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (klines.isEmpty) return;

    final visibleKlines = klines.sublist(visibleStart, visibleEnd);
    if (visibleKlines.isEmpty) return;

    // 计算价格范围（过滤 NaN/Inf）
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    for (final kline in visibleKlines) {
      if (kline.low.isFinite && kline.low < minPrice) minPrice = kline.low;
      if (kline.high.isFinite && kline.high > maxPrice) maxPrice = kline.high;
    }

    if (!minPrice.isFinite || !maxPrice.isFinite || maxPrice <= minPrice) return;

    // 添加 padding
    final priceRange = maxPrice - minPrice;
    minPrice -= priceRange * ChartConfig.pricePadding;
    maxPrice += priceRange * ChartConfig.pricePadding;

    final priceToY = (double price) {
      return size.height * (1 - (price - minPrice) / (maxPrice - minPrice));
    };

    final totalWidth = candleWidth + ChartConfig.candleSpacing;

    // 绘制网格线
    _drawGrid(canvas, size, minPrice, maxPrice, priceToY);

    // BOLL 填充区域 — 在蜡烛底层
    if (showBOLL) {
      _drawBollFill(canvas, size, visibleStart, visibleEnd, totalWidth, priceToY);
    }

    // 绘制蜡烛
    for (int i = 0; i < visibleKlines.length; i++) {
      final kline = visibleKlines[i];
      final x = i * totalWidth + totalWidth / 2;

      // 蜡烛颜色
      final color = kline.isUp ? AppColors.up : AppColors.down;
      final paint = Paint()..color = color;

      // 影线 (上下影线)
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(x, priceToY(kline.high)),
        Offset(x, priceToY(kline.low)),
        wickPaint,
      );

      // 实体
      final bodyTop = priceToY(kline.bodyTop);
      final bodyBottom = priceToY(kline.bodyBottom);
      final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight),
        paint,
      );
    }

    // 绘制 MA 均线
    if (showMA) {
      _drawMA(canvas, size, visibleStart, visibleEnd, totalWidth, priceToY);
    }

    // 绘制 BOLL 线条 — 在蜡烛上层
    if (showBOLL) {
      _drawBollLines(canvas, size, visibleStart, visibleEnd, totalWidth, priceToY);
    }

    // 绘制 BBI
    if (showBBI && indicators.bbi != null) {
      _drawOverlayLine(canvas, size, indicators.bbi!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.ma60);
    }

    // 绘制 EXPMA
    if (showEXPMA && indicators.expmaShort != null && indicators.expmaLong != null) {
      _drawOverlayLine(canvas, size, indicators.expmaShort!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.ma5);
      _drawOverlayLine(canvas, size, indicators.expmaLong!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.ma20);
    }

    // 绘制 KTN 肯特纳通道
    if (showKTN && indicators.ktn != null) {
      _drawOverlayLine(canvas, size, indicators.ktn!['middle']!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.ma20);
      _drawOverlayLine(canvas, size, indicators.ktn!['upper']!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.bollUpper);
      _drawOverlayLine(canvas, size, indicators.ktn!['lower']!, visibleStart, visibleEnd, totalWidth, priceToY, AppColors.bollLower);
    }

    // 绘制价格标签
    _drawPriceLabels(canvas, size, minPrice, maxPrice, priceToY);

    // 绘制 X 轴时间标签
    _drawTimeLabels(canvas, size, visibleKlines, totalWidth);
  }

  void _drawGrid(Canvas canvas, Size size, double minPrice, double maxPrice, double Function(double) priceToY) {
    final gridPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = ChartConfig.gridLineWidth;

    // 水平网格线 (5 条)
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawMA(Canvas canvas, Size size, int start, int end, double totalWidth, double Function(double) priceToY) {
    final colors = [AppColors.ma5, AppColors.ma10, AppColors.ma20, AppColors.ma60];

    for (int lineIdx = 0; lineIdx < indicators.maLines.length; lineIdx++) {
      final maData = indicators.maLines[lineIdx];
      if (maData.isEmpty) continue;

      final paint = Paint()
        ..color = colors[lineIdx]
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final path = Path();
      bool started = false;

      for (int i = start; i < end && i < maData.length; i++) {
        if (maData[i] == 0 || !maData[i].isFinite) continue;

        final x = (i - start) * totalWidth + totalWidth / 2;
        final y = priceToY(maData[i]);

        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawOverlayLine(Canvas canvas, Size size, List<double> data, int start, int end,
      double totalWidth, double Function(double) priceToY, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path();
    bool started = false;
    for (int i = start; i < end && i < data.length; i++) {
      if (data[i] == 0 || !data[i].isFinite) continue;
      final x = (i - start) * totalWidth + totalWidth / 2;
      final y = priceToY(data[i]);
      if (!started) { path.moveTo(x, y); started = true; }
      else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  /// BOLL 填充区域 — 上轨到下轨之间的封闭区域
  void _drawBollFill(Canvas canvas, Size size, int start, int end, double totalWidth, double Function(double) priceToY) {
    final upperData = indicators.bollUpper;
    final lowerData = indicators.bollLower;
    if (upperData.isEmpty || lowerData.isEmpty) return;

    final fillPath = Path();
    bool started = false;

    // 正向遍历上轨
    for (int i = start; i < end && i < upperData.length; i++) {
      if (!upperData[i].isFinite || !lowerData[i].isFinite) continue;
      final x = (i - start) * totalWidth + totalWidth / 2;
      if (!started) { fillPath.moveTo(x, priceToY(upperData[i])); started = true; }
      else { fillPath.lineTo(x, priceToY(upperData[i])); }
    }
    // 反向遍历下轨
    for (int i = end - 1; i >= start; i--) {
      if (i >= upperData.length || i >= lowerData.length) continue;
      if (!upperData[i].isFinite || !lowerData[i].isFinite) continue;
      final x = (i - start) * totalWidth + totalWidth / 2;
      fillPath.lineTo(x, priceToY(lowerData[i]));
    }
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = AppColors.ma20.withOpacity(0.12));
  }

  /// BOLL 三条线 — stroke 模式
  void _drawBollLines(Canvas canvas, Size size, int start, int end, double totalWidth, double Function(double) priceToY) {
    final lines = [
      (indicators.bollMid, AppColors.ma20),
      (indicators.bollUpper, AppColors.bollUpper),
      (indicators.bollLower, AppColors.bollLower),
    ];

    for (final entry in lines) {
      final data = entry.$1;
      final linePaint = Paint()
        ..color = entry.$2
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final path = Path();
      bool started = false;

      for (int i = start; i < end && i < data.length; i++) {
        if (data[i] == 0 || !data[i].isFinite) continue;
        final x = (i - start) * totalWidth + totalWidth / 2;
        final y = priceToY(data[i]);
        if (!started) { path.moveTo(x, y); started = true; }
        else { path.lineTo(x, y); }
      }

      canvas.drawPath(path, linePaint);
    }
  }

  void _drawPriceLabels(Canvas canvas, Size size, double minPrice, double maxPrice, double Function(double) priceToY) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final price = minPrice + (maxPrice - minPrice) * (4 - i) / 4;
      final y = size.height * i / 4;

      textPainter.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: TextStyle(
          color: AppColors.axisLabel,
          fontSize: ChartConfig.axisLabelFontSize,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 4, y - 6));
    }
  }

  void _drawTimeLabels(Canvas canvas, Size size, List<KlineData> visibleKlines, double totalWidth) {
    if (visibleKlines.isEmpty) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final isIntraday = ['1m', '5m', '15m', '30m', '60m'].contains(period);

    // 根据可见区域宽度决定标签间隔
    final visibleWidth = visibleKlines.length * totalWidth;
    final targetLabelCount = (visibleWidth / 80).floor().clamp(3, 8);
    final step = (visibleKlines.length / targetLabelCount).ceil().clamp(1, visibleKlines.length);

    for (int i = 0; i < visibleKlines.length; i += step) {
      final kline = visibleKlines[i];
      final x = i * totalWidth + totalWidth / 2;

      String label;
      if (isIntraday) {
        // 分钟线: 显示 HH:mm
        label = '${kline.time.hour.toString().padLeft(2, '0')}:'
            '${kline.time.minute.toString().padLeft(2, '0')}';
      } else if (period == 'week' || period == 'month') {
        // 周线/月线: 显示 MM/yyyy
        label = '${kline.time.month.toString().padLeft(2, '0')}/'
            '${kline.time.year}';
      } else {
        // 日线: 显示 MM/DD
        label = '${kline.time.month.toString().padLeft(2, '0')}/'
            '${kline.time.day.toString().padLeft(2, '0')}';
      }

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.axisLabel,
          fontSize: ChartConfig.axisLabelFontSize,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CandlestickPainter oldDelegate) {
    return !identical(oldDelegate.klines, klines) ||
        !identical(oldDelegate.indicators, indicators) ||
        oldDelegate.visibleStart != visibleStart ||
        oldDelegate.visibleEnd != visibleEnd ||
        oldDelegate.candleWidth != candleWidth ||
        oldDelegate.showMA != showMA ||
        oldDelegate.showBOLL != showBOLL ||
        oldDelegate.showBBI != showBBI ||
        oldDelegate.showEXPMA != showEXPMA ||
        oldDelegate.showKTN != showKTN ||
        oldDelegate.period != period;
  }
}
