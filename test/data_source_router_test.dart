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

  test('标的级「确定无数据」不计入端点熔断：连续 3 次仍不冷却', () async {
    // 复现原缺陷：东财 F10 端点被所有标的共用，看 3 个无覆盖标的（港股/美股/ETF）
    // 就会把端点误熔断 5 分钟，导致之后正常 A 股的请求被直接跳过。
    const name = 'em:dc.f10_statement_income';
    for (var i = 0; i < 3; i++) {
      await expectLater(
        firstSuccess<String>([
          DataSourceAttempt(
            name,
            () => Future.error(EmptyResponseException(
              'https://datacenter-web.eastmoney.com/api/data/v1/get',
              upstreamMessage: '返回数据为空',
              definitiveNoData: true,
            )),
          ),
        ]),
        throwsA(isA<NetworkException>()),
      );
    }
    expect(SourceHealth.isBlocked(name), isFalse);
  });

  test('暂时性业务空（限流）仍计入熔断，保留挡洪峰能力', () async {
    const name = 'em:dc.f10_statement_income';
    for (var i = 0; i < 3; i++) {
      await expectLater(
        firstSuccess<String>([
          DataSourceAttempt(
            name,
            () => Future.error(EmptyResponseException(
              'https://datacenter-web.eastmoney.com/api/data/v1/get',
              upstreamMessage: '服务器繁忙',
            )),
          ),
        ]),
        throwsA(isA<NetworkException>()),
      );
    }
    expect(SourceHealth.isBlocked(name), isTrue);
  });

  test('「确定无数据」也清零先前的临时失败计数', () async {
    const name = 'em:dc.f10_statement_income';
    SourceHealth.recordFailure(name);
    SourceHealth.recordFailure(name);

    await expectLater(
      firstSuccess<String>([
        DataSourceAttempt(
          name,
          () => Future.error(EmptyResponseException(
            'https://datacenter-web.eastmoney.com/api/data/v1/get',
            upstreamMessage: '返回数据为空',
            definitiveNoData: true,
          )),
        ),
      ]),
      throwsA(isA<NetworkException>()),
    );

    SourceHealth.recordFailure(name);
    SourceHealth.recordFailure(name);
    expect(SourceHealth.isBlocked(name), isFalse);
  });
}
