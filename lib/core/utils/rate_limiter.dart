import 'dart:async';

/// 全局请求频率控制器
/// 按域名分组，确保每个域名的请求间隔不低于安全阈值
class RateLimiter {
  RateLimiter._();
  static final instance = RateLimiter._();

  // 各域名最小间隔（毫秒）
  static const _domainLimits = <String, int>{
    'push2his.eastmoney.com': 600,   // 东财K线/资金流 — 最严格
    'push2.eastmoney.com': 500,      // 东财实时行情
    'push3.eastmoney.com': 500,      // 东财备用
    'datacenter-web.eastmoney.com': 600, // 东财数据中心
    'ai-saas.eastmoney.com': 1000,   // 东财AI
    'np-listapi.eastmoney.com': 500, // 东财新闻
    'searchapi.eastmoney.com': 300,  // 东财搜索
    'qt.gtimg.cn': 250,              // 腾讯行情
    'web.ifzq.gtimg.cn': 250,       // 腾讯K线
    'quotes.sina.cn': 300,           // 新浪分钟K线
    'money.finance.sina.com.cn': 300,// 新浪历史K线
    'finance.pae.baidu.com': 500,    // 百度财经
    'cls.cn': 300,                   // 财联社
  };

  // 默认间隔（未列出的域名）
  static const _defaultLimit = 500;

  // 各域名上次请求时间
  final _lastRequest = <String, DateTime>{};

  // 各域名失败计数（用于指数退避）
  final _failCounts = <String, int>{};

  /// 等待直到可以向指定域名发请求
  Future<void> wait(String domain) async {
    final minInterval = _domainLimits[domain] ?? _defaultLimit;
    final last = _lastRequest[domain];
    if (last != null) {
      final elapsed = DateTime.now().difference(last).inMilliseconds;
      if (elapsed < minInterval) {
        await Future.delayed(Duration(milliseconds: minInterval - elapsed));
      }
    }
    _lastRequest[domain] = DateTime.now();
  }

  /// 从 URL 提取域名并等待
  Future<void> waitByUrl(String url) async {
    final domain = _extractDomain(url);
    if (domain != null) await wait(domain);
  }

  /// 记录失败，返回建议退避时间
  Duration recordFailure(String domain) {
    final count = (_failCounts[domain] ?? 0) + 1;
    _failCounts[domain] = count;
    // 指数退避：1s, 2s, 4s, 8s, 16s（上限）
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

  /// 重置指定域名的封禁状态
  void resetBlock(String domain) {
    _failCounts.remove(domain);
  }

  /// 获取所有域名状态（用于调试/设置页显示）
  Map<String, dynamic> getStatus() {
    final status = <String, dynamic>{};
    for (final domain in _domainLimits.keys) {
      status[domain] = {
        'failCount': _failCounts[domain] ?? 0,
        'blocked': isBlocked(domain),
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
