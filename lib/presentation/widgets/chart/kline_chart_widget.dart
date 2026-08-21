import 'package:flutter/material.dart';
import '../../../data/models/kline_data.dart';
import '../../../data/models/indicator_data.dart';
import '../../../core/constants/chart_config.dart';
import '../../../app/theme.dart';
import 'candlestick_painter.dart';
import 'volume_painter.dart';
import 'indicator_painter_registry.dart';
import 'crosshair_painter.dart';

class KlineChartWidget extends StatefulWidget {
  final List<KlineData> klines;
  final IndicatorData indicators;
  final String selectedIndicator; // 副图指标
  final Set<String> activeOverlays; // 叠加指标
  final String period;

  const KlineChartWidget({
    super.key,
    required this.klines,
    required this.indicators,
    this.selectedIndicator = 'MACD',
    this.activeOverlays = const {'MA'},
    this.period = 'day',
  });

  @override
  State<KlineChartWidget> createState() => _KlineChartWidgetState();
}

class _KlineChartWidgetState extends State<KlineChartWidget> with TickerProviderStateMixin {
  late int _visibleStart;
  late int _visibleEnd;
  late double _candleWidth;

  bool _isCrosshairMode = false;
  Offset? _crosshairPosition;
  KlineData? _crosshairKline;

  AnimationController? _inertiaController;
  double _inertiaVelocity = 0;

  @override
  void initState() {
    super.initState();
    _candleWidth = ChartConfig.candleDefaultWidth;
    _updateVisibleRange();
  }

  @override
  void didUpdateWidget(covariant KlineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 比较 klines 内容而非仅长度（数据更新但长度不变时也需刷新）
    final lengthChanged = oldWidget.klines.length != widget.klines.length;
    final contentChanged = !lengthChanged && widget.klines.isNotEmpty &&
        oldWidget.klines.isNotEmpty &&
        oldWidget.klines.last.close != widget.klines.last.close;
    if (lengthChanged || contentChanged) {
      _updateVisibleRange();
    }
  }

