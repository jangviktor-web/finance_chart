import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/fund_flow_api.dart';
import '../../data/datasources/sentiment_api.dart';
import '../../data/models/sentiment_data.dart';
import 'chart_screen.dart';

/// 资金流向页面 — 3 Tab
class FundFlowScreen extends StatefulWidget {
  const FundFlowScreen({super.key});

  @override
  State<FundFlowScreen> createState() => _FundFlowScreenState();
}

class _FundFlowScreenState extends State<FundFlowScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fundApi = FundFlowApi();
  final _sentApi = SentimentApi();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('资金流向'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '主力资金'),
            Tab(text: '板块资金'),
            Tab(text: '北向资金'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MainForceTab(api: _fundApi),
          _SectorFlowTab(api: _sentApi),
          _NorthboundTab(api: _sentApi),
        ],
      ),
    );
  }
}

// ═══════════════ 主力资金 Tab ═══════════════

class _MainForceTab extends StatefulWidget {
  final FundFlowApi api;
  const _MainForceTab({required this.api});

  @override
  State<_MainForceTab> createState() => _MainForceTabState();
}

class _MainForceTabState extends State<_MainForceTab> {
  MarketFundFlow? _marketFlow;
  List<FundFlowRankItem> _rankData = [];
  bool _loading = true;
  String _period = 'today';

