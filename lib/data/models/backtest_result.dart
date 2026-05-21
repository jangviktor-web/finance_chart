/// 回测结果模型 — 完整指标
class BacktestResult {
  final String strategy;
  final double totalReturn;        // 总收益率 %
  final double annualizedReturn;   // 年化收益率 %
  final double maxDrawdown;        // 最大回撤 %
  final int maxDrawdownDuration;   // 最大回撤持续天数
  final int tradeCount;            // 交易次数
  final int winCount;              // 盈利次数
  final double profitFactor;       // 利润因子
  final double avgWin;             // 平均盈利 %
  final double avgLoss;            // 平均亏损 %
  final double maxWin;             // 最大单笔盈利 %
  final double maxLoss;            // 最大单笔亏损 %
  final double avgHoldingDays;     // 平均持仓天数
  final double totalCommission;    // 总手续费
  final double totalSlippage;      // 总滑点成本
  final List<double> equityCurve;  // 权益曲线
  final List<double>? benchmarkCurve;  // 基准曲线
  final double? benchmarkReturn;   // 基准收益率 %
  final List<TradeLogEntry> tradeLog;  // 交易日志

  const BacktestResult({
    required this.strategy,
    required this.totalReturn,
    required this.annualizedReturn,
    required this.maxDrawdown,
    required this.maxDrawdownDuration,
    required this.tradeCount,
    required this.winCount,
    required this.profitFactor,
    required this.avgWin,
    required this.avgLoss,
    required this.maxWin,
    required this.maxLoss,
    required this.avgHoldingDays,
    required this.totalCommission,
    required this.totalSlippage,
    required this.equityCurve,
    this.benchmarkCurve,
    this.benchmarkReturn,
    required this.tradeLog,
  });

  double get winRate => tradeCount > 0 ? winCount / tradeCount * 100 : 0;
  double? get alpha => benchmarkReturn != null ? totalReturn - benchmarkReturn! : null;

  /// Sharpe 比率（简化版，假设无风险利率 3%）
  double get sharpeRatio {
    if (equityCurve.length < 2) return 0;
    final returns = <double>[];
    for (int i = 1; i < equityCurve.length; i++) {
      returns.add((equityCurve[i] - equityCurve[i - 1]) / equityCurve[i - 1]);
    }
    if (returns.isEmpty) return 0;
    final avg = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.map((r) => (r - avg) * (r - avg)).reduce((a, b) => a + b) / returns.length;
    final std = variance > 0 ? variance : 0.0001;
    // 年化: 日收益率 * 252
    return (avg * 252 - 0.03) / (std * 252);
  }
}

/// 交易日志条目
class TradeLogEntry {
  final DateTime entryDate;
  final DateTime exitDate;
  final double entryPrice;
  final double exitPrice;
  final double quantity;
  final double pnl;             // 实际盈亏金额
  final double pnlPercent;      // 盈亏百分比
  final double investedCapital; // 建仓金额（仓位）
  final String entrySignal;
  final String exitSignal;

  const TradeLogEntry({
    required this.entryDate,
    required this.exitDate,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    required this.pnl,
    required this.pnlPercent,
    this.investedCapital = 0,
    required this.entrySignal,
    required this.exitSignal,
  });

  bool get isWin => pnl > 0;
}
