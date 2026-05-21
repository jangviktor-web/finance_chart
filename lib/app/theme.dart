import 'package:flutter/material.dart';

/// 应用颜色系统 — 全局动态主题
/// 所有 getter 基于 [_isDarkMode] 和 [_colorStyle] 动态返回颜色
/// 切换主题时设置标志位，下次 build 自动刷新
class AppColors {
  // ── 主题标志位 ──
  static bool _isDarkMode = true;
  static String _colorStyle = 'cn'; // 'cn'=红涨绿跌, 'us'=绿涨红跌

  static bool get isDarkMode => _isDarkMode;
  static String get colorStyle => _colorStyle;

  static void setDarkMode(bool value) => _isDarkMode = value;
  static void setColorStyle(String style) => _colorStyle = style;

  // ── 基础色（暗色/亮色 自适应） ──
  static Color get background => _isDarkMode ? const Color(0xFF0a0a0a) : const Color(0xFFF5F5F5);
  static Color get cardBackground => _isDarkMode ? const Color(0xFF1a1a2e) : const Color(0xFFFFFFFF);
  static Color get surface => _isDarkMode ? const Color(0xFF16213e) : const Color(0xFFE8E8E8);
  static Color get divider => _isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
  static Color get textPrimary => _isDarkMode ? const Color(0xFFe0e0e0) : const Color(0xFF1a1a1a);
  static Color get textSecondary => _isDarkMode ? const Color(0xFF888888) : const Color(0xFF666666);
  static Color get gridLine => _isDarkMode ? const Color(0xFF222222) : const Color(0xFFE8E8E8);
  static Color get axisLabel => _isDarkMode ? const Color(0xFF666666) : const Color(0xFF999999);

  // ── 不随主题变的固定色 ──
  static const primary = Color(0xFF3b82f6);

  // MA 均线颜色
  static const ma5 = Color(0xFFf59e0b);
  static const ma10 = Color(0xFF8b5cf6);
  static const ma20 = Color(0xFF3b82f6);
  static const ma60 = Color(0xFF06b6d4);

  // MACD 颜色
  static const macdDif = Color(0xFF3b82f6);
  static const macdDea = Color(0xFFf59e0b);

  // KDJ 颜色
  static const kdjK = Color(0xFFf59e0b);
  static const kdjD = Color(0xFF3b82f6);
  static const kdjJ = Color(0xFF8b5cf6);

  // BOLL/KTN 通道颜色
  static const bollUpper = Color(0xFFef4444);
  static const bollLower = Color(0xFF22c55e);

  // ── 涨跌色（动态，根据用户设置） ──
  static Color get up => _colorStyle == 'cn'
      ? const Color(0xFFef4444)   // 中国：红涨
      : const Color(0xFF22c55e);  // 美国：绿涨

  static Color get down => _colorStyle == 'cn'
      ? const Color(0xFF22c55e)   // 中国：绿跌
      : const Color(0xFFef4444);  // 美国：红跌

  // ── 语义色（不随涨跌色变） ──
  static const error = Color(0xFFef4444);    // 错误/危险/删除
  static const success = Color(0xFF22c55e);  // 成功
  static const warning = Color(0xFFf59e0b);  // 警告

  // ── 按钮前景色（在 primary 背景上的文字） ──
  static const onPrimary = Colors.white;

  // ── 阴影色 ──
  static Color get shadow => _isDarkMode
      ? Colors.black.withOpacity(0.3)
      : Colors.black.withOpacity(0.1);
}

/// 暗色主题
final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0a0a0a),
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.ma20,
    surface: Color(0xFF16213e),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0a0a0a),
    elevation: 0,
  ),
  cardTheme: const CardThemeData(color: Color(0xFF1a1a2e)),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: Color(0xFFe0e0e0), fontSize: 18, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Color(0xFFe0e0e0), fontSize: 16),
    bodyLarge: TextStyle(color: Color(0xFFe0e0e0), fontSize: 14),
    bodyMedium: TextStyle(color: Color(0xFF888888), fontSize: 12),
  ),
);

/// 亮色主题
final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.ma20,
    surface: Color(0xFFE8E8E8),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF5F5F5),
    elevation: 0,
    foregroundColor: Color(0xFF1a1a1a),
  ),
  cardTheme: const CardThemeData(color: Color(0xFFFFFFFF)),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: Color(0xFF1a1a1a), fontSize: 18, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Color(0xFF1a1a1a), fontSize: 16),
    bodyLarge: TextStyle(color: Color(0xFF1a1a1a), fontSize: 14),
    bodyMedium: TextStyle(color: Color(0xFF666666), fontSize: 12),
  ),
);
