import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/core/errors/api_exception.dart';
import 'package:finance_chart/data/datasources/em_financial_api.dart';

void main() {
  group('EmFinancialApi.buildPeriod', () {
    test('income 行 → 正确解析字段与报告期标签', () {
      final row = <String, dynamic>{
        'SECUCODE': '600519.SH',
        'REPORT_DATE': '2025-12-31 00:00:00',
        'REPORT_TYPE': '年报',
        'CURRENCY': 'CNY',
        'OPERATE_INCOME': 90703260964.48,
        'NETPROFIT': 46033330566.78,
      };
      final p = EmFinancialApi.buildPeriod('income', row, '600519.SH', 'annual');
      expect(p, isNotNull);
      expect(p!.fiscalYear, 2025);
      expect(p.fiscalPeriod, 'FY');
      expect(p.currency, 'CNY');
      expect(p.items['operating_income'], 90703260964.48);
      expect(p.items['net_profit'], 46033330566.78);
      expect(p.items.length, 2); // 未映射字段被丢弃
      expect(p.label, '2025年报');
    });

    test('REPORT_TYPE 中报 → Q2', () {
      final row = <String, dynamic>{
        'REPORT_DATE': '2025-08-30 00:00:00',
        'REPORT_TYPE': '中报',
        'OPERATE_INCOME': 1.0,
      };
      final p = EmFinancialApi.buildPeriod('income', row, '600519.SH', 'annual');
      expect(p!.fiscalPeriod, 'Q2');
    });

    test('REPORT_DATE 缺失或空 → null', () {
      expect(EmFinancialApi.buildPeriod('income', <String, dynamic>{}, '600519.SH', 'annual'), isNull);
      expect(
        EmFinancialApi.buildPeriod('income', <String, dynamic>{'REPORT_DATE': ''}, '600519.SH', 'annual'),
        isNull,
      );
    });

    test('非数字字段不写入不崩', () {
      final row = <String, dynamic>{
        'REPORT_DATE': '2025-12-31 00:00:00',
        'REPORT_TYPE': '年报',
        'OPERATE_INCOME': '-',
      };
      final p = EmFinancialApi.buildPeriod('income', row, '600519.SH', 'annual');
      expect(p!.items.containsKey('operating_income'), isFalse);
      expect(p.items.length, 0);
    });
  });

  group('EmFinancialApi.buildIndicatorGroups', () {
    final row = <String, dynamic>{
      'TOTALOPERATEREVETZ': 15.7,
      'PARENTNETPROFITTZ': 12.3,
      'ROEJQ': 30.1,
      'ZZCJLL': 25.2,
      'XSMLL': 90.3,
      'XSJLL': 50.4,
      'ZCFZL': 20.5,
      'LD': 2.1,
      'SD': 1.8,
      'CHZZTS': 50.6,
      'YSZKZZTS': 10.7,
      'TOAZZL': 0.6,
      'MGJYXJJE': 40.8,
      'JYXJLYYSR': 1.2,
    };

    test('全部 14 指标 → 5 组 14 项', () {
      final groups = EmFinancialApi.buildIndicatorGroups(row);
      expect(groups.length, 5);
      expect(groups.fold<int>(0, (sum, g) => sum + g.items.length), 14);
    });

    test('growth 组仅 2 项且无净利润同比', () {
      final growth = EmFinancialApi.buildIndicatorGroups(row)
          .firstWhere((g) => g.ability == 'growth');
      expect(growth.items.length, 2);
      expect(
        growth.items.any((i) => i.indexId == 'calculate_net_profit_yoy_growth_ratio'),
        isFalse,
      );
    });

    test('calculate_roe 值与中文名', () {
      final groups = EmFinancialApi.buildIndicatorGroups(row);
      final roe = groups
          .expand((g) => g.items)
          .firstWhere((i) => i.indexId == 'calculate_roe');
      expect(roe.value, 30.1);
      expect(roe.name, '净资产收益率(ROE)');
    });

    test('某类指标全缺失则不产出该组', () {
      final partial = <String, dynamic>{
        'ROEJQ': 30.1,
        'ZZCJLL': 25.2,
      };
      final groups = EmFinancialApi.buildIndicatorGroups(partial);
      final abilities = groups.map((g) => g.ability).toList();
      expect(abilities.contains('growth'), isFalse);
      expect(abilities.contains('solvency'), isFalse);
      expect(abilities.contains('operation'), isFalse);
      expect(abilities.contains('cash-flow'), isFalse);
      expect(groups.length, 1);
      expect(groups.first.ability, 'profitability');
    });
  });

  group('EmFinancialApi 类型校验（不发网络）', () {
    final api = EmFinancialApi(Dio());

    test('未知报表类型抛 ApiException', () {
      expect(api.getStatement('600519', 'foo'), throwsA(isA<ApiException>()));
    });

    test('指标报告期缺段抛 ApiException', () {
      expect(api.getIndicators('600519', '2025'), throwsA(isA<ApiException>()));
    });

    test('指标报告期非法段抛 ApiException', () {
      expect(api.getIndicators('600519', '2025-9'), throwsA(isA<ApiException>()));
    });
  });
}
