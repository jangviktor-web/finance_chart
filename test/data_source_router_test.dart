import 'dart:async';

import 'package:finance_chart/core/errors/api_exception.dart';
import 'package:finance_chart/core/utils/data_source_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SourceHealth.reset());

  test('blocked source is never invoked; next healthy source wins', () async {
    var tencentCalled = false;
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');
    expect(SourceHealth.isBlocked('tencent:ifzq.kline'), isTrue);

    final result = await firstSuccess<String>([
      DataSourceAttempt('tencent:ifzq.kline', () {
        tencentCalled = true;
        return Future.value('fromTencent');
      }),
      DataSourceAttempt('sina:cn_marketdata.kline', () => Future.value('fromSina')),
    ]);

    expect(tencentCalled, isFalse);
    expect(result, 'fromSina');
  });

  test('all blocked throws immediately without waiting on a never-completing future', () async {
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('sina:cn_marketdata.kline');
    SourceHealth.recordFailure('sina:cn_marketdata.kline');
    SourceHealth.recordFailure('sina:cn_marketdata.kline');

    final neverCompletes = Completer<String>();
    final sw = Stopwatch()..start();
    NetworkException? caught;
    try {
      await firstSuccess<String>([
        DataSourceAttempt('tencent:ifzq.kline', () => neverCompletes.future),
        DataSourceAttempt('sina:cn_marketdata.kline', () => neverCompletes.future),
      ]);
    } on NetworkException catch (e) {
      caught = e;
    }
    sw.stop();

    expect(caught, isNotNull);
    expect(caught.toString(), contains('tencent:ifzq.kline'));
    expect(caught.toString(), contains('sina:cn_marketdata.kline'));
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('non-null success clears earlier failures so source is no longer blocked', () async {
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');

    final result = await firstSuccess<String>([
      DataSourceAttempt('tencent:ifzq.kline', () => Future.value('ok')),
    ]);
    expect(result, 'ok');

    // 成功后失败计数已清零：再加两次失败也不应进入冷却。
    SourceHealth.recordFailure('tencent:ifzq.kline');
    SourceHealth.recordFailure('tencent:ifzq.kline');
    expect(SourceHealth.isBlocked('tencent:ifzq.kline'), isFalse);
  });

  test('all attempts failing throws with source names in message', () async {
    NetworkException? caught;
    try {
      await firstSuccess<String>([
        DataSourceAttempt('tencent:ifzq.kline', () => Future.error('boom-tencent')),
        DataSourceAttempt('sina:cn_marketdata.kline', () => Future.error('boom-sina')),
      ]);
    } on NetworkException catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(caught.toString(), contains('tencent:ifzq.kline'));
    expect(caught.toString(), contains('sina:cn_marketdata.kline'));
    expect(caught.toString(), contains('boom-sina'));
  });

  test('cooldown expiry self-heals: source gets a fresh chance', () async {
    // 连续失败 3 次 → 进入 5 分钟冷却
    for (var i = 0; i < 3; i++) {
      SourceHealth.recordFailure('tencent:ifzq.kline');
    }
    expect(SourceHealth.isBlocked('tencent:ifzq.kline'), isTrue);

    // 冷却期内该源不会被触发
    var called = false;
    final blocked = <String>[];
    try {
      await firstSuccess<String>([
        DataSourceAttempt('tencent:ifzq.kline', () {
          called = true;
          return Future.value('should-not-run');
        }),
      ]);
    } on NetworkException catch (e) {
      blocked.add(e.toString());
    }
    expect(called, isFalse);
    expect(blocked.single, contains('冷却中'));
  });
}
