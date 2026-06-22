/// 涨停/跌停池条目
class LimitStock {
  final String code;
  final String name;
  final double price;
  final double changePercent;
  final double amount;       // 成交额
  final String limitType;    // 涨停/跌停/炸板
  final int firstTime;       // 首次封板时间 HHMMSS
  final int lastTime;        // 最后封板时间
  final int openCount;       // 开板次数
  final String industry;     // 所属行业
  final double flowAmount;   // 封板资金

  const LimitStock({
    required this.code,
    required this.name,
    required this.price,
    required this.changePercent,
    this.amount = 0,
    this.limitType = '',
    this.firstTime = 0,
    this.lastTime = 0,
    this.openCount = 0,
    this.industry = '',
    this.flowAmount = 0,
  });
}

/// 龙虎榜条目
class DragonTigerItem {
  final String code;
  final String name;
  final double changePercent;
  final double closePrice;
  final double turnoverRate;
  final double netBuy;       // 龙虎榜净买入
  final double totalBuy;     // 买入总额
  final double totalSell;    // 卖出总额
  final String reason;       // 上榜原因
  final DateTime date;

  const DragonTigerItem({
    required this.code,
    required this.name,
    required this.changePercent,
    required this.closePrice,
    this.turnoverRate = 0,
    this.netBuy = 0,
    this.totalBuy = 0,
    this.totalSell = 0,
    this.reason = '',
    required this.date,
  });
}

/// 北向资金
class NorthboundData {
  final DateTime time;
  final double netBuy;       // 净买入(亿)
  final double totalBuy;
  final double totalSell;

  const NorthboundData({
    required this.time,
    required this.netBuy,
    this.totalBuy = 0,
    this.totalSell = 0,
  });
}

/// 北向资金历史
class NorthboundHistory {
  final DateTime date;
  final double shNet;        // 沪股通净买入
  final double szNet;        // 深股通净买入
  final double totalNet;     // 合计净买入

  const NorthboundHistory({
    required this.date,
    required this.shNet,
    required this.szNet,
    required this.totalNet,
  });
}

/// 融资融券
class MarginData {
  final DateTime date;
  final double rzBalance;    // 融资余额(亿)
  final double rzBuy;        // 融资买入
  final double rqBalance;    // 融券余额
  final double rqSell;       // 融券卖出

  const MarginData({
    required this.date,
    required this.rzBalance,
    this.rzBuy = 0,
    this.rqBalance = 0,
    this.rqSell = 0,
  });
}

/// 板块资金流向
class SectorFlowData {
  final String name;
  final double changePercent;
  final double netInflow;    // 净流入(亿)
  final double mainInflow;   // 主力净流入
  final int upCount;
  final int downCount;
  final String leaderName;
  final double leaderChange;

  const SectorFlowData({
    required this.name,
    required this.changePercent,
    required this.netInflow,
    this.mainInflow = 0,
    this.upCount = 0,
    this.downCount = 0,
    this.leaderName = '',
    this.leaderChange = 0,
  });
}

/// 个股资金流向（单日）
class FundFlowDetail {
  final DateTime date;
  final double mainNet;       // 主力净流入(元)
  final double smallNet;      // 小单净流入
  final double mediumNet;     // 中单净流入
  final double largeNet;      // 大单净流入
  final double superLargeNet; // 超大单净流入
  final double mainPercent;   // 主力净占比%
  final double closePrice;
  final double changePercent;

  const FundFlowDetail({
    required this.date,
    this.mainNet = 0,
    this.smallNet = 0,
    this.mediumNet = 0,
    this.largeNet = 0,
    this.superLargeNet = 0,
    this.mainPercent = 0,
    this.closePrice = 0,
    this.changePercent = 0,
  });
}

/// 大盘资金流快照
class MarketFundFlow {
  final double mainNet;       // 主力净流入(元)
  final double superLargeNet; // 超大单净流入
  final double largeNet;      // 大单净流入
  final double mediumNet;     // 中单净流入
  final double smallNet;      // 小单净流入
  final double mainPercent;   // 主力净占比%

