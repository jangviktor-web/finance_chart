import 'package:intl/intl.dart';

/// 格式化工具
class FormatUtils {
  FormatUtils._();

  static final _numberFormat = NumberFormat('#,##0.00');
  static final _volumeFormat = NumberFormat('#,##0');
  static final _percentFormat = NumberFormat('+#0.00;-#0.00');
  static final _compactFormat = NumberFormat.compact();

  /// 价格格式: 1234.56
  static String price(double value) => value.toStringAsFixed(2);

  /// 涨跌幅格式: +2.35% 或 -1.20%
  static String percent(double value) => '${_percentFormat.format(value)}%';

  /// 涨跌额格式: +1.23 或 -0.45
  static String change(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

  /// 成交量格式: 12.3万 或 1.2亿
  static String volume(double value) {
    if (value >= 1e8) return '${(value / 1e8).toStringAsFixed(2)}亿';
    if (value >= 1e4) return '${(value / 1e4).toStringAsFixed(2)}万';
    return _volumeFormat.format(value);
  }

  /// 金额格式: 12.3亿
  static String amount(double value) {
    if (value >= 1e8) return '${(value / 1e8).toStringAsFixed(2)}亿';
    if (value >= 1e4) return '${(value / 1e4).toStringAsFixed(2)}万';
    return value.toStringAsFixed(2);
  }

  /// 日期格式: 2026-05-19
  static String date(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  /// 日期时间格式: 2026-05-19 14:30
  static String dateTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

  /// 紧凑数字: 12.3万
  static String compact(double value) => _compactFormat.format(value);
}
