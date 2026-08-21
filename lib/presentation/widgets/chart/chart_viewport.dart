import 'package:flutter/widgets.dart';
import '../../../data/models/kline_data.dart';

/// 图表视口与交互状态（P1-5）
///
/// 手势（滑动/缩放/十字线）只更新本对象并 notifyListeners，
/// 各 CustomPainter 通过 `repaint: viewport` 订阅，实现「只重绘、不重建」：
/// - 手势帧不再触发整棵 widget 树 build（原实现每帧 setState）
/// - 数据/指标切换时才重建 widget 树（低频）
class ChartViewport extends ChangeNotifier {
  int visibleStart = 0;
  int visibleEnd = 0;
  double candleWidth = 10;

  bool isCrosshairMode = false;
  Offset? crosshairPosition;
  KlineData? crosshairKline;

  /// 更新可见区间与蜡烛宽度
  void updateRange({
    required int start,
    required int end,
    required double width,
  }) {
    visibleStart = start;
    visibleEnd = end;
    candleWidth = width;
    notifyListeners();
  }

  /// 更新十字线位置与对应 K 线
  void setCrosshair(Offset? position, KlineData? kline) {
    crosshairPosition = position;
    crosshairKline = kline;
    notifyListeners();
  }

  /// 进入/退出十字线模式
  void setCrosshairMode(bool active) {
    isCrosshairMode = active;
    notifyListeners();
  }
}
