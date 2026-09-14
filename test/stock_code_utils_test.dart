import 'package:flutter_test/flutter_test.dart';
import 'package:finance_chart/core/utils/stock_code_utils.dart';

/// 覆盖 `format` / `toSecId` 的市场判定分支。
///
/// 回归背景：`format` 曾把任何未识别输入都落到 `sz`，于是港股 `00700` 变成
/// `sz00700`、美股 `AAPL` 变成 `szaapl`，静默串到错误市场导致行情/K线返回空
/// （触发路径：选股器选「港股/美股」→ 点结果 → 图表空白）。
/// 港美股的正确表示是东财 secid（`116.00700` / `105.AAPL`），由搜索接口的
/// `QuoteID` 直接带入，工具类只需原样放行。
void main() {
  group('StockCodeUtils.format', () {
    test('6 位 A 股数字补 sh/sz 前缀', () {
      expect(StockCodeUtils.format('600519'), 'sh600519');
      expect(StockCodeUtils.format('510300'), 'sh510300'); // 沪 ETF
      expect(StockCodeUtils.format('000001'), 'sz000001');
      expect(StockCodeUtils.format('300750'), 'sz300750');
      expect(StockCodeUtils.format('830799'), 'sz830799'); // 北交所（secid 同为 0.）
    });

    test('已带 sh/sz 前缀原样返回（大写先转小写）', () {
      expect(StockCodeUtils.format('sh600519'), 'sh600519');
      expect(StockCodeUtils.format('SZ000001'), 'sz000001');
    });

    test('港美股 secid 原样放行', () {
      expect(StockCodeUtils.format('116.00700'), '116.00700');
      expect(StockCodeUtils.format('105.AAPL'), '105.AAPL');
      expect(StockCodeUtils.format('90.BK0475'), '90.BK0475');
    });

    test('裸港美股代码不再被硬拼深圳前缀（核心回归）', () {
      expect(StockCodeUtils.format('00700'), isNot('sz00700'));
      expect(StockCodeUtils.format('00700'), '00700');
      expect(StockCodeUtils.format('AAPL'), 'aapl'); // 仅小写化，不加市场前缀
    });

    test('空串与纯空白安全', () {
      expect(StockCodeUtils.format(''), '');
      expect(StockCodeUtils.format('   '), '');
    });
  });

  group('StockCodeUtils.toSecId', () {
    test('A 股：1=沪 / 0=深', () {
      expect(StockCodeUtils.toSecId('600519'), '1.600519');
      expect(StockCodeUtils.toSecId('000001'), '0.000001');
      expect(StockCodeUtils.toSecId('sh600519'), '1.600519');
      expect(StockCodeUtils.toSecId('sz000001'), '0.000001');
    });

    test('已是 secid 则直通（港 116 / 美 105 / 板块 90）', () {
      expect(StockCodeUtils.toSecId('116.00700'), '116.00700');
      expect(StockCodeUtils.toSecId('105.AAPL'), '105.AAPL');
      expect(StockCodeUtils.toSecId('90.BK0475'), '90.BK0475');
    });
  });

  group('StockCodeUtils.pureCode / toThsCode', () {
    test('pureCode 剥离 sh/sz', () {
      expect(StockCodeUtils.pureCode('sh600519'), '600519');
      expect(StockCodeUtils.pureCode('sz000001'), '000001');
      expect(StockCodeUtils.pureCode('600519'), '600519');
    });

    test('toThsCode 沪/深/京', () {
      expect(StockCodeUtils.toThsCode('600519'), '600519.SH');
      expect(StockCodeUtils.toThsCode('000001'), '000001.SZ');
      expect(StockCodeUtils.toThsCode('830799'), '830799.BJ');
    });
  });
}
