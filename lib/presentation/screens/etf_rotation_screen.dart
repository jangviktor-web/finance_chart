import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';
import '../../core/utils/stock_code_utils.dart';
import '../../data/datasources/local/watchlist_storage.dart';
import '../../data/datasources/market_api.dart';
import '../../data/models/watchlist_group.dart';
import '../../domain/services/etf_strength.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/loading_skeleton.dart';

/// 「ETF 轮动」页：约 35 只 ETF 池中按「稳强度」打分取前三。
///
/// App 只算分展示，不做自动交易。池子持久化在 WatchlistGroup("ETF轮动池")。
class EtfRotationScreen extends StatefulWidget {
  const EtfRotationScreen({super.key});

  @override
  State<EtfRotationScreen> createState() => _EtfRotationScreenState();
}

class _EtfRotationScreenState extends State<EtfRotationScreen> {
  static const _groupName = 'ETF轮动池';
  static const _window = 22;

  /// 默认 35 只种子池（sh/sz 前缀，去重后恰好 35 个互不相同）。
  static const List<String> _defaultPool = [
    'sh510300', 'sh510500', 'sh510050', 'sz159915', 'sh588000',
    'sh510880', 'sh512880', 'sh512010', 'sh512660', 'sh515030',
    'sz159928', 'sh512690', 'sh159920', 'sh513050', 'sz159995',
    'sh512170', 'sh515790', 'sz159869', 'sh516160', 'sh512980',
    'sz159825', 'sh513180', 'sh512800', 'sh588080', 'sh512670',
    'sh513100', 'sz159901', 'sh512290', 'sh516970', 'sz159938',
    'sh512950', 'sz159740', 'sh561230', 'sh515250', 'sh512550',
  ];

  /// 默认 ETF 代码 → 名称（展示用，缺失时回退到代码本身）。
  static const Map<String, String> _etfNames = {
    'sh510300': '沪深300ETF', 'sh510500': '中证500ETF', 'sh510050': '上证50ETF',
    'sz159915': '创业板ETF', 'sh588000': '科创50ETF', 'sh510880': '红利ETF',
    'sh512880': '证券ETF', 'sh512010': '医药ETF', 'sh512660': '军工ETF',
    'sh515030': '新能源车ETF', 'sz159928': '消费ETF', 'sh512690': '酒ETF',
    'sh159920': '恒生ETF', 'sh513050': '中概互联网ETF', 'sz159995': '芯片ETF',
    'sh512170': '医疗ETF', 'sh515790': '光伏ETF', 'sz159869': '游戏ETF',
    'sh516160': '新能源ETF', 'sh512980': '传媒ETF', 'sz159825': '农业ETF',
    'sh513180': '恒生科技ETF', 'sh512800': '银行ETF', 'sh588080': '科创50ETF',
    'sh512670': '国防ETF', 'sh513100': '纳指ETF', 'sz159901': '深证100ETF',
    'sh512290': '生物医药ETF', 'sh516970': '基建ETF', 'sz159938': '医药ETF',
    'sh512950': '央企ETF', 'sz159740': '恒生科技ETF', 'sh561230': '中证A50ETF',
    'sh515250': '智能汽车ETF', 'sh512550': '沪深300ETF',
  };

  List<String> _poolCodes = [];
  List<EtfStrengthResult> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _nameOf(String code) => _etfNames[code] ?? code;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. 读取池子（首次启动种子化默认 35 只）
      final storage = WatchlistStorage();
      var groups = await storage.loadGroups();
      WatchlistGroup? pool = _findPool(groups);

      if (pool == null) {
        pool = WatchlistGroup(
          id: const Uuid().v4(),
          name: _groupName,
          codes: _defaultPool,
          sortOrder: groups.length,
        );
        groups = [...groups, pool];
        await storage.saveGroups(groups);
      }

      // 去重并保持顺序
      final seen = <String>{};
      _poolCodes = pool.codes
          .where((c) => c.isNotEmpty && seen.add(StockCodeUtils.format(c)))
          .map((c) => StockCodeUtils.format(c))
          .toList();

      // 2. 批量拉取 K 线（复用 market_scanner 范式：batchSize=3 + 批间 300ms + Future.wait）
      final api = MarketApi();
      final inputs = <EtfStrengthInput>[];
      const batchSize = 3;
      final total = _poolCodes.length;

