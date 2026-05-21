import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../data/models/indicator_params.dart';
import '../../providers/indicator_params_provider.dart';

/// 指标选择器 — 30+ 指标分组
class IndicatorSelector extends ConsumerWidget {
  final String selectedIndicator;
  final ValueChanged<String> onIndicatorChanged;
  final Set<String> activeOverlays;
  final ValueChanged<Set<String>>? onOverlaysChanged;

  const IndicatorSelector({
    super.key,
    required this.selectedIndicator,
    required this.onIndicatorChanged,
    this.activeOverlays = const {},
    this.onOverlaysChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(indicatorParamsProvider);

    return DefaultTabController(
      length: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 叠加指标 toggle 区域
          _buildOverlayChips(params),
          // 副图指标 Tab 选择
          SizedBox(
            height: 32,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              dividerHeight: 0,
              tabs: const [
                Tab(text: '趋势'),
                Tab(text: '振荡'),
                Tab(text: '量能'),
                Tab(text: '其他'),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: TabBarView(
              children: [
                _buildIndicatorRow(_trendIndicators(params)),
                _buildIndicatorRow(_oscillatorIndicators(params)),
                _buildIndicatorRow(_volumeIndicators(params)),
                _buildIndicatorRow(_otherIndicators(params)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 叠加指标 — toggle chip (显示在主图上)
  Widget _buildOverlayChips(IndicatorParams params) {
    final overlays = [
      ('MA', params.maLabel),
      ('BOLL', params.bollLabel),
      ('BBI', 'BBI'),
      ('EXPMA', params.expmaLabel),
      ('KTN', params.ktnLabel),
    ];

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: overlays.map((item) {
          final isActive = activeOverlays.contains(item.$1);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                if (onOverlaysChanged == null) return;
                final newSet = Set<String>.from(activeOverlays);
                if (isActive) {
                  newSet.remove(item.$1);
                } else {
                  newSet.add(item.$1);
                }
                onOverlaysChanged!(newSet);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<(String, String)> _trendIndicators(IndicatorParams p) => [
    ('MACD', p.macdLabel),
    ('DMI', p.dmiLabel),
    ('TRIX', p.trixLabel),
    ('BIAS', p.biasLabel),
    ('DFMA', 'DFMA'),
    ('EXPMA', p.expmaLabel),
  ];

  List<(String, String)> _oscillatorIndicators(IndicatorParams p) => [
    ('KDJ', p.kdjLabel),
    ('RSI', p.rsiLabel),
    ('CCI', p.cciLabel),
    ('WR', p.wrLabel),
    ('MFI', p.mfiLabel),
    ('VR', p.vrLabel),
    ('ROC', p.rocLabel),
    ('MTM', p.mtmLabel),
  ];

  List<(String, String)> _volumeIndicators(IndicatorParams p) => [
    ('OBV', 'OBV'),
    ('EMV', 'EMV(14)'),
    ('ASI', 'ASI'),
  ];

  List<(String, String)> _otherIndicators(IndicatorParams p) => [
    ('ATR', p.atrLabel),
    ('PSY', p.psyLabel),
    ('CR', p.crLabel),
    ('DPO', p.dpoLabel),
    ('BRAR', 'BRAR(26)'),
    ('MASS', p.massLabel),
  ];

  Widget _buildIndicatorRow(List<(String, String)> indicators) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      children: indicators.map((item) {
        final isSelected = item.$1 == selectedIndicator;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onIndicatorChanged(item.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ma20.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? AppColors.ma20 : AppColors.textSecondary.withOpacity(0.3),
                ),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: isSelected ? AppColors.ma20 : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
