/// 内存 TTL 缓存管理器
/// 按 key 缓存数据，超时自动过期
class CacheManager {
  CacheManager._();
  static final instance = CacheManager._();

  final _cache = <String, _CacheEntry>{};

  // ── 预设 TTL ──
  static const ttlKline = Duration(minutes: 5);       // K线数据（默认）
  static const ttlRealtime = Duration(seconds: 30);    // 实时行情
  static const ttlSentiment = Duration(minutes: 10);   // 情绪面数据
  static const ttlMacro = Duration(hours: 1);          // 宏观数据
  static const ttlNews = Duration(minutes: 2);         // 新闻
  static const ttlSearch = Duration(minutes: 5);       // 搜索结果
  static const ttlAi = Duration(minutes: 30);          // AI 诊断结果

  // ── 动态 TTL（根据交易时段调整）──
  static Duration get klineMinuteTtl {
    return _isTradingHours() ? const Duration(seconds: 30) : const Duration(minutes: 5);
  }

  static Duration get klineDayTtl {
    return _isTradingHours() ? const Duration(seconds: 60) : const Duration(minutes: 30);
  }

  static bool _isTradingHours() {
    final now = DateTime.now();
    if (now.weekday > 5) return false; // 周末
    final t = now.hour * 60 + now.minute;
    return (t >= 570 && t < 690) || (t >= 780 && t < 900); // 9:30-11:30, 13:00-15:00
  }

  /// 获取缓存，不存在或已过期返回 null
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expireAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// 写入缓存
  void set<T>(String key, T value, Duration ttl) {
    _cache[key] = _CacheEntry(value: value, expireAt: DateTime.now().add(ttl));
  }

  /// 获取缓存，不存在时调用 loader 并缓存结果
  Future<T> getOrLoad<T>(String key, Duration ttl, Future<T> Function() loader) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    final value = await loader();
    set(key, value, ttl);
    return value;
  }

  /// 删除指定 key
  void remove(String key) => _cache.remove(key);

  /// 按前缀批量删除
  void removeByPrefix(String prefix) {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// 清空全部缓存
  void clear() => _cache.clear();

  /// 清理已过期条目
  void purge() {
    final now = DateTime.now();
    _cache.removeWhere((_, v) => now.isAfter(v.expireAt));
  }

  /// 缓存条目数
  int get length => _cache.length;
}

class _CacheEntry {
  final dynamic value;
  final DateTime expireAt;
  _CacheEntry({required this.value, required this.expireAt});
}
