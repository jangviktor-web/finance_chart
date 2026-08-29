// ignore_for_file: dangling_library_doc_comments
/// 同花顺财务数据模型（利润表 / 资产负债表 / 现金流量表 / 财务指标）
///
/// 采用「报告期 + 字段映射」的通用结构，避免为 60+ 字段各建强类型类；
/// UI 按中文标签取数展示。数据来源：同花顺 Financial-API（BYOK，用户自备 Key）。
///
/// 字段名严格对齐 THS 官方文档（endpoints-financials.md）：
///   利润表 21 字段 / 资产负债表 15 字段 / 现金流量表 14 字段；
///   财务指标返回 {thscode, report, abilities[]}，abilities 为五类指标数组。

/// 单期报表
class FinancialPeriod {
  final String thscode;
  final String period; // 'annual' | 'quarterly'
  final int periodEndMs;
  final int reportDateMs;
  final int fiscalYear;
  final String fiscalPeriod; // 如 'FY' / 'Q1'
  final String currency; // A 股恒为 CNY
  /// 原始字段名 → 数值（null 表示该报告期未披露，不补零）
  final Map<String, double?> items;

  const FinancialPeriod({
    required this.thscode,
    required this.period,
    required this.periodEndMs,
    required this.reportDateMs,
    required this.fiscalYear,
    required this.fiscalPeriod,
    required this.currency,
    required this.items,
  });

  /// 报告期标签，如 2024 年报 / 2024 Q3
  String get label {
    final y = fiscalYear.toString();
    if (fiscalPeriod.toUpperCase() == 'FY' || period == 'annual') return '$y年报';
    return '$y $fiscalPeriod';
  }

  DateTime get periodEnd => DateTime.fromMillisecondsSinceEpoch(periodEndMs);

  double? operator [](String key) => items[key];
}

/// 一张报表（多期，已按报告期降序）
class FinancialStatement {
  final List<FinancialPeriod> periods;

  const FinancialStatement(this.periods);

  bool get isEmpty => periods.isEmpty;

  /// 取某字段跨期序列（按报告期降序），用于简易趋势
  List<double?> column(String field) => periods.map((p) => p[field]).toList();
}

/// 财务指标分组（对应 abilities[] 的一个元素）
class FinancialIndicatorGroup {
  final String ability; // growth / profitability / solvency / operation / cash-flow
  final List<FinancialIndicatorItem> items;

  FinancialIndicatorGroup(this.ability, this.items);

  /// 类别中文名
  String get abilityName => kIndicatorAbilityLabels[ability] ?? ability;
}

/// 单个指标（index_id + value）
class FinancialIndicatorItem {
  final String indexId;
  final double? value;

  FinancialIndicatorItem(this.indexId, this.value);

  /// 指标中文名（已知映射优先，否则对 index_id 做可读化兜底）
  String get name => kIndicatorLabels[indexId] ?? _humanizeIndexId(indexId);
}

/// 利润表常用中文标签（字段名 → 展示名，对齐 THS 21 字段）
const Map<String, String> kIncomeLabels = {
  'basic_eps': '基本每股收益',
  'operating_income': '营业收入',
  'operating_costs': '营业成本',
  'operating_expenses': '营业支出',
  'operating_profit': '营业利润',
  'profit_total': '利润总额',
  'net_profit': '净利润',
  'parent_holder_net_profit': '归母净利润',
  'income_tax_expense': '所得税费用',
  'interest_expenses': '利息支出',
  'manage_fee': '管理费用',
  'sales_fee': '销售费用',
  'research_and_development_expenses': '研发费用',
};

/// 资产负债表常用中文标签（字段名 → 展示名，对齐 THS 15 字段）
const Map<String, String> kBalanceLabels = {
  'assets_total': '资产总计',
  'total_current_assets': '流动资产合计',
  'non_current_nets_total': '非流动资产净值合计',
  'total_debt': '负债合计',
  'holder_equity_total': '所有者权益合计',
  'cash': '货币资金',
  'accounts_receivable': '应收账款',
};

/// 现金流量表常用中文标签（字段名 → 展示名，对齐 THS 14 字段）
const Map<String, String> kCashFlowLabels = {
  'act_cash_flow_net': '经营活动现金流量净额',
  'invest_cash_flow_net': '投资活动现金流量净额',
  'financing_cash_flow_net': '筹资活动现金流量净额',
  'cash_equivalents_net_addition': '现金及现金等价物净增加额',
  'pay_dividends_profits_interest_cash': '分配股利利润或偿付利息支付的现金',
  'pay_fixed_assets_etc_cash': '购建固定资产等支付的现金',
};