  void _updateVisibleRange() {
    final count = widget.klines.length;
    if (count == 0) {
      _visibleStart = 0;
      _visibleEnd = 0;
      return;
    }
    final visibleCount = (ChartConfig.defaultVisibleCount * ChartConfig.candleDefaultWidth / _candleWidth).round()
        .clamp(ChartConfig.minVisibleCount, count);
    _visibleEnd = count;
    _visibleStart = (count - visibleCount).clamp(0, count);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.klines.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _isCrosshairMode ? _onCrosshairUpdate : null,
      onLongPressEnd: _onLongPressEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(flex: 5, child: _buildMainChart(constraints.maxWidth)),
              Expanded(flex: 2, child: _buildVolumeChart(constraints.maxWidth)),
              Expanded(flex: 3, child: _buildIndicatorChart(constraints.maxWidth)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainChart(double width) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, double.infinity),
        painter: CandlestickPainter(
          klines: widget.klines,
          indicators: widget.indicators,
          visibleStart: _visibleStart,
          visibleEnd: _visibleEnd,
          candleWidth: _candleWidth,
          showMA: widget.activeOverlays.contains('MA'),
          showBOLL: widget.activeOverlays.contains('BOLL'),
          showBBI: widget.activeOverlays.contains('BBI'),
          showEXPMA: widget.activeOverlays.contains('EXPMA'),
          showKTN: widget.activeOverlays.contains('KTN'),
          period: widget.period,
        ),
        foregroundPainter: _isCrosshairMode
            ? CrosshairPainter(
                position: _crosshairPosition,
                kline: _crosshairKline,
                candleWidth: _candleWidth,
                visibleStart: _visibleStart,
                visibleEnd: _visibleEnd,
                period: widget.period,
              )
            : null,
      ),
    );
  }

  Widget _buildVolumeChart(double width) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, double.infinity),
        painter: VolumePainter(
          klines: widget.klines,
          visibleStart: _visibleStart,
          visibleEnd: _visibleEnd,
          candleWidth: _candleWidth,
        ),
      ),
    );
  }

  Widget _buildIndicatorChart(double width) {
    final painter = _createIndicatorPainter();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, double.infinity),
        painter: painter,
      ),
    );
  }

  CustomPainter _createIndicatorPainter() {
    // P1-6: 通过注册表创建，新增指标无需改动本组件
    final builder = indicatorPainterRegistry[widget.selectedIndicator] ??
        indicatorPainterRegistry['MACD']!;
    return builder(widget.indicators, _visibleStart, _visibleEnd, _candleWidth);
  }

  // 手势处理 — 统一由 onScale* 处理滑动和缩放
  void _onScaleStart(ScaleStartDetails details) {
    _stopInertia();
    _panAccumulator = 0;
  }

  double _panAccumulator = 0;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.klines.isEmpty) return;

    // 十字线模式：由 onLongPressMoveUpdate 处理
    if (_isCrosshairMode) return;

    if (details.scale != 1.0) {
      // 双指缩放
      setState(() {
        _candleWidth = (_candleWidth * details.scale).clamp(ChartConfig.candleMinWidth, ChartConfig.candleMaxWidth);
        final center = (_visibleStart + _visibleEnd) ~/ 2;
        final visibleCount = (ChartConfig.defaultVisibleCount * ChartConfig.candleDefaultWidth / _candleWidth).round()
            .clamp(ChartConfig.minVisibleCount, ChartConfig.maxVisibleCount);
        var newStart = center - visibleCount ~/ 2;
        var newEnd = center + visibleCount ~/ 2;
        if (newStart < 0) { newStart = 0; newEnd = visibleCount; }
        if (newEnd > widget.klines.length) { newEnd = widget.klines.length; newStart = newEnd - visibleCount; }
        _visibleStart = newStart.clamp(0, widget.klines.length);
        _visibleEnd = newEnd.clamp(_visibleStart + ChartConfig.minVisibleCount, widget.klines.length);
      });
    } else {
      // 单指滑动 — 累积亚像素位移，避免因 .round() 丢失微小移动
      final totalWidth = _candleWidth + ChartConfig.candleSpacing;
      _panAccumulator += details.focalPointDelta.dx;
      final shift = (_panAccumulator / totalWidth).round();
      if (shift == 0) return;
      _panAccumulator -= shift * totalWidth;

      final visibleCount = _visibleEnd - _visibleStart;
      var newStart = _visibleStart - shift;
      var newEnd = _visibleEnd - shift;
      if (newStart < 0) { newStart = 0; newEnd = visibleCount; }
      if (newEnd > widget.klines.length) { newEnd = widget.klines.length; newStart = newEnd - visibleCount; }
      setState(() {
        _visibleStart = newStart.clamp(0, widget.klines.length);
        _visibleEnd = newEnd.clamp(_visibleStart + ChartConfig.minVisibleCount, widget.klines.length);
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _inertiaVelocity = details.velocity.pixelsPerSecond.dx;
    if (!_isCrosshairMode && _inertiaVelocity.abs() > 100) _startInertia();
  }

  void _startInertia() {
    _inertiaController?.dispose();
    _inertiaController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    final animation = Tween<double>(begin: _inertiaVelocity, end: 0).animate(
      CurvedAnimation(parent: _inertiaController!, curve: Curves.decelerate),
    );
    animation.addListener(() {
      final totalWidth = _candleWidth + ChartConfig.candleSpacing;
      final shift = (animation.value / totalWidth * 0.016).round();
      if (shift != 0) {
        setState(() {
          _visibleStart = (_visibleStart - shift).clamp(0, widget.klines.length - ChartConfig.minVisibleCount);
          _visibleEnd = (_visibleEnd - shift).clamp(ChartConfig.minVisibleCount, widget.klines.length);
        });
      }
    });
    _inertiaController!.forward();
  }

  void _stopInertia() => _inertiaController?.stop();

  void _onLongPressStart(LongPressStartDetails details) {
    _stopInertia();
    setState(() {
      _isCrosshairMode = true;
      _crosshairPosition = details.localPosition;
      _updateCrosshairData(details.localPosition);
    });
  }

  void _onCrosshairUpdate(LongPressMoveUpdateDetails details) {
    setState(() {
      _crosshairPosition = details.localPosition;
      _updateCrosshairData(details.localPosition);
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isCrosshairMode = false;
      _crosshairPosition = null;
      _crosshairKline = null;
    });
  }

  void _updateCrosshairData(Offset position) {
    final totalWidth = _candleWidth + ChartConfig.candleSpacing;
    final index = _visibleStart + (position.dx / totalWidth).floor();
    if (index >= 0 && index < widget.klines.length) {
      _crosshairKline = widget.klines[index];
    }
  }

  @override
  void dispose() {
    _inertiaController?.dispose();
    super.dispose();
  }
}
