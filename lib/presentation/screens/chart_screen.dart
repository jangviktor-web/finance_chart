import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/market_provider.dart';
import '../providers/watchlist_provider.dart';
import '../providers/indicator_params_provider.dart';
import '../../data/models/indicator_params.dart';
import '../widgets/chart/chart_header.dart';
import '../widgets/chart/chart_period_selector.dart';
import '../widgets/chart/indicator_selector.dart';
import '../widgets/chart/kline_chart_widget.dart';
import '../widgets/common/error_widget.dart';
import 'analysis_screen.dart';
import '../../app/theme.dart';
import '../../data/models/watchlist_group.dart';

class ChartScreen extends ConsumerStatefulWidget {
  final String stockCode;

  const ChartScreen({super.key, required this.stockCode});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  String _selectedPeriod = 'day';
  String _selectedIndicator = 'MACD';
  Set<String> _activeOverlays = {'MA'};

  @override
  void initState() {
    super.initState();
    // 初始加载由 Riverpod provider 自动触发
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    ref.read(klineProvider(widget.stockCode).notifier).load(period: period);
  }

  void _onIndicatorChanged(String indicator) {
    setState(() {
      _selectedIndicator = indicator;
      // 切换副图指标时，重置叠加指标为默认状态（仅保留 MA）
      _activeOverlays = {'MA'};
    });
    // 按需请求扩展指标计算
    final basicIndicators = {'MA', 'MACD', 'KDJ', 'RSI', 'BOLL'};
    if (!basicIndicators.contains(indicator)) {
      ref.read(klineProvider(widget.stockCode).notifier).requestIndicators({indicator});
    }
  }

  void _onOverlaysChanged(Set<String> overlays) {
    setState(() => _activeOverlays = overlays);
    // 按需请求叠加指标计算
    final needed = <String>{};
    for (final o in overlays) {
      if (o != 'MA' && o != 'BOLL') needed.add(o);
    }
    if (needed.isNotEmpty) {
      ref.read(klineProvider(widget.stockCode).notifier).requestIndicators(needed);
    }
  }