/// 财务指标五类能力中文名
const Map<String, String> kIndicatorAbilityLabels = {
  'growth': '成长能力',
  'profitability': '盈利能力',
  'solvency': '偿债能力',
  'operation': '运营能力',
  'cash-flow': '现金流能力',
};

/// 常见指标 index_id → 中文名（命中即显示，未命中走可读化兜底）
const Map<String, String> kIndicatorLabels = {
  'calculate_operating_income_yoy_growth_ratio': '营业收入同比增长率',
  'calculate_net_profit_yoy_growth_ratio': '净利润同比增长率',
  'calculate_parent_net_profit_yoy_growth_ratio': '归母净利润同比增长率',
  'calculate_roa': '总资产收益率(ROA)',
  'calculate_roe': '净资产收益率(ROE)',
  'calculate_gross_profit_margin': '销售毛利率',
  'calculate_net_profit_margin': '销售净利率',
  'calculate_debt_to_asset_ratio': '资产负债率',
  'calculate_current_ratio': '流动比率',
  'calculate_quick_ratio': '速动比率',
  'calculate_inventory_turnover_days': '存货周转天数',
  'calculate_receivable_turnover_days': '应收账款周转天数',
  'calculate_total_asset_turnover': '总资产周转率',
  'calculate_operate_cash_flow_per_share': '每股经营现金流',
  'calculate_cash_flow_to_revenue': '营收现金含量',
};

/// 把 index_id 转为可读中文（兜底：去 calculate_/前缀，下划线转空格，首字母大写）
String _humanizeIndexId(String id) {
  var s = id
      .replaceAll(RegExp(r'^calculate_'), '')
      .replaceAll('_', ' ')
      .trim();
  if (s.isEmpty) return id;
  s = s[0].toUpperCase() + s.substring(1);
  return s;
}

/// 把同花顺 data（{timestamp, item[]}）解析为多期报表
FinancialStatement parseStatement(Map<String, dynamic> data) {
  final raw = data['item'];
  final list = raw is List ? raw : <dynamic>[];
  final periods = <FinancialPeriod>[];
  for (final e in list) {
    if (e is! Map<String, dynamic>) continue;
    final items = <String, double?>{};
    e.forEach((k, v) {
      if (k == 'thscode' ||
          k == 'ticker' ||
          k == 'period' ||
          k == 'period_end_ms' ||
          k == 'report_date_ms' ||
          k == 'fiscal_year' ||
          k == 'fiscal_period' ||
          k == 'currency') {
        return;
      }
      if (v is num) items[k] = v.toDouble();
    });
    periods.add(FinancialPeriod(
      thscode: _str(e['thscode']),
      period: _str(e['period']),
      periodEndMs: _int(e['period_end_ms']),
      reportDateMs: _int(e['report_date_ms']),
      fiscalYear: _int(e['fiscal_year']),
      fiscalPeriod: _str(e['fiscal_period']),
      currency: _str(e['currency']),
      items: items,
    ));
  }
  // 按报告期降序（最新在前）
  periods.sort((a, b) => b.periodEndMs.compareTo(a.periodEndMs));
  return FinancialStatement(periods);
}

/// 解析财务指标 abilities 数组（data = {thscode, report, abilities[]}）
/// abilities[i] = {ability, indicators:[{index_id, value}]}
List<FinancialIndicatorGroup> parseIndicators(Map<String, dynamic> data) {
  final abilities = data['abilities'];
  if (abilities is! List) return [];
  final out = <FinancialIndicatorGroup>[];
  for (final ab in abilities) {
    if (ab is! Map<String, dynamic>) continue;
    final ability = _str(ab['ability']);
    final list = ab['indicators'];
    final items = <FinancialIndicatorItem>[];
    if (list is List) {
      for (final it in list) {
        if (it is! Map<String, dynamic>) continue;
        final id = _str(it['index_id']);
        final v = it['value'];
        double? val;
        if (v != null) {
          val = v is num ? v.toDouble() : double.tryParse(v.toString());
        }
        items.add(FinancialIndicatorItem(id, val));
      }
    }
    out.add(FinancialIndicatorGroup(ability, items));
  }
  return out;
}

String _str(dynamic v) => v?.toString() ?? '';
int _int(dynamic v) => v is num ? v.toInt() : 0;
