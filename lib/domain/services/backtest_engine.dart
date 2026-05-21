import 'dart:math';
import '../../data/models/kline_data.dart';
import '../../data/models/backtest_result.dart';
import '../../data/models/indicator_params.dart';
import 'indicator_calculator.dart';

/// 回测引擎 — 7 种策略
class BacktestEngine {
  final IndicatorCalculator _calculator = IndicatorCalculator();

  /// 运行回测
  BacktestResult run({
    required List<KlineData> klines,
    required String strategy,
    required IndicatorParams params,
    double initialCapital = 100000,
    double commissionRate = 0.0003,  // 万三
    double slippage = 0.001,          // 0.1%
    double stopLoss = 0.08,           // 8%
    double takeProfit = 0.20,         // 20%
    List<KlineData>? benchmarkKlines,
  }) {
    if (klines.length < 60) {
      return _emptyResult(strategy);
    }

    // 预计算所有指标
    final indicators = _calculator.calculateAll(klines, params: params);

    // ── 核心状态：拆分现金和持仓，杜绝双重计算 ──
    double cash = initialCapital;
    bool inPosition = false;
    double entryPrice = 0;
    int entryIndex = 0;
    double quantity = 0;

    double maxEquity = initialCapital;
    double maxDrawdown = 0;
    int maxDrawdownDuration = 0;
    int currentDrawdownDays = 0;
    final equityCurve = <double>[initialCapital];
    final tradeLog = <TradeLogEntry>[];
    double totalCommission = 0;
    double totalSlippage = 0;

    final startIdx = 60;

    for (int i = startIdx; i < klines.length; i++) {
      final signal = _getSignal(klines, i, strategy, indicators, params);
      final currentPrice = klines[i].close;

      if (inPosition) {
        // ── 持仓中：检查止损/止盈/卖出信号 ──
        final pnlPercent = (currentPrice - entryPrice) / entryPrice;

        String? exitSignal;
        if (pnlPercent <= -stopLoss) {
          exitSignal = '止损';
        } else if (pnlPercent >= takeProfit) {
          exitSignal = '止盈';
        } else if (signal == 'sell') {
          exitSignal = '卖出';
        }

        if (exitSignal != null) {
          // ── 卖出：cash = cash + 持仓市值 - 手续费 ──
          final sellPrice = currentPrice * (1 - slippage);
          final proceeds = quantity * sellPrice;
          final commission = proceeds * commissionRate;
          final investedCapital = quantity * entryPrice;
          final pnl = proceeds - investedCapital - commission;

          cash = cash + proceeds - commission;
          totalCommission += commission;
          totalSlippage += proceeds * slippage;

          tradeLog.add(TradeLogEntry(
            entryDate: klines[entryIndex].time,
            exitDate: klines[i].time,
            entryPrice: entryPrice,
            exitPrice: sellPrice,
            quantity: quantity,
            pnl: pnl,
            pnlPercent: pnlPercent,
            investedCapital: investedCapital,
            entrySignal: '买入',
            exitSignal: exitSignal,
          ));

          inPosition = false;
        }
      } else if (signal == 'buy') {
        // ── 买入：用 99% 现金建仓，留 1% 现金缓冲 ──
        final buyPrice = currentPrice * (1 + slippage);
        final investAmount = cash * 0.99;
        final commission = investAmount * commissionRate;
        final actualInvest = investAmount - commission;
        quantity = actualInvest / buyPrice;
        entryPrice = buyPrice;
        entryIndex = i;
        cash = cash - investAmount; // 扣除建仓资金（含手续费）
        totalCommission += commission;
        totalSlippage += actualInvest * slippage;
        inPosition = true;
      }

      // ── 更新权益曲线：总资产 = 现金 + 持仓市值 ──
      final positionValue = inPosition ? quantity * klines[i].close : 0;
      final equity = cash + positionValue;

      if (equity > maxEquity) {
        maxEquity = equity;
        currentDrawdownDays = 0;
      } else {
        currentDrawdownDays++;
        if (currentDrawdownDays > maxDrawdownDuration) {
          maxDrawdownDuration = currentDrawdownDays;
        }
      }

      final dd = (maxEquity - equity) / maxEquity;
      if (dd > maxDrawdown) maxDrawdown = dd;

      equityCurve.add(equity);
    }

    // ── 强制平仓：持仓市值已计入 equity，直接转为现金 ──
    if (inPosition && klines.isNotEmpty) {
      final lastPrice = klines.last.close;
      final sellPrice = lastPrice * (1 - slippage);
      final proceeds = quantity * sellPrice;
      final commission = proceeds * commissionRate;
      final investedCapital = quantity * entryPrice;
      final pnl = proceeds - investedCapital - commission;
      final pnlPercent = (lastPrice - entryPrice) / entryPrice;

      cash = cash + proceeds - commission;
      totalCommission += commission;

      tradeLog.add(TradeLogEntry(
        entryDate: klines[entryIndex].time,
        exitDate: klines.last.time,
        entryPrice: entryPrice,
        exitPrice: sellPrice,
        quantity: quantity,
        pnl: pnl,
        pnlPercent: pnlPercent,
        investedCapital: investedCapital,
        entrySignal: '买入',
        exitSignal: '平仓',
      ));

      inPosition = false;
    }

    // ── 最终 equity = cash（全部平仓后） ──
    final finalEquity = cash;
    final totalReturn = (finalEquity - initialCapital) / initialCapital * 100;
    final tradingDays = klines.length - startIdx;
    final annualizedReturn = tradingDays > 0
        ? ((pow(finalEquity / initialCapital, 252 / tradingDays) - 1) * 100).toDouble()
        : 0.0;

    // 计算基准曲线
    List<double>? benchmarkCurve;
    double? benchmarkReturn;
    if (benchmarkKlines != null && benchmarkKlines.length >= startIdx) {
      final benchStart = benchmarkKlines[startIdx].close;
      benchmarkCurve = <double>[];
      for (int i = startIdx; i < klines.length && (i - startIdx) < equityCurve.length; i++) {
        final bIdx = i < benchmarkKlines.length ? i : benchmarkKlines.length - 1;
        benchmarkCurve.add(initialCapital * benchmarkKlines[bIdx].close / benchStart);
      }
      final benchFinal = benchmarkCurve.isNotEmpty ? benchmarkCurve.last : initialCapital;
      benchmarkReturn = (benchFinal - initialCapital) / initialCapital * 100;
    }

    // 计算交易统计
    final wins = tradeLog.where((t) => t.isWin).toList();
    final losses = tradeLog.where((t) => !t.isWin).toList();
    final avgWin = wins.isNotEmpty ? wins.map((t) => t.pnlPercent).reduce((a, b) => a + b) / wins.length * 100 : 0.0;
    final avgLoss = losses.isNotEmpty ? losses.map((t) => t.pnlPercent).reduce((a, b) => a + b) / losses.length * 100 : 0.0;
    final maxWin = wins.isNotEmpty ? wins.map((t) => t.pnlPercent).reduce(max) * 100 : 0.0;
    final maxLoss = losses.isNotEmpty ? losses.map((t) => t.pnlPercent).reduce(min) * 100 : 0.0;
    final totalWin = wins.isNotEmpty ? wins.map((t) => t.pnl).reduce((a, b) => a + b) : 0.0;
    final totalLoss = losses.isNotEmpty ? losses.map((t) => t.pnl.abs()).reduce((a, b) => a + b) : 0.0001;
    final profitFactor = totalLoss > 0 ? totalWin / totalLoss : 0.0;
    final avgHoldingDays = tradeLog.isNotEmpty
        ? tradeLog.map((t) => t.exitDate.difference(t.entryDate).inDays).reduce((a, b) => a + b) / tradeLog.length
        : 0.0;

    return BacktestResult(
      strategy: strategy,
      totalReturn: totalReturn,
      annualizedReturn: annualizedReturn,
      maxDrawdown: maxDrawdown * 100,
      maxDrawdownDuration: maxDrawdownDuration,
      tradeCount: tradeLog.length,
      winCount: wins.length,
      profitFactor: profitFactor,
      avgWin: avgWin,
      avgLoss: avgLoss,
      maxWin: maxWin,
      maxLoss: maxLoss,
      avgHoldingDays: avgHoldingDays,
      totalCommission: totalCommission,
      totalSlippage: totalSlippage,
      equityCurve: equityCurve,
      benchmarkCurve: benchmarkCurve,
      benchmarkReturn: benchmarkReturn,
      tradeLog: tradeLog,
    );
  }

