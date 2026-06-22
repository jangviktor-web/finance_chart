class ApiEndpoints {
  // ── 腾讯 ──
  static const String tencentRealtime = 'https://qt.gtimg.cn/q=';
  static const String tencentKline = 'https://web.ifzq.gtimg.cn/appstock/app/fqkline/get';

  // ── 东方财富 ──
  static const String eastmoneyRealtime = 'https://push2.eastmoney.com/api/qt/ulist.np/get';
  static const String eastmoneyBase = 'https://datacenter-web.eastmoney.com';
  static const String eastmoneyPush = 'https://push2.eastmoney.com';

  // ── 新浪 ──
  static const String sinaMinute = 'https://money.finance.sina.com.cn/quotes_service/api/json_v2.php/CN_MarketData.getKLineData';

  // ── 情绪面 ──
  // 涨停池/跌停池
  static const String limitUpPool = '$eastmoneyBase/api/data/v1/get';
  static const String limitDownPool = '$eastmoneyBase/api/data/v1/get';
  // 龙虎榜
  static const String dragonTiger = '$eastmoneyBase/api/data/v1/get';
  // 北向资金
  static const String northbound = '$eastmoneyPush/api/qt/kamt.rtmin/get';
  static const String northboundHistory = '$eastmoneyBase/api/data/v1/get';
  // 融资融券
  static const String margin = '$eastmoneyBase/api/data/v1/get';
  // 板块资金流向
  static const String sectorFlow = '$eastmoneyPush/api/qt/clist/get';

  // push2his 数据源（K线 + 资金流）
  static const String eastmoneyPushHis = 'https://push2his.eastmoney.com';
  static const String eastmoneyKline = '$eastmoneyPushHis/api/qt/stock/kline/get';
  static const String eastmoneyTrends = '$eastmoneyPushHis/api/qt/stock/trends2/get';
  static const String fundFlowKline = '$eastmoneyPushHis/api/qt/stock/fflow/daykline/get';
  static const String fundFlowRank = '$eastmoneyPush/api/qt/clist/get';
  static const String marketFundFlow = '$eastmoneyPush/api/qt/ulist.np/get';

  // ── 宏观数据 ──
  static const String macroCpi = '$eastmoneyBase/api/data/v1/get';
  static const String macroPpi = '$eastmoneyBase/api/data/v1/get';
  static const String macroGdp = '$eastmoneyBase/api/data/v1/get';
  static const String macroPmi = '$eastmoneyBase/api/data/v1/get';
  static const String macroM2 = '$eastmoneyBase/api/data/v1/get';
  static const String macroLpr = '$eastmoneyBase/api/data/v1/get';

  // ── 新闻 ──
  static const String news7x24 = 'https://np-listapi.eastmoney.com/comm/web/getNewsByColumns';
  static const String clsNews = 'https://www.cls.cn/nodeapi/updateTelegraphList';
  static const String newsSearch = 'https://search-api-web.eastmoney.com/search/jsonp';

  // ── 个股深度 ──
  static const String shareholders = '$eastmoneyBase/api/data/v1/get';
  static const String valuation = '$eastmoneyBase/api/data/v1/get';
  static const String blockTrades = '$eastmoneyBase/api/data/v1/get';
  static const String restrictedShares = '$eastmoneyBase/api/data/v1/get';

  // ── 公告 ──
  static const String announcements = 'https://np-anotice-stock.eastmoney.com/api/security/ann';
  static const String announcementContent = 'https://np-cnotice-stock.eastmoney.com/api/content/ann';

  // ── 板块成分股 ──
  static const String boardStocks = '$eastmoneyPush/api/qt/clist/get';
}
