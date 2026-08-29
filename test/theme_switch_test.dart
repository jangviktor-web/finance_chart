import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_chart/app/theme.dart';
import 'package:finance_chart/presentation/providers/navigation_provider.dart';

/// 探针：模拟线上 ~200 处「直接读静态 AppColors 取色」的真实写法。
///
/// 这类 Widget 从不调用 Theme.of(context)，因此不会向 Theme 注册依赖 ——
/// 这正是「背景变、字体不变」的根因载体。
class _ColorProbe extends StatelessWidget {
  const _ColorProbe();

  @override
  Widget build(BuildContext context) {
    return Text(
      '主题探针',
      style: TextStyle(color: AppColors.textPrimary),
    );
  }
}

/// 模拟 MainScaffold 的真实结构：const 外壳 + **非 const** 的 IndexedStack children。
///
/// 这一层很关键：const 外壳会被规范化复用，真正决定「是否重建」的是
/// MaterialApp 的 Key 是否变化，以及 IndexedStack 的 children 是否 const。
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: 0,
      children: [_ColorProbe()], // 刻意非 const，与 main_scaffold 保持一致
    );
  }
}

/// 读取探针实际渲染出的字体颜色
Color? _probeColor(WidgetTester tester) {
  final text = tester.widget<Text>(find.text('主题探针'));
  return text.style?.color;
}

void main() {
  // 每个用例结束都复位为默认深色，避免用例间相互污染
  tearDown(() {
    AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
  });

  group('AppColors.applyTheme —— 颜色翻转', () {
    test('深色模式：字体为浅灰、背景为近黑', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      expect(AppColors.textPrimary, const Color(0xFFe0e0e0));
      expect(AppColors.textSecondary, const Color(0xFF888888));
      expect(AppColors.background, const Color(0xFF0a0a0a));
      expect(AppColors.cardBackground, const Color(0xFF1a1a2e));
    });

    test('浅色模式：字体为深灰、背景为浅灰', () {
      AppColors.applyTheme(isDarkMode: false, colorStyle: 'cn');
      expect(AppColors.textPrimary, const Color(0xFF1a1a1a));
      expect(AppColors.textSecondary, const Color(0xFF666666));
      expect(AppColors.background, const Color(0xFFF5F5F5));
      expect(AppColors.cardBackground, const Color(0xFFFFFFFF));
    });

    test('深浅模式的主色确实不同（回归「两种模式字体都浅」）', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      final darkPrimary = AppColors.textPrimary;
      AppColors.applyTheme(isDarkMode: false, colorStyle: 'cn');
      final lightPrimary = AppColors.textPrimary;
      expect(darkPrimary, isNot(equals(lightPrimary)),
          reason: '两种模式的 textPrimary 必须不同，否则就是原 Bug');
    });

    test('涨跌色随 colorStyle 互换', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      expect(AppColors.up, const Color(0xFFef4444), reason: 'A股：红涨');
      expect(AppColors.down, const Color(0xFF22c55e), reason: 'A股：绿跌');

      AppColors.applyTheme(isDarkMode: true, colorStyle: 'us');
      expect(AppColors.up, const Color(0xFF22c55e), reason: '美股：绿涨');
      expect(AppColors.down, const Color(0xFFef4444), reason: '美股：红跌');
    });
  });

  group('themeSignature —— 敏感度', () {
    test('切主题时签名变化', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      final a = AppColors.themeSignature;
      AppColors.applyTheme(isDarkMode: false, colorStyle: 'cn');
      expect(AppColors.themeSignature, isNot(equals(a)));
    });

    test('切涨跌色风格时签名变化', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      final a = AppColors.themeSignature;
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'us');
      expect(AppColors.themeSignature, isNot(equals(a)));
    });

    test('主题配置不变时签名稳定（避免无谓的整树重建）', () {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      final a = AppColors.themeSignature;
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      expect(AppColors.themeSignature, equals(a),
          reason: '签名必须稳定，否则每次 build 都会重建整棵树');
    });

    test('签名格式为 <模式>_<涨跌色风格>', () {
      AppColors.applyTheme(isDarkMode: false, colorStyle: 'us');
      expect(AppColors.themeSignature, 'light_us');
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      expect(AppColors.themeSignature, 'dark_cn');
    });
  });

  group('ValueKey 强制重建 —— 核心修复机制', () {
    // ⚠️ 重要：本 group 只验证「换 Key 确实能翻转颜色」，
    // **不要**用它反推「ValueKey 是否必需」。
    //
    // 原因：这里的 _Shell 是极简模型，且 pumpWidget 会在根节点直接替换
    // MaterialApp、强制根级重建，与真实 App 的重建路径不同 —— 实测在本模型下
    // 即使不换 Key 颜色也会翻转（假阴性），会误导人以为 ValueKey 可以去掉。
    //
    // ValueKey 是否必需的权威判据见 test/theme_app_integration_test.dart：
    // 真实 App 移除 ValueKey 后，浅色模式字体稳定保持 #e0e0e0 不翻转，
    // 精确复现用户报的 Bug —— 故 ValueKey 必需，不可省略。

    testWidgets('【实验组·换 Key】切主题后字体颜色翻转', (tester) async {
      AppColors.applyTheme(isDarkMode: true, colorStyle: 'cn');
      await tester.pumpWidget(MaterialApp(
        key: ValueKey('app_${AppColors.themeSignature}'),
        home: const _Shell(),
      ));
      expect(_probeColor(tester), const Color(0xFFe0e0e0),
          reason: '深色模式应为浅灰字');

      AppColors.applyTheme(isDarkMode: false, colorStyle: 'cn');
      await tester.pumpWidget(MaterialApp(
        key: ValueKey('app_${AppColors.themeSignature}'),
        home: const _Shell(),
      ));

      expect(_probeColor(tester), const Color(0xFF1a1a1a),
          reason: '带 Key 的方案必须能翻转颜色 —— 这是用户报的 Bug 本体');
    });

    // 原先这里有一个「不换 Key」的对照组，但它在本极简模型下会误判为
    // 「不换 Key 也能翻转」，与真实 App 结论相反（假阴性），已删除。
    // 判定请以 theme_app_integration_test.dart 为准。
  });

  group('navIndexProvider —— 切主题不回首页', () {
    testWidgets('MaterialApp 换 Key 重建后，Tab 索引保持', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 模拟用户停留在第 4 个 Tab（0-based index=3）
      container.read(navIndexProvider.notifier).state = 3;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          key: ValueKey('finance_app_dark_cn'),
          home: SizedBox(),
        ),
      ));
      expect(container.read(navIndexProvider), 3);

      // 切主题 → MaterialApp 换 Key → 整棵树重建
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          key: ValueKey('finance_app_light_cn'),
          home: SizedBox(),
        ),
      ));

      expect(container.read(navIndexProvider), 3,
          reason: '切主题后必须停留在原 Tab，不能被弹回首页(0)');
    });

    test('默认索引为 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(navIndexProvider), 0);
    });
  });
}
