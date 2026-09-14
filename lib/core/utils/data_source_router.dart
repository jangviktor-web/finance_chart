import 'dart:async';
import '../../core/errors/api_exception.dart';

/// 多数据源竞速/兜底工具（全 app 数据模块共用）。
///
/// ## 竞速语义
/// 并发尝试 [attempts] 中所有**未冷却**的源，返回**第一个成功（非 null）**的结果；
/// 全部失败则抛出 [NetworkException] 并附带各源错误明细。
/// 单个 [DataSourceAttempt] 是**懒执行**的闭包（[DataSourceAttempt.run]），因此处于冷却中
/// 的端点永远不会被触发——这正是冷却的核心收益：死掉的端点直接跳过，不浪费它的整段超时。
///
/// ## 端点级冷却（circuit breaking）
/// 通过 [SourceHealth] 做轻量健康追踪：某个端点**连续失败 3 次**后进入冷却
/// （`now + 5 分钟`），期间 `firstSuccess` 直接跳过它；冷却到期后自愈，
/// 给它一次全新尝试机会。任一源返回非 null 即视为成功，清空其失败计数与冷却
/// （即使它是在竞速已经分出胜负之后才返回的，它也确实可用，应当清罚）。
///
/// ## 命名约定：`vendor:endpoint`（端点限定，而非 vendor 限定）
/// 名称必须到「端点」粒度，例如 `tencent:ifzq.kline`、`sina:cn_marketdata.kline`、
/// `em:push2his.kline`、`em:push2.clist`、`em:dc.macro`。
/// 关键点：一个死掉的东财端点（如 `em:push2his.kline`）**不能**连累同 vendor 的其它端点
/// （`em:push2.clist`、`em:dc.macro`）。
///
/// 用法：
/// ```dart
/// return firstSuccess(<DataSourceAttempt<MyData>>[
///   DataSourceAttempt('tencent:ifzq.kline', () => _fromTencent(code)),   // keyless，首选
///   DataSourceAttempt('em:push2his.kline', () => _fromEastmoney(code)),
///   if (thinksApi != null)
///     DataSourceAttempt('thinks:kline', () => _fromThinks(code)),        // keyed，按需
/// ]);
/// ```
// ponytail: 故意不做「中央 DataType→source-chain 配置表」。每个模块在调用点保留自己的有序
// attempt 列表即可，因为可用性规则因模块而异（THS 仅当用户配置了 BYOK Key 才加入；新浪只支持
// 日/周/月线）。等 3+ 个模块真正共享同一条链形时，再把那张表补上，避免现在就造用不上的抽象。

/// 端点级健康追踪（静态、进程内）。连续失败达到阈值后进入冷却，冷却结束自愈。
///
/// 名称约定 `vendor:endpoint`，见文件顶部说明。
class SourceHealth {
  SourceHealth._();

  /// 连续失败达到该次数即进入冷却。
  static const int _maxConsecutiveFailures = 3;

  /// 冷却时长：进入冷却后跳过该端点这么久。
  static const Duration _cooldown = Duration(minutes: 5);

  static final Map<String, _HealthEntry> _entries = {};

  /// 该端点当前是否处于冷却中。冷却到期后返回 `false` 并清除记录，使其获得一次全新机会（自愈）。
  static bool isBlocked(String name) {
    final entry = _entries[name];
    if (entry == null || entry.blockedUntil == null) return false;
    if (DateTime.now().isAfter(entry.blockedUntil!)) {
      _entries.remove(name); // 自愈：冷却到期，清掉记录给一次机会
      return false;
    }
    return true;
  }

  /// 成功：清空该端点的失败计数与冷却。
  static void recordSuccess(String name) {
    _entries.remove(name);
  }

  /// 失败：连续失败计数 +1；达到阈值则标记冷却到 `now + 5min`。
  static void recordFailure(String name) {
    final entry = _entries.putIfAbsent(name, _HealthEntry.new);
    entry.failures += 1;
    if (entry.failures >= _maxConsecutiveFailures) {
      entry.blockedUntil = DateTime.now().add(_cooldown);
    }
  }

  /// 清空所有状态（测试用）。
  static void reset() {
    _entries.clear();
  }
}

class _HealthEntry {
  int failures = 0;
  DateTime? blockedUntil;
}

Future<T> firstSuccess<T>(List<DataSourceAttempt<T>> attempts) async {
  if (attempts.isEmpty) {
    throw NetworkException('无可用数据源', source: 'firstSuccess');
  }

  // 1) 过滤掉处于冷却中的端点（懒执行：绝不触发其 run()）。
  final live = attempts.where((a) => !SourceHealth.isBlocked(a.name)).toList();

  // 2) 若全部冷却中，立即失败，不等待任何超时——这是冷却的全部收益。
  if (live.isEmpty) {
    final names = attempts.map((a) => a.name).join(', ');
    throw NetworkException('所有数据源均在冷却中: $names', source: 'firstSuccess');
  }

  final errors = <String>[];
  final completer = Completer<T>();
  var remaining = live.length;

  void settleAllFailed() {
    if (remaining == 0 && !completer.isCompleted) {
      completer.completeError(
        NetworkException('所有数据源均失败: ${errors.join('; ')}', source: 'firstSuccess'),
      );
    }
  }

  for (final a in live) {
    // 3) 真正触发懒闭包（并行竞速）。
    unawaited(a.run().then((result) {
      if (result != null) {
        // 非 null 即成功：即便落败也清罚，因为它确实可用。
        SourceHealth.recordSuccess(a.name);
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } else {
        // 返回 null 视为失败，记一次失败并进入错误明细。
        SourceHealth.recordFailure(a.name);
        errors.add('${a.name}: 返回 null');
      }
      remaining--;
      settleAllFailed();
    }).catchError((e) {
      // 标的级「确定无数据」不是端点故障：端点显然活着并且答复了，清掉失败计数即可。
      // ponytail: 判断只此一处，所有走 firstSuccess 的模块一并受益 —— 不必在每个调用点
      // 各自防「连看几个无覆盖标的就把共享端点误熔断 5 分钟」。
      if (e is EmptyResponseException && e.definitiveNoData) {
        SourceHealth.recordSuccess(a.name);
      } else {
        SourceHealth.recordFailure(a.name);
      }
      errors.add('${a.name}: $e');
      remaining--;
      settleAllFailed();
    }));
  }

  return completer.future;
}

/// 单次数据源尝试：端点限定名称（用于冷却与错误追踪）+ 懒执行的异步闭包。
class DataSourceAttempt<T> {
  final String name;
  final Future<T> Function() run;
  DataSourceAttempt(this.name, this.run);
}
