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

  /// 同花顺 thscode 格式: 600519.SH / 000001.SZ / 8xxxxx.BJ
  /// 用于同花顺金融数据 API（BYOK）的兜底行情请求
  static String toThsCode(String code) {
    final pure = pureCode(format(code));
    if (pure.startsWith('6') || pure.startsWith('9')) return '$pure.SH';
    if (pure.startsWith('4') || pure.startsWith('8')) return '$pure.BJ';
    return '$pure.SZ';
  }
}