  /// 获取交易信号
  String _getSignal(List<KlineData> klines, int i, String strategy, indicators, IndicatorParams params) {
    switch (strategy) {
      case 'buy_hold':
        return i == 60 ? 'buy' : 'hold';

      case 'ma_cross':
        if (i < 1) return 'hold';
        final ma5 = indicators.maLines[0];
        final ma20 = indicators.maLines[2];
        if (i >= ma5.length || i >= ma20.length) return 'hold';
        if (ma5[i - 1] <= ma20[i - 1] && ma5[i] > ma20[i]) return 'buy';
        if (ma5[i - 1] >= ma20[i - 1] && ma5[i] < ma20[i]) return 'sell';

      case 'macd_cross':
        if (i < 1) return 'hold';
        final dif = indicators.dif;
        final dea = indicators.dea;
        if (i >= dif.length) return 'hold';
        if (dif[i - 1] <= dea[i - 1] && dif[i] > dea[i]) return 'buy';
        if (dif[i - 1] >= dea[i - 1] && dif[i] < dea[i]) return 'sell';

      case 'kdj_cross':
        if (i < 1) return 'hold';
        final kData = indicators.k;
        final dData = indicators.d;
        final jData = indicators.j;
        if (i >= kData.length) return 'hold';
        if (kData[i - 1] <= dData[i - 1] && kData[i] > dData[i] && jData[i] < 50) return 'buy';
        if (kData[i] > 80 && jData[i] > 80) return 'sell';

      case 'rsi_oversold':
        if (i < 1) return 'hold';
        final rsiData = indicators.rsi;
        if (i >= rsiData.length) return 'hold';
        if (rsiData[i - 1] < 35 && rsiData[i] >= 30) return 'buy';
        if (rsiData[i - 1] > 65 && rsiData[i] <= 70) return 'sell';

      case 'boll_bounce':
        if (i >= indicators.bollMid.length) return 'hold';
        final close = klines[i].close;
        final upper = indicators.bollUpper[i];
        final lower = indicators.bollLower[i];
        if (lower > 0 && close <= lower * 1.01) return 'buy';
        if (upper > 0 && close >= upper * 0.99) return 'sell';

      case 'ensemble':
        // 多信号共振：至少 3 个指标同时发出买入/卖出信号
        int buySignals = 0;
        int sellSignals = 0;

        // MA
        if (i >= 1 && i < indicators.maLines[0].length) {
          final ma5 = indicators.maLines[0];
          final ma20 = indicators.maLines[2];
          if (ma5[i - 1] <= ma20[i - 1] && ma5[i] > ma20[i]) buySignals++;
          if (ma5[i - 1] >= ma20[i - 1] && ma5[i] < ma20[i]) sellSignals++;
        }
        // MACD
        if (i >= 1 && i < indicators.dif.length) {
          if (indicators.dif[i - 1] <= indicators.dea[i - 1] && indicators.dif[i] > indicators.dea[i]) buySignals++;
          if (indicators.dif[i - 1] >= indicators.dea[i - 1] && indicators.dif[i] < indicators.dea[i]) sellSignals++;
        }
        // KDJ
        if (i >= 1 && i < indicators.k.length) {
          if (indicators.k[i] > indicators.d[i] && indicators.j[i] < 50) buySignals++;
          if (indicators.k[i] > 80 && indicators.j[i] > 80) sellSignals++;
        }
        // RSI
        if (i < indicators.rsi.length) {
          if (indicators.rsi[i] < 35) buySignals++;
          if (indicators.rsi[i] > 70) sellSignals++;
        }
        // BOLL
        if (i < indicators.bollLower.length) {
          if (indicators.bollLower[i] > 0 && klines[i].close <= indicators.bollLower[i] * 1.02) buySignals++;
          if (indicators.bollUpper[i] > 0 && klines[i].close >= indicators.bollUpper[i] * 0.98) sellSignals++;
        }

        if (buySignals >= 3) return 'buy';
        if (sellSignals >= 3) return 'sell';
    }
    return 'hold';
  }

  BacktestResult _emptyResult(String strategy) => BacktestResult(
    strategy: strategy,
    totalReturn: 0,
    annualizedReturn: 0,
    maxDrawdown: 0,
    maxDrawdownDuration: 0,
    tradeCount: 0,
    winCount: 0,
    profitFactor: 0,
    avgWin: 0,
    avgLoss: 0,
    maxWin: 0,
    maxLoss: 0,
    avgHoldingDays: 0,
    totalCommission: 0,
    totalSlippage: 0,
    equityCurve: [],
    tradeLog: [],
  );
}
