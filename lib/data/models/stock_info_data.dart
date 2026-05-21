/// 股东人数
class ShareholderData {
  final String date;
  final int holderCount;     // 股东人数
  final double avgAmount;    // 人均持股金额
  final double changePercent; // 环比变化 %

  const ShareholderData({
    required this.date,
    required this.holderCount,
    this.avgAmount = 0,
    this.changePercent = 0,
  });
}

/// 估值数据
class ValuationData {
  final double pe;           // 市盈率
  final double pb;           // 市净率
  final double ps;           // 市销率
  final double pcf;          // 市现率
  final double totalMarketCap; // 总市值(亿)
  final double circulatingCap; // 流通市值(亿)
  final double dividendYield;  // 股息率 %

  const ValuationData({
    this.pe = 0,
    this.pb = 0,
    this.ps = 0,
    this.pcf = 0,
    this.totalMarketCap = 0,
    this.circulatingCap = 0,
    this.dividendYield = 0,
  });
}

/// 大宗交易
class BlockTrade {
  final DateTime date;
  final double price;
  final double volume;       // 成交量(万股)
  final double amount;       // 成交额(万元)
  final double premiumRate;  // 溢/折价率 %
  final String buyer;        // 买方营业部
  final String seller;       // 卖方营业部

  const BlockTrade({
    required this.date,
    required this.price,
    required this.volume,
    required this.amount,
    this.premiumRate = 0,
    this.buyer = '',
    this.seller = '',
  });
}

/// 限售解禁
class RestrictedShare {
  final DateTime date;
  final double amount;       // 解禁市值(亿)
  final double volume;       // 解禁股数(万股)
  final String type;         // 解禁类型

  const RestrictedShare({
    required this.date,
    required this.amount,
    required this.volume,
    this.type = '',
  });
}
