// ignore_for_file: dangling_library_doc_comments
/// 同花顺集合竞价快照模型（BYOK，用户自备 Key）
///
/// 数据来自 GET /api/a-share/auction/snapshot，单只或多只 A 股。
/// 数值字段在「未就绪/停牌」时为空，严格按服务端返回展示，不补零、不模拟。
/// 字段名对齐 THS 官方文档（endpoints-auction.md）。

class AuctionSnapshot {
  final String thscode;
  final String ticker;
  final String name;
  final String? dataStatus; // ready / final / suspended / not_ready
  final String? auctionPhase;

  final double? auctionPrice;
  final double? auctionPct; // 竞价涨跌幅（百分数原值）
  final double? auctionVolume; // 手
  final double? auctionAmount;
  final double? auctionUnmatched;
  final double? auctionTurnoverPct; // 换手率（百分数原值）
  final double? auctionYesterdayRatioPct; // 相对昨日成交量比例
  final double? auctionVolumeRatio; // 竞价量比

  final double? preClosePrice;
  final double? openPrice;
  final double? lastPrice;
  final double? floatMarketCap;

  const AuctionSnapshot({
    this.thscode = '',
    this.ticker = '',
    this.name = '',
    this.dataStatus,
    this.auctionPhase,
    this.auctionPrice,
    this.auctionPct,
    this.auctionVolume,
    this.auctionAmount,
    this.auctionUnmatched,
    this.auctionTurnoverPct,
    this.auctionYesterdayRatioPct,
    this.auctionVolumeRatio,
    this.preClosePrice,
    this.openPrice,
    this.lastPrice,
    this.floatMarketCap,
  });

  /// 是否拿到有效竞价价格（区分未就绪/停牌）
  bool get hasPrice => auctionPrice != null;

  factory AuctionSnapshot.fromMap(Map<String, dynamic> m) {
    return AuctionSnapshot(
      thscode: _str(m['thscode']),
      ticker: _str(m['ticker']),
      name: _str(m['name']),
      dataStatus: m['data_status']?.toString(),
      auctionPhase: m['auction_phase']?.toString(),
      auctionPrice: _num(m['auction_price']),
      auctionPct: _num(m['auction_pct']),
      auctionVolume: _num(m['auction_volume']),
      auctionAmount: _num(m['auction_amount']),
      auctionUnmatched: _num(m['auction_unmatched']),
      auctionTurnoverPct: _num(m['auction_turnover_pct']),
      auctionYesterdayRatioPct: _num(m['auction_yesterday_ratio_pct']),
      auctionVolumeRatio: _num(m['auction_volume_ratio']),
      preClosePrice: _num(m['pre_close_price']),
      openPrice: _num(m['open_price']),
      lastPrice: _num(m['last_price']),
      floatMarketCap: _num(m['float_market_cap']),
    );
  }
}

String _str(dynamic v) => v?.toString() ?? '';
double? _num(dynamic v) => v is num ? v.toDouble() : null;
