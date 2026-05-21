/// 全市场扫描结果
class ScanResult {
  final String code;
  final String name;
  final double price;
  final double changePercent;
  final String signal;       // 策略信号: "MA金叉买入", "KDJ超卖反弹" 等
  final String strategy;     // 匹配的策略名称
  final double winRate;      // 该策略历史胜率
  final double expectedRange; // 预期日内涨幅区间 (%)
  final DateTime scanTime;

  const ScanResult({
    required this.code,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.signal,
    required this.strategy,
    required this.winRate,
    required this.expectedRange,
    required this.scanTime,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'price': price,
    'changePercent': changePercent,
    'signal': signal,
    'strategy': strategy,
    'winRate': winRate,
    'expectedRange': expectedRange,
    'scanTime': scanTime.toIso8601String(),
  };

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      code: json['code'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      signal: json['signal'] as String,
      strategy: json['strategy'] as String,
      winRate: (json['winRate'] as num).toDouble(),
      expectedRange: (json['expectedRange'] as num).toDouble(),
      scanTime: DateTime.parse(json['scanTime'] as String),
    );
  }
}

/// 扫描任务状态
enum ScanStatus {
  idle,       // 未扫描
  scanning,   // 扫描中
  completed,  // 扫描完成
  error,      // 扫描失败
}

/// 扫描配置
class ScanConfig {
  final String strategy;        // 使用的策略
  final bool filterST;          // 过滤 ST
  final bool filterNewStock;    // 过滤次新股
  final bool filterSTAR;        // 过滤科创板
  final bool filterChiNext;     // 过滤创业板
  final double minMarketCap;    // 最小市值 (亿)

  const ScanConfig({
    this.strategy = 'all',
    this.filterST = true,
    this.filterNewStock = true,
    this.filterSTAR = false,
    this.filterChiNext = false,
    this.minMarketCap = 0,
  });
}
