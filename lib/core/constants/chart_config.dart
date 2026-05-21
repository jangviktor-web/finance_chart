class ChartConfig {
  static const double candleMinWidth = 3.0;
  static const double candleMaxWidth = 20.0;
  static const double candleDefaultWidth = 8.0;
  static const double candleSpacing = 2.0;

  static const double volumeHeightRatio = 0.2;  // 成交量区域占比
  static const double indicatorHeightRatio = 0.15; // 指标子图占比

  static const int defaultVisibleCount = 60;  // 默认显示蜡烛数
  static const int minVisibleCount = 10;
  static const int maxVisibleCount = 200;

  static const double pricePadding = 0.05;  // 价格区间上下留白 5%
  static const double gridLineWidth = 0.5;
  static const double axisLabelFontSize = 10.0;

  // 手势阈值
  static const double longPressThreshold = 300; // 长按触发时间(ms)
  static const double inertiaFriction = 0.92;   // 惯性摩擦系数
}
