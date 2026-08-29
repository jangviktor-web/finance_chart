import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/thinks_api.dart';
import '../../data/models/ths_extra_data.dart';
import '../../presentation/providers/settings_provider.dart';
import 'chart_screen.dart';

/// 盘中热度 — 同花顺特色数据（连板天梯 / 异动 / 热股榜 / 飙升榜）
class ThsHotScreen extends ConsumerStatefulWidget {
  const ThsHotScreen({super.key});

  @override
  ConsumerState<ThsHotScreen> createState() => _ThsHotScreenState();
}

class _ThsHotScreenState extends ConsumerState<ThsHotScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ThinksApi? _ths;
  late final bool _configured;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final key = ref.read(settingsProvider).thinksApiKey;
    _configured = key.isNotEmpty;
    _ths = _configured ? ThinksApi(apiKey: key) : null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('盘中热度'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '连板天梯'),
            Tab(text: '异动'),
            Tab(text: '热股榜'),
            Tab(text: '飙升榜'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_configured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.warning.withOpacity(0.12),
              child: Text('未配置同花顺 API Key，数据为空。请到「设置 → 同花顺 API Key」填入后重试。',
                  style: TextStyle(color: AppColors.warning, fontSize: 12)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LadderTab(ths: _ths, configured: _configured),
                _AnomalyTab(ths: _ths, configured: _configured),
                _RankTab(ths: _ths, configured: _configured, hot: true),
                _RankTab(ths: _ths, configured: _configured, hot: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用加载/错误/空态
Widget _stateWidget({
  required bool loading,
  String? error,
  bool configured = true,
  required VoidCallback onRetry,
  required Widget child,
  bool isEmpty = false,
}) {
  if (loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  if (error != null) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.warning, size: 36),
          const SizedBox(height: 8),
          Text('加载失败', style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(error, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('重试', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
  if (isEmpty) {
    final msg = configured ? '暂无数据' : '请先在设置中配置同花顺 Key';
    return Center(child: Text(msg, style: TextStyle(color: AppColors.textSecondary)));
  }
  return child;
}

void _openChart(BuildContext context, String code) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChartScreen(stockCode: code)));
}

// ──────────── 连板天梯 ────────────
class _LadderTab extends StatefulWidget {
  final ThinksApi? ths;
  final bool configured;
  const _LadderTab({required this.ths, required this.configured});

  @override
  State<_LadderTab> createState() => _LadderTabState();
}

class _LadderTabState extends State<_LadderTab> {
  List<LadderDay> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = widget.ths == null ? <LadderDay>[] : await widget.ths!.getLimitUpLadder();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stateWidget(
      loading: _loading,
      error: _error,
      configured: widget.configured,
      onRetry: _load,
      isEmpty: _data.isEmpty,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final day = _data[i];
          // 按连板天数降序分组
          final groups = <int, List<LadderStock>>{};
          for (final s in day.stocks) {
            groups.putIfAbsent(s.boardNum, () => []).add(s);
          }
          final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.date, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...keys.map((k) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$k 连板', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: groups[k]!.map((s) => InkWell(
                                  onTap: () => _openChart(context, s.code),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Text(s.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                                  ),
                                )).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────── 异动 ────────────
class _AnomalyTab extends StatefulWidget {
  final ThinksApi? ths;
  final bool configured;
  const _AnomalyTab({required this.ths, required this.configured});

  @override
  State<_AnomalyTab> createState() => _AnomalyTabState();
}

class _AnomalyTabState extends State<_AnomalyTab> {
  List<AnomalyItem> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = widget.ths == null ? <AnomalyItem>[] : await widget.ths!.getAnomalyList();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stateWidget(
      loading: _loading,
      error: _error,
      configured: widget.configured,
      onRetry: _load,
      isEmpty: _data.isEmpty,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          return InkWell(
            onTap: () => _openChart(context, item.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.stockName, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(item.tagName, style: TextStyle(color: AppColors.primary, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.analysisContent, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (item.keywords.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: item.keywords.take(5).map((k) => Chip(
                            label: Text(k, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(color: AppColors.divider),
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────── 热股榜 / 飙升榜 ────────────
class _RankTab extends StatefulWidget {
  final ThinksApi? ths;
  final bool configured;
  final bool hot; // true=热股榜, false=飙升榜
  const _RankTab({required this.ths, required this.configured, required this.hot});

  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> {
  List<RankStockItem> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = widget.ths == null
          ? <RankStockItem>[]
          : (widget.hot ? await widget.ths!.getHotStockList() : await widget.ths!.getSkyrocketList());
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _stateWidget(
      loading: _loading,
      error: _error,
      configured: widget.configured,
      onRetry: _load,
      isEmpty: _data.isEmpty,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          final trendUp = item.rankChange > 0;
          return InkWell(
            onTap: () => _openChart(context, item.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5))),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('#${item.rank}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                  Expanded(child: Text(item.name, style: TextStyle(color: AppColors.textPrimary))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('热度 ${item.heat.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(
                        item.rankChange == 0 ? '—' : '${trendUp ? '↑' : '↓'}${item.rankChange.abs()}',
                        style: TextStyle(color: trendUp ? AppColors.up : AppColors.down, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
