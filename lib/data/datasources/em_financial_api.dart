import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/stock_code_utils.dart';
import '../models/financial_data.dart';
import 'em_http.dart';

/// 东财 F10 财务数据（**keyless 第二源**）—— 三大报表 + 主要指标。
///
/// 与同花顺 Financial-API 的差异与适配：
/// - **字段名**：东财是大写下划线（`OPERATE_INCOME`），UI 取数用的是同花顺小写名
///   （`operating_income`），故此处翻译一层；未进映射表的字段**直接丢弃** ——
///   UI 只渲染 `k*Labels` 里存在的字段，多余字段没有消费者。
/// - **报告期**：东财只给 `REPORT_DATE`/`REPORT_TYPE`，`fiscal_year`/`fiscal_period` 由此合成。
/// - **指标**：东财 MAINFINADATA 是**扁平一行**，需按五类能力分桶成 abilities[] 形态。
/// - **代码**：`SECUCODE` 形如 `600519.SH`，与 [StockCodeUtils.toThsCode] 输出同形，直接复用。
// ponytail: 不做「东财→同花顺全字段表」。只映射 UI 真会渲染的那些，其余字段是死重量。
class EmFinancialApi {
  final Dio _dio;
  EmFinancialApi(this._dio);

  /// 报表类型 → 东财 reportName
  static const Map<String, String> reportNames = {
    'income': 'RPT_F10_FINANCE_GINCOME',
    'balance': 'RPT_F10_FINANCE_GBALANCE',
    'cashflow': 'RPT_F10_FINANCE_GCASHFLOW',
  };

  /// 同花顺字段名（UI 的 k*Labels key）→ 东财字段名
  static const Map<String, Map<String, String>> fieldMaps = {
    'income': {
      'basic_eps': 'BASIC_EPS',
      'operating_income': 'OPERATE_INCOME',
      'operating_costs': 'OPERATE_COST',
      'operating_expenses': 'TOTAL_OPERATE_COST',
      'operating_profit': 'OPERATE_PROFIT',
      'profit_total': 'TOTAL_PROFIT',
      'net_profit': 'NETPROFIT',
      'parent_holder_net_profit': 'PARENT_NETPROFIT',
      'income_tax_expense': 'INCOME_TAX',
      'interest_expenses': 'INTEREST_EXPENSE',
      'manage_fee': 'MANAGE_EXPENSE',
      'sales_fee': 'SALE_EXPENSE',
      'research_and_development_expenses': 'RESEARCH_EXPENSE',
    },
    'balance': {
      'assets_total': 'TOTAL_ASSETS',
      'total_current_assets': 'TOTAL_CURRENT_ASSETS',
      'non_current_nets_total': 'TOTAL_NONCURRENT_ASSETS',
      'total_debt': 'TOTAL_LIABILITIES',
      'holder_equity_total': 'TOTAL_EQUITY',
      'cash': 'MONETARYFUNDS',
      'accounts_receivable': 'ACCOUNTS_RECE',
    },
    'cashflow': {
      'act_cash_flow_net': 'NETCASH_OPERATE',
      'invest_cash_flow_net': 'NETCASH_INVEST',
      'financing_cash_flow_net': 'NETCASH_FINANCE',
      'cash_equivalents_net_addition': 'CCE_ADD',
      'pay_dividends_profits_interest_cash': 'ASSIGN_DIVIDEND_PORFIT',
      'pay_fixed_assets_etc_cash': 'CONSTRUCT_LONG_ASSET',
    },
  };

  /// 五类能力 → {同花顺 index_id: 东财字段名}
  static const Map<String, Map<String, String>> indicatorMaps = {
    'growth': {
      'calculate_operating_income_yoy_growth_ratio': 'TOTALOPERATEREVETZ',
      'calculate_parent_net_profit_yoy_growth_ratio': 'PARENTNETPROFITTZ',
    },
    'profitability': {
      'calculate_roe': 'ROEJQ',
      'calculate_roa': 'ZZCJLL',
      'calculate_gross_profit_margin': 'XSMLL',
      'calculate_net_profit_margin': 'XSJLL',
    },
    'solvency': {
      'calculate_debt_to_asset_ratio': 'ZCFZL',
      'calculate_current_ratio': 'LD',
      'calculate_quick_ratio': 'SD',
    },
    'operation': {
      'calculate_inventory_turnover_days': 'CHZZTS',
      'calculate_receivable_turnover_days': 'YSZKZZTS',
      'calculate_total_asset_turnover': 'TOAZZL',
    },
    'cash-flow': {
      'calculate_operate_cash_flow_per_share': 'MGJYXJJE',
      'calculate_cash_flow_to_revenue': 'JYXJLYYSR',
    },
  };

  /// 报告期码 → 东财 REPORT_TYPE（UI 传的是同花顺约定的 'YYYY-[1-4]'）
  static const Map<String, String> _reportTypeByCode = {
    '1': '一季报', '2': '中报', '3': '三季报', '4': '年报',
  };
  static const Map<String, String> _fiscalPeriodByType = {
    '一季报': 'Q1', '中报': 'Q2', '三季报': 'Q3', '年报': 'FY',
  };

