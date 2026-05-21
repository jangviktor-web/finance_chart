/// 宏观经济指标数据点
class MacroDataPoint {
  final String period;       // 如 "2025-Q4", "2025-12"
  final double value;
  final double? yoy;         // 同比 %
  final double? mom;         // 环比 %

  const MacroDataPoint({
    required this.period,
    required this.value,
    this.yoy,
    this.mom,
  });
}

/// 宏观指标集合
class MacroIndicator {
  final String name;         // CPI, GDP, PMI 等
  final String unit;         // %, 万亿 等
  final List<MacroDataPoint> data;
  final double? latestValue;
  final double? latestYoy;

  const MacroIndicator({
    required this.name,
    required this.unit,
    required this.data,
    this.latestValue,
    this.latestYoy,
  });
}

/// LPR 数据
class LprData {
  final String date;
  final double lpr1y;        // 1年期 LPR
  final double lpr5y;        // 5年期 LPR

  const LprData({
    required this.date,
    required this.lpr1y,
    required this.lpr5y,
  });
}
