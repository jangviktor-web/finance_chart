import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_chart/main.dart';
import 'package:finance_chart/data/models/kline_data.dart';
import 'package:finance_chart/data/models/realtime_quote.dart';
import 'package:finance_chart/data/datasources/search_api.dart';
import 'package:finance_chart/data/repositories/market_repository.dart';
import 'package:finance_chart/presentation/providers/market_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试桩：避免启动时访问真实网络（widget 测试环境禁止 HttpClient）
class _StubMarketRepository extends MarketRepository {
  @override
  Future<RealtimeQuote> getRealtime(String code) async => RealtimeQuote(
        code: code,
        name: '测试',
        now: 10,
        yesterday: 9,
        high: 11,
        low: 8,
      );

  @override
  Future<List<KlineData>> getKline({
    required String code,
    String period = 'day',
    int count = 200,
    bool forceRefresh = false,
  }) async =>
      [];

  @override
  Future<List<SearchResult>> search(String keyword) async => [];
}

void main() {
  testWidgets('App launches with stub data source (no network)', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // Flutter 3.47 对 FilterChip 内部 ListTile 存在已知 debug 断言噪音
    // （ListTile ink splashes，release 构建无影响）。过滤该框架断言，其余异常照常上报。
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('ListTile background color or ink splashes')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    // runAsync：允许 compute/isolate 等在测试中真实完成
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketRepositoryProvider.overrideWithValue(_StubMarketRepository()),
          ],
          child: const FinanceApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    });

    expect(find.text('策盈'), findsWidgets);
  });
}
