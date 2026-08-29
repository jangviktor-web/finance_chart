import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/stock_info_api.dart';
import '../../data/models/stock_info_data.dart';
import '../../data/models/financial_data.dart';
import '../../data/models/auction_data.dart';
import '../../presentation/providers/market_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/screens/settings_screen.dart';

/// 个股深度数据页面
class StockDetailScreen extends ConsumerStatefulWidget {
  final String stockCode;
  final String stockName;

  const StockDetailScreen({super.key, required this.stockCode, this.stockName = ''});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  final _api = StockInfoApi();

  ValuationData? _valuation;
  List<ShareholderData> _shareholders = [];
  List<BlockTrade> _blockTrades = [];
  List<RestrictedShare> _restricted = [];
  bool _loading = true;
  String? _error;

  // ── 财务三表（同花顺 BYOK）──
  FinancialStatement? _income;
  FinancialStatement? _balance;
  FinancialStatement? _cashflow;
  List<FinancialIndicatorGroup>? _indicators;
  bool _finLoading = false;
  String? _finError;
  String _finType = 'income'; // income | balance | cashflow | indicators
  int _indicatorYear = DateTime.now().year - 1;

  // ── 集合竞价（同花顺 BYOK）──
  AuctionSnapshot? _auction;
  bool _auctionLoading = false;
  String? _auctionError;
  String _auctionStage = 'final'; // live | final

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getValuation(widget.stockCode),
        _api.getShareholders(widget.stockCode, limit: 8),
        _api.getBlockTrades(widget.stockCode, limit: 10),
        _api.getRestrictedShares(widget.stockCode, limit: 5),
      ]);

      if (mounted) {
        setState(() {
          _valuation = results[0] as ValuationData;
          _shareholders = results[1] as List<ShareholderData>;
          _blockTrades = results[2] as List<BlockTrade>;
          _restricted = results[3] as List<RestrictedShare>;
          _loading = false;
        });
      }
      // 财务三表与个股主数据解耦：即使失败也不影响主页面
      unawaited(_loadFinancials());
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// 加载同花顺财务三表 + 指标（需用户配置 Key；未配置给出引导）
  Future<void> _loadFinancials() async {
    if (!mounted) return;
    // 未配置 Key：直接给出引导，不再发请求
    final hasKey = ref.read(settingsProvider).thinksApiKey.isNotEmpty;
    if (!hasKey) {
      if (mounted) setState(() { _finLoading = false; _finError = '未配置同花顺 API Key'; });
      return;
    }
    if (mounted) setState(() { _finLoading = true; _finError = null; });
    try {
      final api = ref.read(marketApiProvider);
      final code = widget.stockCode;
      // 三表各自独立容错，单表缺失不影响其余
      final inc = await api.getFinancials(code, 'income').catchError((_) => FinancialStatement([]));
      final bal = await api.getFinancials(code, 'balance').catchError((_) => FinancialStatement([]));
      final cf = await api.getFinancials(code, 'cashflow').catchError((_) => FinancialStatement([]));
      if (mounted) {
        setState(() {
          _income = inc;
          _balance = bal;
          _cashflow = cf;
          _finLoading = false;
        });
      }
      unawaited(_loadIndicators());
      unawaited(_loadAuction());
    } catch (e) {
      if (mounted) setState(() { _finError = e.toString(); _finLoading = false; });
    }
  }

  /// 加载集合竞价快照（与三表同生命周期；单只标的失败不影响其余）
  Future<void> _loadAuction() async {
    try {
      final api = ref.read(marketApiProvider);
      final data = await api.getAuctionSnapshot(widget.stockCode, stage: _auctionStage);
      if (mounted) setState(() => _auction = data);
    } catch (e) {
      if (mounted) setState(() => _auctionError = e.toString());
    }
  }

  /// 加载指定年报期的财务指标（单报告期五类）
  Future<void> _loadIndicators() async {
    try {
      final api = ref.read(marketApiProvider);
      final data = await api.getFinancialIndicators(widget.stockCode, '$_indicatorYear-4');
      if (mounted) setState(() => _indicators = data);
    } catch (_) {
      // 指标失败不阻塞三表展示
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.stockName.isNotEmpty ? '${widget.stockName} 详情' : '个股详情'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildValuationCard(),
                      const SizedBox(height: 12),
                      _buildShareholderCard(),
                      const SizedBox(height: 12),
                      _buildBlockTradeCard(),
                      const SizedBox(height: 12),
                      _buildRestrictedCard(),
                      const SizedBox(height: 12),
                      _buildAuctionCard(),
                      const SizedBox(height: 12),
                      _buildFinancialCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: AppColors.warning, size: 48),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('重试', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildValuationCard() {
    final v = _valuation;
    if (v == null) return const SizedBox.shrink();

    return _card(
      '估值数据',
      Icons.assessment,
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _valItem('市盈率(PE)', v.pe.toStringAsFixed(2)),
          _valItem('市净率(PB)', v.pb.toStringAsFixed(2)),
          _valItem('总市值', '${v.totalMarketCap.toStringAsFixed(0)}亿'),
          _valItem('流通市值', '${v.circulatingCap.toStringAsFixed(0)}亿'),
        ],
      ),
    );
  }

  Widget _valItem(String label, String value) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildShareholderCard() {
    if (_shareholders.isEmpty) return const SizedBox.shrink();

    return _card(
      '股东人数变化',
      Icons.people,
      Column(
        children: _shareholders.map((s) {
          final changeColor = s.changePercent > 0 ? AppColors.up : (s.changePercent < 0 ? AppColors.down : AppColors.textSecondary);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(s.date, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Expanded(child: Text('${_formatCount(s.holderCount)}人',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                Text('${s.changePercent >= 0 ? '+' : ''}${s.changePercent.toStringAsFixed(1)}%',
                    style: TextStyle(color: changeColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockTradeCard() {
    if (_blockTrades.isEmpty) return const SizedBox.shrink();

    return _card(
      '大宗交易',
      Icons.swap_horiz,
      Column(
        children: _blockTrades.take(8).map((t) {
          final premiumColor = t.premiumRate > 0 ? AppColors.up : (t.premiumRate < 0 ? AppColors.down : AppColors.textSecondary);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text('${t.date.month}/${t.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                SizedBox(width: 60, child: Text(t.price.toStringAsFixed(2),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                Expanded(child: Text('${t.amount.toStringAsFixed(0)}万',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                Text('${t.premiumRate >= 0 ? '+' : ''}${t.premiumRate.toStringAsFixed(1)}%',
                    style: TextStyle(color: premiumColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestrictedCard() {
    if (_restricted.isEmpty) return const SizedBox.shrink();

    return _card(
      '限售解禁',
      Icons.lock_open,
      Column(
        children: _restricted.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('${r.date.year}/${r.date.month}/${r.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Expanded(child: Text('${r.amount.toStringAsFixed(1)}亿',
                    style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold))),
                Text(r.type, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──────────── 集合竞价（同花顺 BYOK）────────────

  Widget _buildAuctionCard() {
    // 未配置 Key 时由「财务三表」卡片统一提示，避免重复
    if (_finError != null && _finError!.contains('未配置')) {
      return const SizedBox.shrink();
    }
    return _card(
      '集合竞价（同花顺）',
      Icons.gavel,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stageChip('final', '竞价终态'),
              const SizedBox(width: 6),
              _stageChip('live', '竞价实时'),
            ],
          ),
          const SizedBox(height: 10),
          if (_auctionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (_auction == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _auctionError != null ? '集合竞价数据加载失败' : '暂无集合竞价数据（仅 A 股，非竞价时段可能未就绪）',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else
            _buildAuctionBody(),
        ],
      ),
    );
  }

  Widget _stageChip(String stage, String label) {
    final selected = _auctionStage == stage;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        if (_auctionStage == stage) return;
        setState(() {
          _auctionStage = stage;
          _auctionLoading = true;
          _auction = null;
        });
        unawaited(_loadAuction());
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAuctionBody() {
    final a = _auction!;
    // 竞价涨跌幅染色（红涨绿跌，遵循 A 股习惯）
    final pctColor = a.auctionPct == null
        ? AppColors.textSecondary
        : (a.auctionPct! >= 0 ? AppColors.up : AppColors.down);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              a.auctionPrice == null ? '--' : a.auctionPrice!.toStringAsFixed(2),
              style: TextStyle(color: pctColor, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Text(
              a.auctionPct == null ? '' : '${a.auctionPct! >= 0 ? '+' : ''}${a.auctionPct!.toStringAsFixed(2)}%',
              style: TextStyle(color: pctColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (a.dataStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text('状态：${_statusText(a.dataStatus!)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          )
        else
          const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _auctItem('竞价成交量', a.auctionVolume == null ? '--' : '${_fmtHand(a.auctionVolume!)} 手'),
            _auctItem('竞价成交额', a.auctionAmount == null ? '--' : _fmtMoney(a.auctionAmount!)),
            _auctItem('未匹配量', a.auctionUnmatched == null ? '--' : '${_fmtHand(a.auctionUnmatched!)} 手'),
            _auctItem('竞价换手率', a.auctionTurnoverPct == null ? '--' : '${a.auctionTurnoverPct!.toStringAsFixed(2)}%'),
            _auctItem('竞价量比', a.auctionVolumeRatio == null ? '--' : a.auctionVolumeRatio!.toStringAsFixed(2)),
            _auctItem('相对昨日量', a.auctionYesterdayRatioPct == null ? '--' : '${a.auctionYesterdayRatioPct!.toStringAsFixed(2)}%'),
            _auctItem('昨收', a.preClosePrice == null ? '--' : a.preClosePrice!.toStringAsFixed(2)),
            _auctItem('开盘', a.openPrice == null ? '--' : a.openPrice!.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }

  Widget _auctItem(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _statusText(String s) {
    switch (s) {
      case 'ready':
        return '竞价就绪';
      case 'final':
        return '竞价终态';
      case 'suspended':
        return '停牌';
      case 'not_ready':
        return '未就绪';
      default:
        return s;
    }
  }

  // ──────────── 财务三表（同花顺 BYOK）────────────

  Widget _buildFinancialCard() {
    return _card(
      '财务三表（同花顺）',
      Icons.account_balance,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_finLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (_finError != null)
            _buildFinError()
          else ...[
            _buildFinTabs(),
            const SizedBox(height: 10),
            _buildFinContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildFinError() {
    final noKey = _finError!.contains('未配置');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(noKey ? Icons.vpn_key : Icons.cloud_off, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  noKey ? '未配置同花顺 API Key，财务数据不可用' : '财务数据加载失败',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          noKey
              ? ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('去设置页填入 Key', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                )
              : ElevatedButton(
                  onPressed: _loadFinancials,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('重试', style: TextStyle(color: Colors.white)),
                ),
        ],
      ),
    );
  }

  Widget _buildFinTabs() {
    final tabs = [
      ('income', '利润表'),
      ('balance', '资产负债表'),
      ('cashflow', '现金流量表'),
      ('indicators', '财务指标'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tabs.map((t) {
        final selected = _finType == t.$1;
        return ChoiceChip(
          label: Text(t.$2),
          selected: selected,
          onSelected: (_) => setState(() => _finType = t.$1),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildFinContent() {
    switch (_finType) {
      case 'income':
        return _buildStatementTable(_income, kIncomeLabels);
      case 'balance':
        return _buildStatementTable(_balance, kBalanceLabels);
      case 'cashflow':
        return _buildStatementTable(_cashflow, kCashFlowLabels);
      case 'indicators':
        return _buildIndicatorsView();
      default:
        return const SizedBox.shrink();
    }
  }

  /// 多期报表表：首列=项目名，其后每列=一个报告期（最新在前）
  Widget _buildStatementTable(FinancialStatement? stmt, Map<String, String> labels) {
    if (stmt == null || stmt.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }
    final periods = stmt.periods;
    final rows = <TableRow>[];

    // 表头：项目 + 各报告期
    rows.add(TableRow(
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08)),
      children: [
        _finCell('项目', isHeader: true, align: Alignment.centerLeft),
        for (final p in periods) _finCell(p.label, isHeader: true),
      ],
    ));

    // 仅展示至少一期有值的行，避免空行
    labels.forEach((field, cn) {
      final any = periods.any((p) => p[field] != null);
      if (!any) return;
      rows.add(TableRow(
        children: [
          _finCell(cn, align: Alignment.centerLeft),
          for (final p in periods) _finCell(_fmtMoney(p[field])),
        ],
      ));
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: AppColors.textSecondary.withOpacity(0.15)),
        children: rows,
      ),
    );
  }

  Widget _finCell(String text, {bool isHeader = false, Alignment align = Alignment.centerRight}) {
    return Container(
      width: isHeader && align == Alignment.centerLeft ? 130 : 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: align,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isHeader ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// 金额格式化：元 → 亿/万（未披露返回 '--'）
  String _fmtMoney(double? v) {
    if (v == null) return '--';
    final a = v.abs();
    if (a >= 1e8) return '${(v / 1e8).toStringAsFixed(2)}亿';
    if (a >= 1e4) return '${(v / 1e4).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }

  /// 手数格式化（1 手 = 100 股）
  String _fmtHand(double v) {
    if (v.abs() >= 1e4) return '${(v / 1e4).toStringAsFixed(2)}万';
    return v.toStringAsFixed(0);
  }

  /// 财务指标视图：年报期选择 + 五类指标分组
  Widget _buildIndicatorsView() {
    if (_indicators == null || _indicators!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('暂无指标数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }
    final yr = DateTime.now().year;
    final years = [yr - 2, yr - 1, yr];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('报告期', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            DropdownButton<int>(
              value: _indicatorYear,
              underline: const SizedBox.shrink(),
              items: years
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y 年报', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (y) {
                if (y == null) return;
                setState(() => _indicatorYear = y);
                _loadIndicators();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final g in _indicators!)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(g.abilityName,
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              for (final it in g.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(it.name,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                      Text(
                        it.value == null ? '--' : it.value!.toStringAsFixed(2),
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
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
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count.toString();
  }
}