  /// 三大报表（多期，已按报告期降序）。拿不到数据就抛异常，由 firstSuccess 继续兜底。
  Future<FinancialStatement> getStatement(
    String code,
    String type, {
    String period = 'annual',
    int limit = 4,
  }) async {
    final reportName = reportNames[type];
    if (reportName == null) throw ApiException('未知报表类型: $type');
    final secu = StockCodeUtils.toThsCode(code);
    // ponytail: 过滤串刻意不留空格（`in(` 而非 `in (`—— dio 会把空格编成 `+`，东财不认。
    final typeFilter = period == 'quarterly'
        ? '(REPORT_TYPE in("一季报","中报","三季报"))'
        : '(REPORT_TYPE="年报")';
    final res = await getEmWithMirror(
      _dio,
      ApiEndpoints.f10Report,
      params: {
        'reportName': reportName,
        'columns': 'ALL',
        'filter': '(SECUCODE="$secu")$typeFilter',
        'pageNumber': 1,
        'pageSize': limit,
        'sortColumns': 'REPORT_DATE',
        'sortTypes': -1,
        'source': 'HSF10',
        'client': 'PC',
      },
    );
    final rows = rowsOf(res.data);
    if (rows.isEmpty) throw ParseException('东财 F10 无数据: $reportName $secu');
    final periods = <FinancialPeriod>[];
    for (final r in rows) {
      final p = buildPeriod(type, r, secu, period);
      if (p != null) periods.add(p);
    }
    if (periods.isEmpty) throw ParseException('东财 F10 字段不匹配: $reportName $secu');
    periods.sort((a, b) => b.periodEndMs.compareTo(a.periodEndMs));
    return FinancialStatement(periods);
  }

  /// 财务指标（单报告期）。`report` 格式 `'YYYY-[1-4]'`（1=一季报 2=中报 3=三季报 4=年报）。
  Future<List<FinancialIndicatorGroup>> getIndicators(String code, String report) async {
    final parts = report.split('-');
    final reportType = parts.length == 2 ? _reportTypeByCode[parts[1]] : null;
    if (reportType == null) throw ApiException('报告期格式应为 YYYY-[1-4]: $report');
    final secu = StockCodeUtils.toThsCode(code);
    final res = await getEmWithMirror(
      _dio,
      ApiEndpoints.f10Report,
      params: {
        'reportName': 'RPT_F10_FINANCE_MAINFINADATA',
        'columns': 'ALL',
        'filter': '(SECUCODE="$secu")(REPORT_YEAR="${parts[0]}")(REPORT_TYPE="$reportType")',
        'pageNumber': 1,
        'pageSize': 1,
        'sortColumns': 'REPORT_DATE',
        'sortTypes': -1,
        'source': 'HSF10',
        'client': 'PC',
      },
    );
    final rows = rowsOf(res.data);
    if (rows.isEmpty) throw ParseException('东财 F10 指标无数据: $secu $report');
    return buildIndicatorGroups(rows.first);
  }

  /// 东财 `result.data[]`；形态异常返回空表（而非抛错），由调用方统一判「无数据」。
  static List<Map<String, dynamic>> rowsOf(dynamic data) {
    if (data is! Map) return const [];
    final result = data['result'];
    if (result is! Map) return const [];
    final rows = result['data'];
    if (rows is! List) return const [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  /// 单行 → [FinancialPeriod]。缺 `REPORT_DATE` 的行返回 null（该行不可用）。
  static FinancialPeriod? buildPeriod(
    String type,
    Map<String, dynamic> row,
    String thscode,
    String period,
  ) {
    final endMs = _parseReportDate(row['REPORT_DATE']);
    if (endMs == 0) return null;
    final reportType = row['REPORT_TYPE']?.toString() ?? '';
    final items = <String, double?>{};
    (fieldMaps[type] ?? const {}).forEach((thsKey, emKey) {
      final v = row[emKey];
      if (v is num) items[thsKey] = v.toDouble();
    });
    return FinancialPeriod(
      thscode: thscode,
      period: period,
      periodEndMs: endMs,
      reportDateMs: endMs, // 东财 F10 只给 REPORT_DATE，公告日不单独提供
      fiscalYear: DateTime.fromMillisecondsSinceEpoch(endMs).year,
      fiscalPeriod: _fiscalPeriodByType[reportType] ?? 'FY',
      currency: row['CURRENCY']?.toString() ?? 'CNY',
      items: items,
    );
  }

  /// 东财 MAINFINADATA 单行 → 五类能力分组，仅保留有值的指标。
  static List<FinancialIndicatorGroup> buildIndicatorGroups(Map<String, dynamic> row) {
    final out = <FinancialIndicatorGroup>[];
    indicatorMaps.forEach((ability, map) {
      final items = <FinancialIndicatorItem>[];
      map.forEach((indexId, emKey) {
        final v = row[emKey];
        if (v is num) items.add(FinancialIndicatorItem(indexId, v.toDouble()));
      });
      if (items.isNotEmpty) out.add(FinancialIndicatorGroup(ability, items));
    });
    return out;
  }

  /// 东财 `'2025-12-31 00:00:00'` → 毫秒时间戳（Dart 的 parse 接受空格分隔符）。
  static int _parseReportDate(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty) return 0;
    return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
  }
}
