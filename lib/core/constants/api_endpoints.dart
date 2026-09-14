class ApiEndpoints {
  // ── 腾讯 ──
  static const String tencentRealtime = 'https://qt.gtimg.cn/q=';
  static const String tencentKline = 'https://web.ifzq.gtimg.cn/appstock/app/fqkline/get';
  /// 龙虎榜每日榜单（keyless 免鉴权，与东财报告期为两条独立链路）
  static const String tencentLhbDaily = 'https://proxy.finance.qq.com/cgi/cgi-bin/longhubang/lhbDetail';
  /// 个股龙虎榜详情（keyless）— 注意参数名是 `stockCode`，不是 `code`
  static const String tencentLhbStock = 'https://proxy.finance.qq.com/cgi/cgi-bin/longhubang/stockDetail';

  // ── 东方财富 ──
  static const String eastmoneyRealtime = 'https://push2.eastmoney.com/api/qt/ulist.np/get';
  static const String eastmoneyBase = 'https://datacenter-web.eastmoney.com';
  static const String eastmoneyPush = 'https://push2.eastmoney.com';

  // ── 东财镜像主机（2026-09 实测，可互为备份）──
  /// datacenter-web 的镜像：**所有 reportName 响应体字节级一致**（连 version 哈希
  /// 与报错文案都相同），可无条件互备，且享受独立的限流配额桶。
  static const String eastmoneyBaseMirror = 'https://datacenter.eastmoney.com';
  /// push2 的镜像：**仅实时类路径**（clist / ulist.np / kamt.rtmin / trends2）可用。
  /// ⚠️ 历史类路径（stock/kline、stock/fflow/daykline）**不是**镜像 —— kline 返回
  /// 空数组 `"klines":[]`、fflow 只返回当日 1 条，会**静默丢数据**（HTTP 200），
  /// 故 history 路径不得走此镜像。
  static const String eastmoneyPushMirror = 'https://push2delay.eastmoney.com';

  /// 东财主域 URL → 镜像 URL；无镜像可用的 host 原样返回（幂等，可安全重复调用）。
  ///
  /// 与 `firstSuccess` 配合即可得到「同源不同机」冗余：
  /// ```dart
  /// firstSuccess([
  ///   DataSourceAttempt('em:dc.cpi', () => _get(ApiEndpoints.macroCpi)),
  ///   DataSourceAttempt('em:dc.cpi.mirror', () => _get(ApiEndpoints.mirrorOf(ApiEndpoints.macroCpi))),
  /// ]);
  /// ```
  static String mirrorOf(String url) {
    if (url.startsWith(eastmoneyBase)) {
      return url.replaceFirst(eastmoneyBase, eastmoneyBaseMirror);
    }
    // push2his 不会被误匹配：'push2his.eastmoney.com' 不以 'push2.eastmoney.com' 开头。
    if (url.startsWith(eastmoneyPush)) {
      return url.replaceFirst(eastmoneyPush, eastmoneyPushMirror);
    }
    return url;
  }

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
