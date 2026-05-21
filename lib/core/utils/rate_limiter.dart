import 'dart:async';

/// 全局请求频率控制器
/// 按域名分组：最小请求间隔 + 每日调用次数上限 + 指数退避
class RateLimiter {
  RateLimiter._();
  static final instance = RateLimiter._();

  // ── 各域名最小间隔（毫秒） ──
  static const _domainLimits = <String, int>{
    // 东方财富
    'push2.eastmoney.com': 500,         // 实时行情
    'push2his.eastmoney.com': 600,      // K线/资金流 — 最严格
    'push3.eastmoney.com': 500,         // 备用
    'datacenter-web.eastmoney.com': 600,// 数据中心
    'ai-saas.eastmoney.com': 1000,      // AI
    'mkapi2.dfcfs.com': 1000,           // AI选股
    'np-listapi.eastmoney.com': 500,    // 新闻
    'searchapi.eastmoney.com': 300,     // 搜索
    'search-api-web.eastmoney.com': 300,// 新闻搜索
    // 腾讯
    'qt.gtimg.cn': 250,                 // 行情
    'web.ifzq.gtimg.cn': 250,          // K线
    'ifzq.gtimg.cn': 250,              // 分钟K线
    // 新浪
    'quotes.sina.cn': 300,              // 分钟K线
    'money.finance.sina.com.cn': 300,   // 历史K线
    'zhibo.sina.com.cn': 500,           // 直播
    // 百度
    'finance.pae.baidu.com': 500,       // 百度财经
    // 财联社
    'cls.cn': 300,
  };

  // ── 各域名每日调用次数上限 ──
  static const _dailyLimits = <String, int>{
    // 东方财富
    'push2.eastmoney.com': 1000,
    'push2his.eastmoney.com': 500,
    'push3.eastmoney.com': 500,
    'datacenter-web.eastmoney.com': 200,
    'ai-saas.eastmoney.com': 50,
    'mkapi2.dfcfs.com': 50,
    'np-listapi.eastmoney.com': 300,
    'searchapi.eastmoney.com': 300,
    'search-api-web.eastmoney.com': 200,
    // 腾讯
    'qt.gtimg.cn': 2000,
    'web.ifzq.gtimg.cn': 500,
    'ifzq.gtimg.cn': 500,
    // 新浪
    'quotes.sina.cn': 200,
    'money.finance.sina.com.cn': 200,
    'zhibo.sina.com.cn': 100,
    // 百度
    'finance.pae.baidu.com': 200,
    // 财联社
    'cls.cn': 200,
  };

  static const _defaultLimit = 500;
  static const _defaultDailyLimit = 500;

  // 各域名上次请求时间
  final _lastRequest = <String, DateTime>{};
  // 各域名失败计数（指数退避）
  final _failCounts = <String, int>{};
  // 各域名当日调用次数
  final _dailyCounts = <String, int>{};
  // 当前日期（用于每日重置）
  DateTime _currentDate = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 重置每日计数（跨天自动触发）
  void _resetDailyIfNeeded() {
    final today = _today();
    if (today != _currentDate) {
      _dailyCounts.clear();
      _currentDate = today;
    }
  }

  /// 等待直到可以向指定域名发请求
  /// 返回 true 表示正常放行，false 表示已达每日上限
  Future<bool> wait(String domain) async {
    _resetDailyIfNeeded();

    // 检查每日上限
    final dailyLimit = _dailyLimits[domain] ?? _defaultDailyLimit;
    final used = _dailyCounts[domain] ?? 0;
    if (used >= dailyLimit) {
      return false; // 达到每日上限
    }

    // 检查最小间隔
    final minInterval = _domainLimits[domain] ?? _defaultLimit;
    final last = _lastRequest[domain];
    if (last != null) {
      final elapsed = DateTime.now().difference(last).inMilliseconds;
      if (elapsed < minInterval) {
        await Future.delayed(Duration(milliseconds: minInterval - elapsed));
      }
    }

    _lastRequest[domain] = DateTime.now();
    _dailyCounts[domain] = used + 1;
    return true;
  }

  /// 从 URL 提取域名并等待
  Future<bool> waitByUrl(String url) async {
    final domain = _extractDomain(url);
    if (domain != null) return wait(domain);
    return true;
  }

  /// 记录失败，返回建议退避时间
  Duration recordFailure(String domain) {
    final count = (_failCounts[domain] ?? 0) + 1;
    _failCounts[domain] = count;
    final backoffMs = (1000 * (1 << (count - 1).clamp(0, 4))).clamp(1000, 16000);
    return Duration(milliseconds: backoffMs);
  }

  /// 记录成功，重置失败计数
  void recordSuccess(String domain) {
    _failCounts.remove(domain);
  }

  /// 获取域名当前失败次数
  int getFailCount(String domain) => _failCounts[domain] ?? 0;

  /// 检查域名是否被暂时封禁（连续失败5次以上）
  bool isBlocked(String domain) => (_failCounts[domain] ?? 0) >= 5;

  /// 检查域名是否达到每日上限
  bool isDailyLimitReached(String domain) {
    _resetDailyIfNeeded();
    final dailyLimit = _dailyLimits[domain] ?? _defaultDailyLimit;
    return (_dailyCounts[domain] ?? 0) >= dailyLimit;
  }

  /// 获取域名当日已调用次数
  int getDailyCount(String domain) {
    _resetDailyIfNeeded();
    return _dailyCounts[domain] ?? 0;
  }

  /// 获取域名每日上限
  int getDailyLimit(String domain) => _dailyLimits[domain] ?? _defaultDailyLimit;

  /// 重置指定域名的封禁状态
  void resetBlock(String domain) {
    _failCounts.remove(domain);
  }

  /// 获取所有域名状态（用于调试/设置页显示）
  Map<String, dynamic> getStatus() {
    _resetDailyIfNeeded();
    final status = <String, dynamic>{};
    for (final domain in _domainLimits.keys) {
      status[domain] = {
        'failCount': _failCounts[domain] ?? 0,
        'blocked': isBlocked(domain),
        'dailyCount': _dailyCounts[domain] ?? 0,
        'dailyLimit': _dailyLimits[domain] ?? _defaultDailyLimit,
        'dailyLimitReached': isDailyLimitReached(domain),
        'lastRequest': _lastRequest[domain]?.toIso8601String(),
      };
    }
    return status;
  }

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return null;
    }
  }
}
