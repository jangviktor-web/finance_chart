import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/models/stock_score.dart';
import '../../data/datasources/search_api.dart';
import '../../domain/services/scoring_engine.dart';
import '../providers/market_provider.dart';
import '../widgets/chart/radar_chart_painter.dart';
import 'chart_screen.dart';

/// 多股对比页面
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  final List<String> _codes = [];
  final _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _searching = false;

  static const _colors = [
    Color(0xFF3b82f6), // blue
    Color(0xFFf59e0b), // amber
    Color(0xFF22c55e), // green
    Color(0xFFef4444), // red
    Color(0xFF8b5cf6), // purple
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addCode(String code) {
    if (_codes.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('最多对比 5 只股票'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_codes.contains(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('已在对比列表中'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() {
      _codes.add(code);
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _removeCode(String code) {
    setState(() => _codes.remove(code));
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _searching = true);
    try {
      final api = ref.read(searchApiProvider);
      final results = await api.search(keyword);
      setState(() => _searchResults = results.take(8).toList());
    } catch (_) {
      // ignore
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('多股对比'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 已选股票 chips
          if (_codes.isNotEmpty) _buildSelectedChips(),
          // 搜索结果
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          // 内容区
          Expanded(child: _codes.isEmpty ? _buildEmptyState() : _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '输入股票代码或名称搜索添加...',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) {
          if (v.length >= 2) _search(v);
          else setState(() => _searchResults.clear());
        },
      ),
    );
  }

  Widget _buildSelectedChips() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _codes.length,
        itemBuilder: (_, i) {
          final code = _codes[i];
          final color = _colors[i % _colors.length];
          final marketState = ref.watch(klineProvider(code));
          final name = marketState.quote.name;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Chip(
              label: Text('${name ?? code}  ×', style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: color.withOpacity(0.8),
              deleteIconColor: Colors.white70,
              onDeleted: () => _removeCode(code),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (_, i) {
          final item = _searchResults[i];
          final code = item.code;
          final name = item.name;
          return ListTile(
            dense: true,
            title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(code, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
            onTap: () => _addCode(code),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('搜索并添加股票进行对比', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('最多支持 5 只股票同时对比', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 收集所有股票的评分
    final scores = <StockScore>[];
    for (int i = 0; i < _codes.length; i++) {
      final code = _codes[i];
      final state = ref.watch(klineProvider(code));
      if (state.isLoading) continue;
      final score = ScoringEngine.calculate(
        code: code,
        name: state.quote.name,
        klines: state.klines,
        indicators: state.indicators,
      );
      scores.add(score);
    }

    if (scores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 雷达图
        _buildRadarChart(scores),
        const SizedBox(height: 20),
        // 评分排名表
        _buildScoreTable(scores),
        const SizedBox(height: 16),
        // 各股票详情卡片
        ...scores.map((s) => _buildStockCard(s)),
      ],
    );
  }

  Widget _buildRadarChart(List<StockScore> scores) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('综合评分雷达图', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: RadarChartPainter(scores: scores, colors: _colors),
            ),
          ),
          // 图例
          Wrap(
            spacing: 12,
            children: List.generate(scores.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(scores[i].name, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTable(List<StockScore> scores) {
    // 按总分排序
    final sorted = [...scores]..sort((a, b) => b.total.compareTo(a.total));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('评分排名', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // 表头
          Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
              SizedBox(width: 60, child: Text('股票', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
              Expanded(child: Text('总分', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
              ...StockScore.dimensionLabels.map((l) =>
                SizedBox(width: 36, child: Text(l, style: TextStyle(color: AppColors.textSecondary, fontSize: 10), textAlign: TextAlign.center))),
            ],
          ),
          const Divider(height: 16),
          ...List.generate(sorted.length, (i) {
            final s = sorted[i];
            final color = _colors[_codes.indexOf(s.code) % _colors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
                  SizedBox(
                    width: 60,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChartScreen(stockCode: s.code))),
                      child: Text(s.name, style: TextStyle(color: AppColors.primary, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(s.total.toStringAsFixed(1), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: s.total / 100,
                              backgroundColor: AppColors.surface,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...s.values.map((v) => SizedBox(
                    width: 36,
                    child: Text(v.toStringAsFixed(0), style: TextStyle(color: _scoreColor(v), fontSize: 11), textAlign: TextAlign.center),
                  )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockCard(StockScore score) {
    final labels = StockScore.dimensionLabels;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(score.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(score.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor(score.total).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${score.total.toStringAsFixed(1)} 分',
                  style: TextStyle(color: _scoreColor(score.total), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final value = score.values[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 36, child: Text(labels[i], style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value / 100,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation(_scoreColor(value)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 32, child: Text(value.toStringAsFixed(0), style: TextStyle(color: AppColors.textPrimary, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return AppColors.up;
    if (score >= 40) return AppColors.warning;
    return AppColors.down;
  }
}
