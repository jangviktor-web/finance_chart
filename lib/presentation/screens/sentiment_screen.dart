import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/sentiment_api.dart';
import '../../data/models/sentiment_data.dart';
import 'chart_screen.dart';

/// 市场情绪页面 — 6 Tab
class SentimentScreen extends StatefulWidget {
  const SentimentScreen({super.key});

  @override
  State<SentimentScreen> createState() => _SentimentScreenState();
}

class _SentimentScreenState extends State<SentimentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = SentimentApi();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: const Text('市场情绪'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '涨停池'),
            Tab(text: '跌停池'),
            Tab(text: '龙虎榜'),
            Tab(text: '北向资金'),
            Tab(text: '融资融券'),
            Tab(text: '板块资金'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LimitPoolTab(api: _api, isUp: true),
          _LimitPoolTab(api: _api, isUp: false),
          _DragonTigerTab(api: _api),
          _NorthboundTab(api: _api),
          _MarginTab(api: _api),
          _SectorFlowTab(api: _api),
        ],
      ),
    );
  }
}

/// 涨停/跌停池 Tab
class _LimitPoolTab extends StatefulWidget {
  final SentimentApi api;
  final bool isUp;
  const _LimitPoolTab({required this.api, required this.isUp});

  @override
  State<_LimitPoolTab> createState() => _LimitPoolTabState();
}

class _LimitPoolTabState extends State<_LimitPoolTab> {
  List<LimitStock> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = widget.isUp
          ? await widget.api.getLimitUpPool()
          : await widget.api.getLimitDownPool();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);
    if (_data.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) => _buildLimitItem(_data[i]),
      ),
    );
  }

  Widget _buildLimitItem(LimitStock item) {
    final color = widget.isUp ? AppColors.up : AppColors.down;
    return InkWell(
      onTap: () => _openChart(item.code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(item.code.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(item.price.toStringAsFixed(2),
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text('${item.changePercent >= 0 ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right),
            ),
            if (item.openCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('开${item.openCount}',
                    style: TextStyle(color: AppColors.warning, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }

  void _openChart(String code) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChartScreen(stockCode: code),
    ));
  }
}

/// 龙虎榜 Tab
class _DragonTigerTab extends StatefulWidget {
  final SentimentApi api;
  const _DragonTigerTab({required this.api});

  @override
  State<_DragonTigerTab> createState() => _DragonTigerTabState();
}

class _DragonTigerTabState extends State<_DragonTigerTab> {
  List<DragonTigerItem> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.getDragonTiger();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);
    if (_data.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          final color = item.changePercent >= 0 ? AppColors.up : AppColors.down;
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChartScreen(stockCode: item.code))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(item.reason, style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${item.changePercent >= 0 ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('净买 ${_formatAmount(item.netBuy)}',
                            style: TextStyle(color: item.netBuy >= 0 ? AppColors.up : AppColors.down, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}亿';
    return '${v.toStringAsFixed(0)}万';
  }
}

/// 北向资金 Tab
class _NorthboundTab extends StatefulWidget {
  final SentimentApi api;
  const _NorthboundTab({required this.api});

  @override
  State<_NorthboundTab> createState() => _NorthboundTabState();
}

class _NorthboundTabState extends State<_NorthboundTab> {
  List<NorthboundHistory> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.getNorthboundHistory(days: 30);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);
    if (_data.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          final color = item.totalNet >= 0 ? AppColors.up : AppColors.down;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('${item.date.month}/${item.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                Expanded(child: Text('沪股通 ${item.shNet.toStringAsFixed(2)}亿',
                    style: TextStyle(color: item.shNet >= 0 ? AppColors.up : AppColors.down, fontSize: 12))),
                Expanded(child: Text('深股通 ${item.szNet.toStringAsFixed(2)}亿',
                    style: TextStyle(color: item.szNet >= 0 ? AppColors.up : AppColors.down, fontSize: 12))),
                SizedBox(
                  width: 80,
                  child: Text('${item.totalNet >= 0 ? '+' : ''}${item.totalNet.toStringAsFixed(2)}亿',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 融资融券 Tab
class _MarginTab extends StatefulWidget {
  final SentimentApi api;
  const _MarginTab({required this.api});

  @override
  State<_MarginTab> createState() => _MarginTabState();
}

class _MarginTabState extends State<_MarginTab> {
  List<MarginData> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.getMargin(days: 30);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);
    if (_data.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('${item.date.month}/${item.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('融资余额', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                    Text('${item.rzBalance.toStringAsFixed(0)}亿',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                )),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('融资买入', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                    Text('${item.rzBuy.toStringAsFixed(0)}亿',
                        style: TextStyle(color: AppColors.up, fontSize: 13)),
                  ],
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 板块资金流向 Tab
class _SectorFlowTab extends StatefulWidget {
  final SentimentApi api;
  const _SectorFlowTab({required this.api});

  @override
  State<_SectorFlowTab> createState() => _SectorFlowTabState();
}

class _SectorFlowTabState extends State<_SectorFlowTab> {
  List<SectorFlowData> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.getSectorFlow(limit: 30);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _load);
    if (_data.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (ctx, i) {
          final item = _data[i];
          final chgColor = item.changePercent >= 0 ? AppColors.up : AppColors.down;
          final flowColor = item.netInflow >= 0 ? AppColors.up : AppColors.down;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${item.changePercent >= 0 ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(color: chgColor, fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${item.netInflow >= 0 ? '+' : ''}${item.netInflow.toStringAsFixed(2)}亿',
                      style: TextStyle(color: flowColor, fontSize: 13),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 通用错误组件
class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.warning, size: 40),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error, style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center, maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
