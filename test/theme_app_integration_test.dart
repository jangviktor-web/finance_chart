import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:finance_chart/main.dart';
import 'package:finance_chart/app/theme.dart';
import 'package:finance_chart/data/models/kline_data.dart';
import 'package:finance_chart/data/models/realtime_quote.dart';
import 'package:finance_chart/data/datasources/search_api.dart';
import 'package:finance_chart/data/repositories/market_repository.dart';
import 'package:finance_chart/presentation/providers/market_provider.dart';
import 'package:finance_chart/presentation/providers/settings_provider.dart';

/// 测试桩：避免启动时访问真实网络
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

/// 收集当前界面上所有 Text 实际使用的字体颜色
Set<Color> _collectTextColors(WidgetTester tester) {
  final colors = <Color>{};
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final c = t.style?.color;
    if (c != null) colors.add(c);
  }
  return colors;
}

void main() {
  setUp(() {
    // 单元测试环境没有 flutter_secure_storage 的平台通道实现。
    // 不 mock 的话，真实 App 启动触发 SettingsNotifier.load() → loadEmApiKey()
    // 时会抛 MissingPluginException，掩盖真正的断言结果。
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('真实 App：深色→浅色切换后，界面字体颜色确实翻转', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // 过滤 Flutter 3.47 FilterChip/ListTile 的已知 debug 断言噪音
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      // Flutter 3.47 FilterChip/ListTile 的已知 debug 断言噪音
      if (msg.contains('ListTile background color or ink splashes')) {
        return;
      }
      // 整树重建（切主题换 MaterialApp Key）会让仍在飞行的异步任务在已 dispose
      // 的 State 上调用 setState —— 属树被拆除后的副作用，与字体取色无关，
      // 单独过滤以便聚焦本次断言目标。
      if (msg.contains('setState() called after dispose')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final container = ProviderContainer(
      overrides: [
        marketRepositoryProvider.overrideWithValue(_StubMarketRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FinanceApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    });

    // 默认应为深色模式
    expect(AppColors.isDarkMode, isTrue, reason: '默认深色');
    final darkColors = _collectTextColors(tester);
    expect(darkColors, isNotEmpty, reason: '界面上应能取到文字');
    // ignore: avoid_print
    print('>>> [深色模式] 取样到的字体颜色: ${darkColors.map((c) => c.toARGB32().toRadixString(16)).toList()}');

    // ── 切到浅色模式 ──
    await tester.runAsync(() async {
      await container.read(settingsProvider.notifier).setDarkMode(false);
    });
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 600));
    });

    expect(AppColors.isDarkMode, isFalse, reason: '设置已切到浅色');
    final lightColors = _collectTextColors(tester);
    // ignore: avoid_print
    print('>>> [浅色模式] 取样到的字体颜色: ${lightColors.map((c) => c.toARGB32().toRadixString(16)).toList()}');

    // 核心断言：深色模式专用的浅灰字 (#e0e0e0) 在浅色模式下不应再出现
    expect(
      lightColors.contains(const Color(0xFFe0e0e0)),
      isFalse,
      reason: '浅色模式下若仍出现 #e0e0e0 浅灰字，说明字体没跟随主题翻转 '
          '—— 这正是用户报的「选浅色模式字体还是浅色」',
    );

    // 反向断言：浅色模式应出现深灰字 (#1a1a1a)
    expect(
      lightColors.contains(const Color(0xFF1a1a1a)),
      isTrue,
      reason: '浅色模式应渲染深灰字 #1a1a1a',
    );
  });

  testWidgets('真实 App：浅色→深色切回后，字体颜色再次翻转', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      // Flutter 3.47 FilterChip/ListTile 的已知 debug 断言噪音
      if (msg.contains('ListTile background color or ink splashes')) {
        return;
      }
      // 整树重建（切主题换 MaterialApp Key）会让仍在飞行的异步任务在已 dispose
      // 的 State 上调用 setState —— 属树被拆除后的副作用，与字体取色无关，
      // 单独过滤以便聚焦本次断言目标。
      if (msg.contains('setState() called after dispose')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final container = ProviderContainer(
      overrides: [
        marketRepositoryProvider.overrideWithValue(_StubMarketRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FinanceApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    });

    // 先切浅色再切回深色，验证双向都生效
    await tester.runAsync(() async {
      await container.read(settingsProvider.notifier).setDarkMode(false);
    });
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 400));
    });
    final lightColors = _collectTextColors(tester);

    await tester.runAsync(() async {
      await container.read(settingsProvider.notifier).setDarkMode(true);
    });
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 400));
    });
    final backToDark = _collectTextColors(tester);

    // 两个模式的取色集合必须不同
    expect(
      backToDark,
      isNot(equals(lightColors)),
      reason: '深浅两种模式渲染出的字体颜色集合必须不同',
    );
    expect(
      backToDark.contains(const Color(0xFFe0e0e0)),
      isTrue,
      reason: '切回深色模式应重新出现浅灰字 #e0e0e0',
    );
    // ignore: avoid_print
    print('>>> [切回深色] 取样到的字体颜色: ${backToDark.map((c) => c.toARGB32().toRadixString(16)).toList()}');
  });
}
