import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/core/errors/api_exception.dart';
import 'package:finance_chart/data/datasources/em_financial_api.dart';

/// 假 adapter：无视 URL，固定返回 `text/plain;charset=UTF-8` 的 JSON 体。
/// 用来离线复现「东财 datacenter 返回 text/plain → dio 不自动解 JSON」的真实链路，
/// 验证 [EmFinancialApi.rowsOf] 必须自己 decode，否则会静默拿到空表。
class _TextPlainAdapter implements HttpClientAdapter {
  final String body;
  _TextPlainAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        200,
        headers: {Headers.contentTypeHeader: ['text/plain;charset=UTF-8']},
      );

  @override
  void close({bool force = false}) {}
}

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

  group('EmFinancialApi.rowsOf（P0 回归：text/plain 必须解码）', () {
    /// 单测版：直接喂 JSON 字符串（模拟 dio 在 text/plain 下的行为）。
    /// 修复前 rowsOf 看到 String 直接返回空表 → 此测试必红。
    test('text/plain JSON 字符串 → 解码出正确行数', () {
      final json = jsonEncode({
        'success': true,
        'result': {
          'data': [
            {'REPORT_DATE': '2025-12-31 00:00:00', 'REPORT_TYPE': '年报', 'OPERATE_INCOME': 1.0},
            {'REPORT_DATE': '2024-12-31 00:00:00', 'REPORT_TYPE': '年报', 'OPERATE_INCOME': 2.0},
          ],
        },
      });
      final rows = EmFinancialApi.rowsOf(json);
      expect(rows.length, 2);
      expect(rows.first['OPERATE_INCOME'], 1.0);
    });

    test('空字符串 / 非法 JSON → 空表（不抛）', () {
      expect(EmFinancialApi.rowsOf(''), isEmpty);
      expect(EmFinancialApi.rowsOf('<html>not json</html>'), isEmpty);
    });
  });

  group('EmFinancialApi 真实解码路径（dio text/plain 假 adapter，离线）', () {
    // 单行同时含报表字段与指标字段，让 income / indicators 两条链路都能验证。
    final payload = jsonEncode({
      'success': true,
      'result': {
        'data': [
          {
            'SECUCODE': '600519.SH',
            'REPORT_DATE': '2025-12-31 00:00:00',
            'REPORT_TYPE': '年报',
            'CURRENCY': 'CNY',
            'OPERATE_INCOME': 90703260964.48,
            'NETPROFIT': 46033330566.78,
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
            'TOTALOPERATEREVETZ': 15.7,
            'PARENTNETPROFITTZ': 12.3,
          },
          {
            'SECUCODE': '600519.SH',
            'REPORT_DATE': '2024-12-31 00:00:00',
            'REPORT_TYPE': '年报',
            'CURRENCY': 'CNY',
            'OPERATE_INCOME': 80000000000.0,
            'NETPROFIT': 40000000000.0,
          },
        ],
      },
    });

    test('getStatement 经 text/plain 取到非空报告期', () async {
      final dio = Dio()..httpClientAdapter = _TextPlainAdapter(payload);
      final api = EmFinancialApi(dio);
      final stmt = await api.getStatement('600519', 'income');
      expect(stmt.periods.isNotEmpty, isTrue);
      expect(stmt.periods.length, 2);
      expect(stmt.periods.first.items['operating_income'], 90703260964.48);
    });

    test('getIndicators 经 text/plain 取到五类共 14 指标', () async {
      final dio = Dio()..httpClientAdapter = _TextPlainAdapter(payload);
      final api = EmFinancialApi(dio);
      final groups = await api.getIndicators('600519', '2025-4');
      expect(groups.length, 5);
      expect(groups.fold<int>(0, (sum, g) => sum + g.items.length), 14);
      final roe = groups
          .expand((g) => g.items)
          .firstWhere((i) => i.indexId == 'calculate_roe');
      expect(roe.value, 30.1);
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
