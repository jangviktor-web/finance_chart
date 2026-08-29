// ignore_for_file: dangling_library_doc_comments
/// 同花顺公募基金数据模型（BYOK，用户自备 Key）
///
/// 覆盖基金基本资料、区间收益、最新净值与重仓股四类高频数据。
/// 字段名严格对齐 THS 官方文档（endpoints-fund.md）。百分数类字段均为「百分数原值」，
/// 服务端未披露时返回 null，严格按原值展示，不补零、不归一化。

/// 基金基本资料
class FundProfile {
  final String thscode;
  final String ticker;
  final String? fundName;
  final int? estabDateMs;
  final String? companyName;
  final String? managerName;
  final double? fundScale;
  final double? unitNav;

  const FundProfile({
    this.thscode = '',
    this.ticker = '',
    this.fundName,
    this.estabDateMs,
    this.companyName,
    this.managerName,
    this.fundScale,
    this.unitNav,
  });

  factory FundProfile.fromMap(Map<String, dynamic> m) {
    return FundProfile(
      thscode: _str(m['thscode']),
      ticker: _str(m['ticker']),
      fundName: m['fund_name']?.toString(),
      estabDateMs: _int(m['estab_date']),
      companyName: m['mgmt_name']?.toString(),
      managerName: m['manager_name']?.toString(),
      fundScale: _num(m['fund_scale']),
      unitNav: _num(m['unit_nav']),
    );
  }

  DateTime? get estabDate =>
      estabDateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(estabDateMs!);
}

/// 基金区间收益（百分数原值）
class FundReturns {
  /// 各区间 → 收益率（百分数原值）；null 表示未披露
  final Map<String, double?> returns;
  /// 各区间 → 同类平均（百分数原值，可能缺失）
  final Map<String, double?> peerAverage;

  const FundReturns({this.returns = const {}, this.peerAverage = const {}});

  factory FundReturns.fromMap(Map<String, dynamic> m) {
    final r = <String, double?>{};
    final p = <String, double?>{};
    const keys = {
      'return_week': '近一周',
      'return_month': '近一月',
      'return_tmonth': '近三月',
      'return_hyear': '近半年',
      'return_year': '近一年',
      'return_twoyear': '近两年',
      'return_tyear': '近三年',
      'return_fyear': '近五年',
      'return_nowyear': '今年以来',
      'return_now': '成立以来',
    };
    keys.forEach((k, label) {
      if (m.containsKey(k)) r[label] = _num(m[k]);
    });
    // 同类平均 peer_average_<key>
    keys.forEach((k, label) {
      final pk = 'peer_average_${k.split('_').last}';
      if (k != 'return_week' && k != 'return_twoyear' && m.containsKey(pk)) {
        p[label] = _num(m[pk]);
      }
    });
    return FundReturns(returns: r, peerAverage: p);
  }

  /// 用于卡片展示的固定顺序
  List<String> get labels => const [
        '近一月', '近三月', '近半年', '近一年', '近三年', '近五年', '今年以来', '成立以来',
      ];
}

/// 基金净值点
class FundNavPoint {
  final int navDateMs;
  final double? unitNav;
  final double? adjNav;

  FundNavPoint({required this.navDateMs, this.unitNav, this.adjNav});

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(navDateMs);
}

/// 基金重仓股
class FundHolding {
  final String stockName;
  final double? holdRatio; // 百分数原值
  final String assetType;
  final double? positionCapital;
  final double? periodIncreaseRatePct;
  final int? investmentRank;

  FundHolding({
    this.stockName = '',
    this.holdRatio,
    this.assetType = '',
    this.positionCapital,
    this.periodIncreaseRatePct,
    this.investmentRank,
  });

  factory FundHolding.fromMap(Map<String, dynamic> m) {
    return FundHolding(
      stockName: m['stock_name']?.toString() ?? '',
      holdRatio: _num(m['hold_ratio']),
      assetType: m['asset_type']?.toString() ?? '',
      positionCapital: _num(m['position_capital']),
      periodIncreaseRatePct: _num(m['period_increase_rate_pct']),
      investmentRank: _int(m['investment_rank']),
    );
  }
}

String _str(dynamic v) => v?.toString() ?? '';
double? _num(dynamic v) => v is num ? v.toDouble() : null;
int? _int(dynamic v) => v is num ? v.toInt() : null;
