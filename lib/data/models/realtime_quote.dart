class RealtimeQuote {
  final String code;
  final String name;
  final double now;
  final double yesterday;
  final double high;
  final double low;
  final double volume;
  final double amount;
  final DateTime? time;

  const RealtimeQuote({
    required this.code,
    required this.name,
    required this.now,
    required this.yesterday,
    required this.high,
    required this.low,
    this.volume = 0,
    this.amount = 0,
    this.time,
  });

  double get change => now - yesterday;
  double get changePercent => yesterday > 0 ? (change / yesterday * 100) : 0;
  bool get isUp => change >= 0;

  factory RealtimeQuote.empty() => const RealtimeQuote(
    code: '',
    name: '--',
    now: 0,
    yesterday: 0,
    high: 0,
    low: 0,
  );

  @override
  String toString() => 'RealtimeQuote($code $name $now ${changePercent.toStringAsFixed(2)}%)';
}