      for (int i = 0; i < total; i += batchSize) {
        if (!mounted) return;
        final batch = _poolCodes.skip(i).take(batchSize).toList();
        final futures = batch.map((code) async {
          try {
            final klines = await api.getKline(
              code: code,
              period: 'day',
              count: _window + 5,
            );
            return EtfStrengthInput(
              code: code,
              name: _nameOf(code),
              klines: klines,
            );
          } catch (_) {
            // 单只失败不影响其它：返回空行情，评分层会标记为「无行情数据」
            return EtfStrengthInput(
              code: code,
              name: _nameOf(code),
              klines: const [],
            );
          }
        });

        final batchResults = await Future.wait(futures);
        inputs.addAll(batchResults);

        if (i + batchSize < total) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // 3. 算分排名
      final results = EtfRotation.rank(inputs, window: _window);

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  WatchlistGroup? _findPool(List<WatchlistGroup> groups) {
    for (final g in groups) {
      if (g.name == _groupName) return g;
    }
    return null;
  }

  Future<void> _savePool(List<String> codes) async {
    final storage = WatchlistStorage();
    final groups = await storage.loadGroups();
    final idx = groups.indexWhere((g) => g.name == _groupName);
    if (idx < 0) return;
    groups[idx] = groups[idx].copyWith(codes: codes);
    await storage.saveGroups(groups);
  }

  Future<void> _addCode(String raw) async {
    final formatted = StockCodeUtils.format(raw);
    // 校验 sh/sz 前缀或裸 6 位（归一后必须以 sh/sz 开头）
    if (!formatted.startsWith('sh') && !formatted.startsWith('sz')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('请输入 sh/sz 前缀或 6 位代码'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    if (_poolCodes.contains(formatted)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('已在轮动池中'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    _poolCodes = [..._poolCodes, formatted];
    await _savePool(_poolCodes);
    await _load();
  }

  Future<void> _removeCode(String code) async {
    _poolCodes = _poolCodes.where((c) => c != code).toList();
    await _savePool(_poolCodes);
    await _load();
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('添加 ETF', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '如 sh510300 或 510300',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addCode(controller.text.trim());
            },
            child: Text('添加', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('移除 ETF', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('确认从轮动池移除 $code ？', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeCode(code);
            },
            child: Text('移除', style: TextStyle(color: AppColors.down)),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return AppColors.up;
    if (score >= 40) return AppColors.warning;
    return AppColors.down;
  }

  Color _rankAccent(int rank) {
    switch (rank) {
      case 1: return AppColors.up;
      case 2: return const Color(0xFFFF6D00);
      case 3: return const Color(0xFFFFA000);
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ETF 轮动'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新算分',
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '编辑池子',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          ..._results.map((r) => _buildRow(r)),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final top3 = _results.where((r) => !r.disqualified).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('买入候选（前三）', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (top3.isEmpty)
            Text('暂无符合条件的 ETF', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            Text(
              top3.map((r) => '${r.name}(${r.code})').join('  ·  '),
              style: TextStyle(color: AppColors.up, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(EtfStrengthResult r) {
    final isTop3 = !r.disqualified && r.rank <= 3;
    return GestureDetector(
      onLongPress: () => _showRemoveDialog(r.code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isTop3
              ? Border.all(color: _rankAccent(r.rank).withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Opacity(
          opacity: r.disqualified ? 0.5 : 1.0,
          child: Row(
            children: [
              // 排名徽标
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: r.disqualified ? AppColors.divider : _rankAccent(r.rank).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  r.disqualified ? '–' : '${r.rank}',
                  style: TextStyle(
                    color: r.disqualified ? AppColors.textSecondary : _rankAccent(r.rank),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 代码/名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.name,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        ),
                        if (isTop3) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _rankAccent(r.rank).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('持有候选',
                              style: TextStyle(color: _rankAccent(r.rank), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(r.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    if (r.disqualified) ...[
                      const SizedBox(height: 2),
                      Text(r.reason, style: TextStyle(color: AppColors.down, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 分数条 + 数值
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.disqualified ? '0' : r.score.toStringAsFixed(1),
                      style: TextStyle(
                        color: r.disqualified ? AppColors.textSecondary : _scoreColor(r.score),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: r.disqualified ? 0 : r.score / 100,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation(
                          r.disqualified ? AppColors.textSecondary : _scoreColor(r.score),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A ${r.a.toStringAsFixed(0)}  B ${r.b.toStringAsFixed(0)}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(8, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const LoadingSkeleton(width: 28, height: 28, borderRadius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    LoadingSkeleton(height: 14, width: 120),
                    SizedBox(height: 6),
                    LoadingSkeleton(height: 10, width: 80),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const LoadingSkeleton(width: 60, height: 16),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '稳强度 = 0.7×风险调整收益 + 0.3×上涨天数占比。近3日曾单日跌超5%或短期涨幅过猛者剔除。'
        '仅作分析展示，不构成投资建议。长按条目可移除。',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}
