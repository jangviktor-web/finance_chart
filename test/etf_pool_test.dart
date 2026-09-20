import 'package:flutter_test/flutter_test.dart';

import 'package:finance_chart/presentation/screens/etf_rotation_screen.dart';

/// ETF 轮动池的两个关键性质：
/// 1. **池子逐只对齐规格**（《ETF 轮动 · App 对齐规格 v2》一节：33 只，不得自行增减）；
/// 2. **默认池换代时的迁移**分支正确（唯一会改动用户持久化数据的地方）。
void main() {
  group('池子对齐规格（33 只）', () {
    const specPool = [
      'sh510300', 'sh510500', 'sh588000', 'sz159915',
      'sh512100', 'sz159949', 'sh510050', 'sz159901',
      'sh512480', 'sz159995', 'sh512760', 'sh515880',
      'sh515050', 'sz159852',
      'sh512800', 'sh512000', 'sh512070',
      'sh512010', 'sh512170', 'sz159992',
      'sh512690', 'sz159928',
      'sh512660', 'sh515030', 'sh515790',
      'sh512400', 'sh515220', 'sz159980', 'sh518880',
      'sh513050', 'sh513180', 'sh513500',
      'sz159825',
    ];

    test('代码集合与规格完全一致（33 只，无增减）', () {
      expect(etfRotationDefaultPool.length, 33);
      expect(etfRotationDefaultPool.toSet(), specPool.toSet());
      expect(etfRotationDefaultPool.toSet().length, 33, reason: '不得有重复代码');
    });

    test('池外标的已移除：纳指ETF/电力ETF/养殖ETF 等', () {
      for (final gone in [
        'sh513100', // 纳指ETF
        'sz159611', // 电力ETF
        'sz159865', // 养殖ETF
        'sh588200', // 科创芯片ETF
        'sh512890', // 红利低波ETF
        'sh562500', // 机器人ETF
        'sz159781', // 双创50ETF
        'sh515980', // 人工智能ETF
        'sh513520', // 日经225ETF
        'sz159869', // 游戏ETF
        'sh512980', // 传媒ETF
        'sh512880', // 证券ETF（规格用的是券商ETF sh512000）
      ]) {
        expect(etfRotationDefaultPool, isNot(contains(gone)),
            reason: '$gone 属于池外标的，必须移除');
      }
    });

    test('规格新增标的已补齐', () {
      for (final added in [
        'sh515880', // 通信ETF国泰
        'sh515050', // 通信ETF华夏
        'sh512760', // 芯片ETF国泰
        'sz159852', // 软件ETF嘉实
        'sz159949', // 创业板50ETF
        'sh512000', // 券商ETF
        'sh512070', // 证券保险ETF
        'sz159980', // 有色ETF大成
        'sh515790', // 光伏ETF
      ]) {
        expect(etfRotationDefaultPool, contains(added));
      }
    });

    test('每个池内代码都有展示名称（防「界面只显示裸代码」回归）', () {
      for (final code in etfRotationDefaultPool) {
        expect(etfRotationDefaultNames[code], isNotNull,
            reason: '$code 缺名称，界面会显示裸代码');
        expect(etfRotationDefaultNames[code]!.trim(), isNotEmpty);
      }
    });

    test('名称表无池外冗余项', () {
      expect(
        etfRotationDefaultNames.keys.toSet(),
        etfRotationDefaultPool.toSet(),
      );
    });
  });

  group('默认池换代迁移', () {
    const def = ['sh510300', 'sz159915', 'sh512800'];

    test('用户自定义过池子 → 永不覆盖', () {
      expect(
        shouldReseedEtfPool(
            stored: ['sh510300'], currentDefault: def, customized: true),
        isFalse,
      );
      // 即使存量池与默认池毫无交集，只要用户改过就不动他的数据
      expect(
        shouldReseedEtfPool(
            stored: ['sh600519'], currentDefault: def, customized: true),
        isFalse,
      );
    });

    test('未自定义 + 存量池与默认池不一致 → 迁移到新池', () {
      // 旧池遗留代码：不在新名称表里，正是「名称不显示」的成因
      expect(
        shouldReseedEtfPool(
          stored: ['sh159920', 'sh510880', 'sz159825'],
          currentDefault: def,
          customized: false,
        ),
        isTrue,
      );
    });

    test('未自定义 + 已与默认池一致 → 不迁移（顺序/重复无关）', () {
      expect(
        shouldReseedEtfPool(stored: def, currentDefault: def, customized: false),
        isFalse,
      );
      expect(
        shouldReseedEtfPool(
          stored: ['sh512800', 'sh510300', 'sh510300', 'sz159915'],
          currentDefault: def,
          customized: false,
        ),
        isFalse,
      );
    });

    test('从旧 35 只池迁移到新 33 只池会被触发', () {
      expect(
        shouldReseedEtfPool(
          stored: const [
            'sh513100', 'sz159611', 'sz159865', 'sh588200', 'sh512890',
          ],
          currentDefault: etfRotationDefaultPool,
          customized: false,
        ),
        isTrue,
      );
      expect(
        shouldReseedEtfPool(
          stored: etfRotationDefaultPool,
          currentDefault: etfRotationDefaultPool,
          customized: false,
        ),
        isFalse,
      );
    });
  });
}