  const MarketFundFlow({
    this.mainNet = 0,
    this.superLargeNet = 0,
    this.largeNet = 0,
    this.mediumNet = 0,
    this.smallNet = 0,
    this.mainPercent = 0,
  });
}

/// 资金流排行条目
class FundFlowRankItem {
  final String code;
  final String name;
  final double price;
  final double changePercent;
  final double mainNet;       // 主力净流入(元)
  final double mainPercent;   // 主力净占比%
  final double superLargeNet;
  final double largeNet;
  final double mediumNet;
  final double smallNet;

  const FundFlowRankItem({
    required this.code,
    required this.name,
    this.price = 0,
    this.changePercent = 0,
    this.mainNet = 0,
    this.mainPercent = 0,
    this.superLargeNet = 0,
    this.largeNet = 0,
    this.mediumNet = 0,
    this.smallNet = 0,
  });
}

/// 北向资金板块排名
class NorthboundBoardRank {
  final String boardName;
  final String boardCode;
  final double holdMarketValue;  // 持股市值(元)
  final double holdPercent;      // 持股占比%
  final double netBuy;           // 净买入(元)
  final double changePercent;    // 涨跌幅%

  const NorthboundBoardRank({
    required this.boardName,
    this.boardCode = '',
    this.holdMarketValue = 0,
    this.holdPercent = 0,
    this.netBuy = 0,
    this.changePercent = 0,
  });
}

/// 个股北向持仓历史
class NorthboundStockHold {
  final DateTime date;
  final double holdShares;     // 持股数量(股)
  final double holdMarketValue; // 持股市值(元)
  final double holdPercent;    // 持股占比%
  final double freePercent;    // 流通股占比%

  const NorthboundStockHold({
    required this.date,
    this.holdShares = 0,
    this.holdMarketValue = 0,
    this.holdPercent = 0,
    this.freePercent = 0,
  });
}

/// 龙虎榜机构席位
class DragonTigerOrgItem {
  final String orgName;        // 机构/营业部名称
  final double buyAmount;      // 买入金额
  final double sellAmount;     // 卖出金额
  final double netAmount;      // 净额
  final double buyPercent;     // 买入占总成交比%
  final double sellPercent;    // 卖出占总成交比%

  const DragonTigerOrgItem({
    required this.orgName,
    this.buyAmount = 0,
    this.sellAmount = 0,
    this.netAmount = 0,
    this.buyPercent = 0,
    this.sellPercent = 0,
  });
}

/// 龙虎榜上榜统计
class DragonTigerStatItem {
  final String code;
  final String name;
  final int totalTimes;        // 总上榜次数
  final int recentTimes;       // 近期上榜次数
  final double totalNetBuy;    // 累计净买入
  final double latestChange;   // 最近一次涨跌幅

  const DragonTigerStatItem({
    required this.code,
    required this.name,
    this.totalTimes = 0,
    this.recentTimes = 0,
    this.totalNetBuy = 0,
    this.latestChange = 0,
  });
}

/// 个股公告条目
class AnnouncementItem {
  final String artCode;       // 公告唯一编号
  final String title;         // 标题
  final DateTime publishTime; // 发布时间
  final List<String> stockCodes; // 关联股票代码
  final String eventType;     // 事件类型: earnings/dividend/insider/notice等
  final int importance;       // 重要性 0-3
  final String url;           // 原文链接

  const AnnouncementItem({
    required this.artCode,
    required this.title,
    required this.publishTime,
    this.stockCodes = const [],
    this.eventType = 'notice',
    this.importance = 0,
    this.url = '',
  });
}

/// 板块成分股条目
class BoardStockItem {
  final String code;
  final String name;
  final double price;
  final double changePercent;
  final double turnover;      // 成交额
  final double volume;        // 成交量

  const BoardStockItem({
    required this.code,
    required this.name,
    this.price = 0,
    this.changePercent = 0,
    this.turnover = 0,
    this.volume = 0,
  });
}
