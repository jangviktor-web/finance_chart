/// 多维评分模型
class StockScore {
  final String code;
  final String name;
  final double valuation;  // 估值 0-100
  final double momentum;   // 动量 0-100
  final double volatility; // 波动 0-100
  final double trend;      // 趋势 0-100
  final double volume;     // 量能 0-100

  const StockScore({
    required this.code,
    required this.name,
    required this.valuation,
    required this.momentum,
    required this.volatility,
    required this.trend,
    required this.volume,
  });

  double get total => (valuation + momentum + volatility + trend + volume) / 5;

  List<double> get values => [valuation, momentum, volatility, trend, volume];

  static const List<String> dimensionLabels = ['估值', '动量', '波动', '趋势', '量能'];

  @override
  String toString() => 'StockScore($code $name, total=${total.toStringAsFixed(1)})';
}
