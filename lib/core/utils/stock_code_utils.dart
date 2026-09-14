/// 股票代码工具类
class StockCodeUtils {
  StockCodeUtils._();

  /// 格式化股票代码：仅给 6 位纯数字 A 股代码补 sh/sz 前缀，其余原样返回。
  ///
  /// ponytail: 原实现把任何未识别输入都落到 `sz`，于是港股 `00700` 被拼成
  /// `sz00700`、美股 `AAPL` 拼成 `szaapl`，静默串到错误市场并让行情/K线返回空。
  /// 港美股在东财侧用 secid 表示（`116.00700` / `105.AAPL`），必须原样放行。
  static String format(String code) {
    code = code.trim();
    if (code.isEmpty) return code;
    // ponytail: secid（含 `.`，如 116.00700 / 105.AAPL / 90.BK0475）来自东财 `QuoteID`，
    // 原样放行不做小写化 —— 实测东财 ulist 大小写不敏感，但不必替上游改写法，
    // 保持原样对其它端点最稳。
    if (code.contains('.')) return code;
    code = code.toLowerCase();
    if (code.startsWith('sh') || code.startsWith('sz')) return code;
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      // 6开头上海，5开头上海ETF，其他深圳
      return (code.startsWith('6') || code.startsWith('5')) ? 'sh$code' : 'sz$code';
    }
    return code;
  }

  /// 获取纯数字部分
  static String pureCode(String code) {
    if (code.startsWith('sh') || code.startsWith('sz')) {
      return code.substring(2);
    }
    return code;
  }

  /// 东方财富 secid 格式
  /// 沪 `1.600519` / 深 `0.000001` / 港 `116.00700` / 美 `105.AAPL` / 板块 `90.BK0475`
  ///
  /// ponytail: 港美股的 secid 由搜索接口的 `QuoteID` 直接带入，此处只需直通；
  /// 不再从裸代码推断市场号 —— 美股 105/106/107 分属 NASDAQ/NYSE/AMEX，
  /// 仅凭 Ticker 无法判定，猜错会静默返回别的标的。
  static String toSecId(String code) {
    final formatted = format(code);
    if (formatted.contains('.')) return formatted;
    final market = formatted.startsWith('sh') ? '1' : '0';
    return '$market.${pureCode(formatted)}';
  }

  /// 是否 A 股市场（沪深主板/科创/创业板 + 北交所）。港美股 secid、板块、非 6 位数字代码一律为 false。
  ///
  /// 用途：判断某标的能否走东财 F10 财务接口（F10 只覆盖 A 股）。
  static bool isAShare(String code) {
    final f = format(code);
    if (f.contains('.')) {
      // 东财 secid：`1.` = 沪A、`0.` = 深A、`116.` = 港股、`105/106/107.` = 美股、`90.` = 板块
      final prefix = f.split('.').first;
      return prefix == '1' || prefix == '0';
    }
    return RegExp(r'^\d{6}$').hasMatch(pureCode(f));
  }

  /// 是否境内 ETF / 基金：沪 `5xxxxx`；深 `15/16/17/18xxxx`。
  ///
  /// ⚠️ 这类代码**是** A 股代码格式，但东财 F10 不提供其财务报表（实测 510300.SH /
  /// 159915.SZ 均返回「返回数据为空」），故单列出来。
  static bool isFundOrEtf(String code) {
    final f = format(code);
    if (f.contains('.')) return false;
    final pure = pureCode(f);
    if (f.startsWith('sh')) return pure.startsWith('5');
    if (f.startsWith('sz')) return RegExp(r'^1[5-8]').hasMatch(pure);
    return false;
  }

  /// 同花顺 thscode 格式: 600519.SH / 000001.SZ / 8xxxxx.BJ
  /// 用于同花顺金融数据 API（BYOK）的兜底行情请求
  static String toThsCode(String code) {
    final pure = pureCode(format(code));
    if (pure.startsWith('6') || pure.startsWith('9')) return '$pure.SH';
    if (pure.startsWith('4') || pure.startsWith('8')) return '$pure.BJ';
    return '$pure.SZ';
  }
}