  static const _periods = {'today': '今日', '3day': '3日', '5day': '5日', '10day': '10日'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getMarketFundFlow(),
        widget.api.getFundFlowRank(period: _period, limit: 30),
      ]);
      if (mounted) {
        setState(() {
          _marketFlow = results[0] as MarketFundFlow;
          _rankData = results[1] as List<FundFlowRankItem>;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changePeriod(String p) {
    setState(() => _period = p);
    _loadRank();
  }

  Future<void> _loadRank() async {
    try {
      final data = await widget.api.getFundFlowRank(period: _period, limit: 30);
      if (mounted) setState(() => _rankData = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _marketFlow == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMarketSnapshot(),
          const SizedBox(height: 16),
          _buildPeriodSelector(),
          const SizedBox(height: 8),
          _buildRankList(),
        ],
      ),
    );
  }

  Widget _buildMarketSnapshot() {
    final m = _marketFlow;
    if (m == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('大盘实时资金流', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFlowItem('主力净流入', m.mainNet, m.mainPercent),
              _buildFlowItem('超大单', m.superLargeNet, null),
              _buildFlowItem('大单', m.largeNet, null),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFlowItem('中单', m.mediumNet, null),
              _buildFlowItem('小单', m.smallNet, null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowItem(String label, double value, double? percent) {
    final color = value >= 0 ? AppColors.up : AppColors.down;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(_formatAmount(value), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            if (percent != null)
              Text('${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
                style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: _periods.entries.map((e) {
        final selected = e.key == _period;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(e.value, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            onSelected: (_) => _changePeriod(e.key),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRankList() {
    if (_rankData.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('全市场主力净流入排行', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          // 表头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 50, child: Text('代码', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                SizedBox(width: 60, child: Text('名称', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                Expanded(child: Text('主力净流入', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
                SizedBox(width: 60, child: Text('涨跌幅', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          ...List.generate(_rankData.length, (i) {
            final item = _rankData[i];
            final mainColor = item.mainNet >= 0 ? AppColors.up : AppColors.down;
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChartScreen(stockCode: item.code))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text(item.code.replaceAll(RegExp(r'^(sh|sz)'), ''), style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                    SizedBox(width: 60, child: Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Expanded(child: Text(_formatAmount(item.mainNet), style: TextStyle(color: mainColor, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    SizedBox(
                      width: 60,
                      child: Text('${item.changePercent >= 0 ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: item.changePercent >= 0 ? AppColors.up : AppColors.down, fontSize: 11),
                        textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 1e8) return '${(value / 1e8).toStringAsFixed(2)}亿';
    if (abs >= 1e4) return '${(value / 1e4).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }
}

// ═══════════════ 板块资金 Tab ═══════════════

class _SectorFlowTab extends StatefulWidget {
  final SentimentApi api;
  const _SectorFlowTab({required this.api});

  @override
  State<_SectorFlowTab> createState() => _SectorFlowTabState();
}

class _SectorFlowTabState extends State<_SectorFlowTab> {
  List<SectorFlowData> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.getSectorFlow(limit: 30);
      if (mounted) setState(() => _data = data);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _data.length,
        itemBuilder: (_, i) => _buildItem(_data[i], i + 1),
      ),
    );
  }

  Widget _buildItem(SectorFlowData item, int rank) {
    final flowColor = item.netInflow >= 0 ? AppColors.up : AppColors.down;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: TextStyle(color: rank <= 3 ? AppColors.primary : AppColors.textSecondary, fontSize: 12, fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('领涨: ${item.leaderName} ${item.leaderChange >= 0 ? '+' : ''}${item.leaderChange.toStringAsFixed(2)}%',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatAmount(item.netInflow), style: TextStyle(color: flowColor, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward, size: 10, color: AppColors.up),
                  Text('${item.upCount}', style: TextStyle(color: AppColors.up, fontSize: 10)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_downward, size: 10, color: AppColors.down),
                  Text('${item.downCount}', style: TextStyle(color: AppColors.down, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 1e8) return '${(value / 1e8).toStringAsFixed(2)}亿';
    if (abs >= 1e4) return '${(value / 1e4).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }
}

// ═══════════════ 北向资金 Tab ═══════════════

class _NorthboundTab extends StatefulWidget {
  final SentimentApi api;
  const _NorthboundTab({required this.api});

  @override
  State<_NorthboundTab> createState() => _NorthboundTabState();
}

class _NorthboundTabState extends State<_NorthboundTab> {
  List<NorthboundData> _realtime = [];
  List<NorthboundHistory> _history = [];
  List<NorthboundBoardRank> _boardRank = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getNorthboundRealtime(),
        widget.api.getNorthboundHistory(days: 20),
        widget.api.getNorthboundBoardRank(limit: 15),
      ]);
      if (mounted) {
        setState(() {
          _realtime = results[0] as List<NorthboundData>;
          _history = results[1] as List<NorthboundHistory>;
          _boardRank = results[2] as List<NorthboundBoardRank>;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _history.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 实时快照
          if (_realtime.isNotEmpty) _buildRealtimeCard(),
          // 历史趋势
          if (_history.isNotEmpty) _buildHistoryCard(),
          // 板块排名
          if (_boardRank.isNotEmpty) _buildBoardRank(),
        ],
      ),
    );
  }

  Widget _buildRealtimeCard() {
    final latest = _realtime.last;
    final color = latest.netBuy >= 0 ? AppColors.up : AppColors.down;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日北向资金', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_formatAmount(latest.netBuy), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('时间: ${latest.time}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('近 20 日净买入', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HistoryBarPainter(data: _history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardRank() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('北向板块持仓排名', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          ...List.generate(_boardRank.length, (i) {
            final item = _boardRank[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('${i + 1}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                  Expanded(child: Text(item.boardName, style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                  SizedBox(
                    width: 80,
                    child: Text(_formatAmount(item.holdMarketValue), style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text('${item.netBuy >= 0 ? '+' : ''}${_formatAmount(item.netBuy)}',
                      style: TextStyle(color: item.netBuy >= 0 ? AppColors.up : AppColors.down, fontSize: 11),
                      textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 1e8) return '${(value / 1e8).toStringAsFixed(2)}亿';
    if (abs >= 1e4) return '${(value / 1e4).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }
}

/// 历史柱状图 Painter
class _HistoryBarPainter extends CustomPainter {
  final List<NorthboundHistory> data;
  _HistoryBarPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final barWidth = (size.width - 20) / data.length * 0.7;
    final spacing = (size.width - 20) / data.length;

    // 找最大绝对值
    double maxAbs = 0;
    for (final d in data) {
      final v = d.totalNet.abs();
      if (v > maxAbs) maxAbs = v;
    }
    if (maxAbs == 0) return;

    final midY = size.height / 2;
    final scaleY = (size.height / 2 - 10) / maxAbs;

    // 零线
    final linePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);

    for (int i = 0; i < data.length; i++) {
      final value = data[i].totalNet;
      final x = 10 + i * spacing + spacing * 0.15;
      final barHeight = value.abs() * scaleY;
      final color = value >= 0 ? AppColors.up : AppColors.down;

      final rect = value >= 0
          ? Rect.fromLTWH(x, midY - barHeight, barWidth, barHeight)
          : Rect.fromLTWH(x, midY, barWidth, barHeight);
      canvas.drawRect(rect, Paint()..color = color.withOpacity(0.8));
    }
  }

  @override
  bool shouldRepaint(_HistoryBarPainter old) => !identical(data, old.data);
}
