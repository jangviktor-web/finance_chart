/// 同花顺扩展特色数据模型（连板天梯 / 异动 / 热股飙升榜 / 估值快照）

/// 连板天梯单只股票
class LadderStock {
  final String code;        // App 内部代码（sh600519）
  final String name;
  final int boardNum;       // 连板天数
  final String signLevel;   // 标记级别
  final String? sealNextDay; // 次日封板情况（最近交易日为 null）

  const LadderStock({
    required this.code,
    required this.name,
    required this.boardNum,
    this.signLevel = '',
    this.sealNextDay,
  });
}

/// 连板天梯某交易日
class LadderDay {
  final String date;
  final List<LadderStock> stocks; // 该日所有梯队股票（含 boardNum）

  const LadderDay({required this.date, required this.stocks});
}

/// 当日个股异动原因
class AnomalyItem {
  final String stockName;
  final String analysisContent;
  final List<String> keywords;
  final String code;     // App 内部代码
  final String tagName;  // 异动标签（涨停/跌停/大幅上涨...）

  const AnomalyItem({
    required this.stockName,
    required this.analysisContent,
    required this.keywords,
    required this.code,
    required this.tagName,
  });
}

/// 热股榜 / 飙升榜条目
class RankStockItem {
  final String code;
  final String name;
  final int rank;
  final double heat;
  final int rankChange;  // 排名变化（正=上升）
  final String rankTrend; // 排名趋势标记

  const RankStockItem({
    required this.code,
    required this.name,
    required this.rank,
    this.heat = 0,
    this.rankChange = 0,
    this.rankTrend = '',
  });
}

/// 估值快照（PE/PB/PS/PCF）
class ValuationSnapshot {
  final String code;
  final String name;
  final double? peTtm;
  final double? peMrq;
  final double? pbMrq;
  final double? psTtm;
  final double? pcfTtm;

  const ValuationSnapshot({
    required this.code,
    required this.name,
    this.peTtm,
    this.peMrq,
    this.pbMrq,
    this.psTtm,
    this.pcfTtm,
  });
}
