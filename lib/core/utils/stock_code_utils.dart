/// 股票代码工具类
class StockCodeUtils {
  StockCodeUtils._();

  /// 格式化股票代码，确保带 sh/sz 前缀
  static String format(String code) {
    code = code.toLowerCase().trim();
    if (code.startsWith('sh') || code.startsWith('sz')) {
      return code;
    }
    // 6开头上海，5开头上海ETF，其他深圳
    if (code.startsWith('6') || code.startsWith('5')) return 'sh$code';
    return 'sz$code';
  }

  /// 纯数字代码 -> 带市场前缀
  static String fromNumeric(String code) {
    code = code.trim();
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      return code.startsWith('6') ? 'sh$code' : 'sz$code';
    }
    return format(code);
  }

  /// 获取纯数字部分
  static String pureCode(String code) {
    if (code.startsWith('sh') || code.startsWith('sz')) {
      return code.substring(2);
    }
    return code;
  }

  /// 获取市场编号 (东方财富 API 用)
  /// 1=上海, 0=深圳
  static String marketNum(String code) {
    return format(code).startsWith('sh') ? '1' : '0';
  }

  /// 东方财富 secid 格式: 1.600519 或 0.000001
  static String toSecId(String code) {
    final formatted = format(code);
    final pure = pureCode(formatted);
    final market = formatted.startsWith('sh') ? '1' : '0';
    return '$market.$pure';
  }

  /// 判断是否为有效的股票代码
  static bool isValid(String code) {
    final trimmed = code.trim();
    if (RegExp(r'^(sh|sz)\d{6}$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }
}
