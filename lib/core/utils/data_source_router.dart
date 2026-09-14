import 'dart:async';
import '../../core/errors/api_exception.dart';

/// 多数据源竞速/兜底工具（全 app 数据模块共用）。
///
/// 并发尝试 [attempts] 中所有源，返回**第一个成功（非 null）**的结果；
/// 全部失败则抛出 [NetworkException] 并附带各源错误明细。
///
/// 源自 `market_api._race`——原本是行情/K线私有的兜底逻辑，抽取为共享工具，
/// 让财务/估值/资金流/宏观/新闻/情绪等所有模块都能「数据源失效自动切换」。
///
/// 用法：
/// ```dart
/// return firstSuccess(<DataSourceAttempt<MyData>>[
///   DataSourceAttempt('tencent', _fromTencent(code)),   // keyless，首选
///   DataSourceAttempt('eastmoney', _fromEastmoney(code)),
///   if (thinksApi != null)
///     DataSourceAttempt('thinks', _fromThinks(code)),   // keyed，按需
/// ]);
/// ```
Future<T> firstSuccess<T>(List<DataSourceAttempt<T>> attempts) async {
  if (attempts.isEmpty) {
    throw NetworkException('无可用数据源', source: 'firstSuccess');
  }
  final errors = <String>[];
  final completer = Completer<T>();
  var remaining = attempts.length;

  for (final a in attempts) {
    a.future.then((result) {
      if (result != null && !completer.isCompleted) {
        completer.complete(result);
      }
      remaining--;
      if (remaining == 0 && !completer.isCompleted) {
        completer.completeError(
          NetworkException('所有数据源均失败: ${errors.join('; ')}', source: 'firstSuccess'),
        );
      }
    }).catchError((e) {
      errors.add('${a.name}: $e');
      remaining--;
      if (remaining == 0 && !completer.isCompleted) {
        completer.completeError(
          NetworkException('所有数据源均失败: ${errors.join('; ')}', source: 'firstSuccess'),
        );
      }
    });
  }

  return completer.future;
}

/// 单次数据源尝试：名称（用于错误追踪）+ 异步 Future。
class DataSourceAttempt<T> {
  final String name;
  final Future<T> future;
  DataSourceAttempt(this.name, this.future);
}