  void _openAnalysis(MarketState state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          stockCode: widget.stockCode,
          stockName: state.quote.name.isNotEmpty ? state.quote.name : widget.stockCode,
          klines: state.klines,
          indicators: state.indicators,
        ),
      ),
    );
  }

  void _showAddToWatchlistSheet() {
    final groups = ref.read(watchlistProvider);
    final code = widget.stockCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('添加到自选',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(code.toUpperCase(),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            ...groups.map((group) {
              final isInGroup = group.codes.contains(code);
              return ListTile(
                leading: Icon(
                  isInGroup ? Icons.check_circle : Icons.add_circle_outline,
                  color: isInGroup ? AppColors.up : AppColors.textSecondary,
                ),
                title: Text(group.name,
                  style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('${group.codes.length}只股票',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  final notifier = ref.read(watchlistProvider.notifier);
                  if (isInGroup) {
                    notifier.removeStock(group.id, code);
                  } else {
                    notifier.addStock(group.id, code);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isInGroup ? '已从"${group.name}"移除' : '已添加到"${group.name}"'),
                      backgroundColor: AppColors.up,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showIndicatorParamsDialog() {
    final params = ref.read(indicatorParamsProvider);
    // 临时状态用于编辑
    List<int> maPeriods = List.from(params.maPeriods);
    int macdShort = params.macdShort;
    int macdLong = params.macdLong;
    int macdSignal = params.macdSignal;
    int rsiPeriod = params.rsiPeriod;
    int kdjPeriod = params.kdjPeriod;
    int bollPeriod = params.bollPeriod;
    double bollMultiplier = params.bollMultiplier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text('指标参数设置',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        maPeriods = [5, 10, 20, 60];
                        macdShort = 12; macdLong = 26; macdSignal = 9;
                        rsiPeriod = 14; kdjPeriod = 9;
                        bollPeriod = 20; bollMultiplier = 2.0;
                      });
                    },
                    child: const Text('恢复默认', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: AppColors.divider),

              // ── MA 周期 ──
              _buildSectionLabel('MA 均线周期'),
              Wrap(
                spacing: 8,
                children: [5, 10, 20, 60, 120, 250].map((p) {
                  final selected = maPeriods.contains(p);
                  return FilterChip(
                    label: Text('$p', style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                    )),
                    selected: selected,
                    onSelected: (v) {
                      setSheetState(() {
                        if (v && maPeriods.length < 5) {
                          maPeriods.add(p);
                          maPeriods.sort();
                        } else if (!v) {
                          maPeriods.remove(p);
                        }
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── MACD ──
              _buildSectionLabel('MACD 参数'),
              _buildSliderRow('快线(DIF短)', macdShort.toDouble(), 5, 20, (v) {
                setSheetState(() => macdShort = v.round());
              }),
              _buildSliderRow('慢线(DIF长)', macdLong.toDouble(), 15, 40, (v) {
                setSheetState(() => macdLong = v.round());
              }),
              _buildSliderRow('信号线(DEA)', macdSignal.toDouble(), 3, 15, (v) {
                setSheetState(() => macdSignal = v.round());
              }),
              const SizedBox(height: 16),

              // ── RSI ──
              _buildSectionLabel('RSI 周期'),
              _buildSliderRow('周期', rsiPeriod.toDouble(), 5, 30, (v) {
                setSheetState(() => rsiPeriod = v.round());
              }),
              const SizedBox(height: 16),

              // ── KDJ ──
              _buildSectionLabel('KDJ 周期'),
              _buildSliderRow('周期', kdjPeriod.toDouble(), 5, 30, (v) {
                setSheetState(() => kdjPeriod = v.round());
              }),
              const SizedBox(height: 16),

              // ── BOLL ──
              _buildSectionLabel('BOLL 参数'),
              _buildSliderRow('周期', bollPeriod.toDouble(), 10, 40, (v) {
                setSheetState(() => bollPeriod = v.round());
              }),
              _buildSliderRow('倍数', bollMultiplier, 1.0, 3.0, (v) {
                setSheetState(() => bollMultiplier = double.parse(v.toStringAsFixed(1)));
              }),
              const SizedBox(height: 24),

              // ── 应用按钮 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newParams = IndicatorParams(
                      maPeriods: maPeriods,
                      macdShort: macdShort,
                      macdLong: macdLong,
                      macdSignal: macdSignal,
                      rsiPeriod: rsiPeriod,
                      kdjPeriod: kdjPeriod,
                      bollPeriod: bollPeriod,
                      bollMultiplier: bollMultiplier,
                    );
                    ref.read(indicatorParamsProvider.notifier).updateParams(newParams);
                    ref.read(klineProvider(widget.stockCode).notifier).recalculateIndicators(newParams);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('指标参数已更新'), backgroundColor: AppColors.up, duration: Duration(seconds: 1)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('应用参数'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(color: AppColors.ma5, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    final isInt = value == value.roundToDouble();
    final displayValue = isInt ? value.round().toString() : value.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surface,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(displayValue, style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(klineProvider(widget.stockCode));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(state.quote.name.isNotEmpty ? state.quote.name : widget.stockCode),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(watchlistProvider.notifier).isStockWatched(widget.stockCode)
                  ? Icons.star
                  : Icons.star_border,
              color: ref.watch(watchlistProvider.notifier).isStockWatched(widget.stockCode)
                  ? AppColors.ma5
                  : AppColors.textSecondary,
            ),
            tooltip: '收藏',
            onPressed: () => _showAddToWatchlistSheet(),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '指标参数',
            onPressed: () => _showIndicatorParamsDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: '技术分析',
            onPressed: state.klines.isNotEmpty ? () => _openAnalysis(state) : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(klineProvider(widget.stockCode).notifier).load(period: _selectedPeriod),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? AppErrorWidget(
                  message: state.error!,
                  onRetry: () => ref.read(klineProvider(widget.stockCode).notifier).load(period: _selectedPeriod),
                )
              : _buildChartContent(state),
    );
  }

  Widget _buildChartContent(MarketState state) {
    return Column(
      children: [
        ChartHeader(quote: state.quote),
        ChartPeriodSelector(
          selectedPeriod: _selectedPeriod,
          onPeriodChanged: _onPeriodChanged,
        ),
        Expanded(
          child: KlineChartWidget(
            klines: state.klines,
            indicators: state.indicators,
            selectedIndicator: _selectedIndicator,
            activeOverlays: _activeOverlays,
            period: state.period,
          ),
        ),
        IndicatorSelector(
          selectedIndicator: _selectedIndicator,
          onIndicatorChanged: _onIndicatorChanged,
          activeOverlays: _activeOverlays,
          onOverlaysChanged: _onOverlaysChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
