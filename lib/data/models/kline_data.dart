class KlineData {
  final DateTime time;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;
  final double amount; // 成交额

  const KlineData({
    required this.time,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    this.amount = 0,
  });

  bool get isUp => close >= open;

  double get bodyTop => isUp ? close : open;
  double get bodyBottom => isUp ? open : close;

  factory KlineData.fromJson(List<dynamic> json) {
    return KlineData(
      time: DateTime.parse(json[0] as String),
      open: (json[1] as num).toDouble(),
      close: (json[2] as num).toDouble(),
      high: (json[3] as num).toDouble(),
      low: (json[4] as num).toDouble(),
      volume: (json[5] as num).toDouble(),
      amount: json.length > 6 ? (json[6] as num?)?.toDouble() ?? 0 : 0,
    );
  }

  @override
  String toString() => 'KlineData($time, O:$open C:$close H:$high L:$low V:$volume A:$amount)';
}
