import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';
import '../../core/utils/stock_code_utils.dart';
import '../../data/datasources/local/etf_rotation_snapshot_storage.dart';
import '../../data/datasources/local/watchlist_storage.dart';
import '../../data/datasources/market_api.dart';
import '../../data/models/watchlist_group.dart';
import '../../domain/services/etf_strength.dart';
import 'chart_screen.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/loading_skeleton.dart';

/// 「ETF 轮动」页：33 只固定 ETF 池中按「稳强度」打分排名，再经两道筛取前三为买入候选。
///
/// 口径见 [EtfRotation]（《ETF 轮动 · App 对齐规格 v2》2026-09-18）。
/// App 只算分展示，不做自动交易。池子持久化在 WatchlistGroup("ETF轮动池")。
class EtfRotationScreen extends StatefulWidget {
  const EtfRotationScreen({super.key});

  @override
  State<EtfRotationScreen> createState() => _EtfRotationScreenState();
}

class _EtfRotationScreenState extends State<EtfRotationScreen> {
  static const _groupName = 'ETF轮动池';

  /// 回望窗口：规格二节的 20 个交易日（引用服务端常量，避免两处漂移）。
  static const _window = EtfRotation.defaultWindow;

  /// 买入候选数量（前三），同时是调仓提示的对比宽度。
  static const _topN = EtfRotation.defaultTopN;

  /// K 线请求根数。需同时满足：ret20 要 21 根、MA20 要 20 根、**MA28 要 28 根**，
  /// 外加「盘中丢弃当日未收盘 bar」的 1 根余量；规格五节也要求每只 ≥35 根。
  static const int _klineBars = 45;

  List<String> _poolCodes = [];
  List<EtfStrengthResult> _results = [];
  EtfRotationDiff? _diff; // 与上次快照的上榜/出榜对比（null = 尚未计算出）
  bool _suggestCash = false; // 全池无一只同时过两道筛 → 全弱空仓
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _nameOf(String code) => etfRotationDefaultNames[code] ?? code;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. 读取池子；不存在则种子化。若存量池「用户从未改过」且与当前默认池不一致，
      //    说明代码里的默认池已换代 → 覆盖为新默认池。
      //    ⚠️ 不迁移的老用户会一直用旧池：既拿不到新池的优化，旧代码也不在内置
      //    名称表里 → 界面只能显示裸代码（正是「ETF 名称没显示」的真实成因）。
      final storage = WatchlistStorage();
      var groups = await storage.loadGroups();
      WatchlistGroup? pool = _findPool(groups);
      final state = EtfRotationSnapshotStorage();
      final customized = await state.isPoolCustomized();

      final needSeed = pool == null ||
          shouldReseedEtfPool(
            stored: pool.codes,
            currentDefault: etfRotationDefaultPool,
            customized: customized,
          );
      if (needSeed) {
        final rebuilt = WatchlistGroup(
          id: pool?.id ?? const Uuid().v4(),
          name: _groupName,
          codes: etfRotationDefaultPool,
          sortOrder: pool?.sortOrder ?? groups.length,
        );
        groups = pool == null
            ? [...groups, rebuilt]
            : [for (final g in groups) if (g.name == _groupName) rebuilt else g];
        pool = rebuilt;
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
            final raw = await api.getKline(
              code: code,
              period: 'day',
              count: _klineBars,
            );
            // 规格五节 2：15:00 前丢弃当日未收盘的半根 K 线（否则污染 ret20 与近3日红线）
            return EtfStrengthInput(
              code: code,
              name: _nameOf(code),
              klines: EtfRotation.dropTodayBar(raw),
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

      // 4. 算分排名（全量有效标的照常排名，规格四节）
      final results = EtfRotation.rank(inputs, window: _window);
      final candidates = EtfRotation.buyCandidates(results, topN: _topN);

      // 5. 调仓提示：以上次**买入候选**为基准做 diff，再把本次候选写回
      final lastTop = await state.loadLastTop();
      final currentTop = candidates.map((r) => r.code).toList();
      final diff = EtfRotation.diffTopN(current: currentTop, previous: lastTop);
      if (currentTop.isNotEmpty) {
        await state.saveLastTop(currentTop);
      }

      // 6. 全弱空仓判定（规格四节：全池无一只同时过两道筛）
      final suggestCash = EtfRotation.suggestCash(results);

      if (!mounted) return;
      setState(() {
        _results = results;
        _diff = diff;
        _suggestCash = suggestCash;
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
    // 用户动过池子 → 此后默认池换代不再覆盖他的选择
    await EtfRotationSnapshotStorage().markPoolCustomized();
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

  /// 点按条目 → 该 ETF 的 K 线详情页（与全站其它列表的目的地一致）。
  void _openDetail(String code) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChartScreen(stockCode: code)),
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

  /// 稳强度是「20 日涨幅 ÷ 波动率」的比值（不是 0–100 归一化分）。
  /// 阈值取经验档位：≈4.8 是「区间涨 ~4.8% 且日波动 ~1%」这一量级（2026-09-18 头部实测）；
  /// 故 ≥3 记绿、≥1 记橙、其余记红。
  Color _scoreColor(double score) {
    if (score >= 3) return AppColors.up;
    if (score >= 1) return AppColors.warning;
    return AppColors.down;
  }

  /// 池内最高分，用于把比值归一化到进度条（0–1）。
  double _maxScore() {
    final qualified = _results.where((r) => !r.disqualified);
    if (qualified.isEmpty) return 0.0;
    return qualified.map((r) => r.score).reduce(math.max);
  }

  Color _rankAccent(int rank) {
    switch (rank) {
      case 1: return AppColors.up;
      case 2: return AppColors.rank2;
      case 3: return AppColors.rank3;
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
    final maxScore = _maxScore();
    final candidateCodes =
        EtfRotation.candidateCodes(_results, topN: _topN).toSet();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          ..._results.map((r) => _buildRow(r, maxScore, candidateCodes)),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final candidates = EtfRotation.buyCandidates(_results, topN: _topN);
    final diff = _diff;
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
          if (_suggestCash) ...[
            Text('⛔ 全弱空仓信号',
                style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('全池 ${_poolCodes.length} 只无一只同时站上 MA28 且 20 日涨幅为正，建议空仓等待。',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ] else if (candidates.isEmpty)
            Text('暂无符合条件的 ETF', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else ...[
            Text(
              candidates.map((r) => '${r.name}(${r.code})').join('  ·  '),
              style: TextStyle(color: AppColors.up, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '两道筛：现价 ≥ MA28 且 20 日涨幅 > 0',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],

          // 调仓提示：与上次快照对比（规格五节 3「不留恋」的操作抓手）
          if (diff != null) ...[
            const SizedBox(height: 8),
            if (!diff.hasBaseline)
              Text('首次运行，已记录本次候选作为下次对比基准。',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11))
            else if (diff.isEmpty)
              Text('较上次候选无变化，无需调仓', style: TextStyle(color: AppColors.textSecondary, fontSize: 11))
            else
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (diff.entered.isNotEmpty)
                    Text('🔄 新上榜：${diff.entered.map(_nameOf).join('、')}',
                        style: TextStyle(color: AppColors.up, fontSize: 12)),
                  if (diff.exited.isNotEmpty)
                    Text('⤵ 出榜：${diff.exited.map(_nameOf).join('、')}',
                        style: TextStyle(color: AppColors.down, fontSize: 12)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(EtfStrengthResult r, double maxScore, Set<String> candidateCodes) {
    // 候选 = 「过两道筛」且「按分降序排进前 N」；仅用 rank<=N 会把跌破 MA28 的也算进来。
    final isCandidate = candidateCodes.contains(r.code);
    final accent = isCandidate ? _rankAccent(r.rank) : AppColors.textSecondary;
    return GestureDetector(
      onTap: () => _openDetail(r.code),
      onLongPress: () => _showRemoveDialog(r.code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isCandidate
              ? Border.all(color: accent.withValues(alpha: 0.6), width: 1.5)
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
                  color: r.disqualified ? AppColors.divider : accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  r.disqualified ? '–' : '${r.rank}',
                  style: TextStyle(
                    color: r.disqualified ? AppColors.textSecondary : accent,
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
                        if (isCandidate) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('持有候选',
                              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(r.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    if (r.disqualified)
                      Text(r.reason, style: TextStyle(color: AppColors.down, fontSize: 11))
                    else if (isCandidate)
                      Text('✅ 站上 MA28 · 20日涨幅为正',
                          style: TextStyle(color: AppColors.up, fontSize: 11))
                    else
                      Text('未入选：${r.blockReason}',
                          style: TextStyle(color: AppColors.warning, fontSize: 11)),
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
                      r.disqualified ? '0' : r.score.toStringAsFixed(2),
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
                        value: r.disqualified || maxScore <= 0
                            ? 0
                            : (r.score / maxScore).clamp(0.0, 1.0).toDouble(),
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation(
                          r.disqualified ? AppColors.textSecondary : _scoreColor(r.score),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '涨 ${(r.cumulativeReturn * 100).toStringAsFixed(1)}%  波 ${(r.volatility * 100).toStringAsFixed(2)}%',
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
        '稳强度 = 20 日涨幅 ÷ 波动率（波动率取日收益样本标准差 max(σ, 0.3%) 防低波动失真）。'
        '三条红线剔除：近3日曾单日跌超5%、20日涨幅>+40%、偏离MA20>+12%。'
        '买入候选需再过两道筛：现价站上 MA28 且 20 日涨幅为正，取分数前三；'
        '全池无一只合格即提示全弱空仓。仅作分析展示，不构成投资建议。长按条目可移除。',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}

/// ETF 轮动默认池（33 只）。
///
/// 《ETF 轮动 · App 对齐规格 v2》（2026-09-18）第一节：**必须逐只对齐，不得自行增减**。
/// 曾混入池外的纳指ETF(sh513100)、电力ETF(sz159611)、养殖ETF 等已按要求移除；
/// 通信ETF国泰(sh515880)、软件ETF嘉实(sz159852)、创业板50ETF(sz159949) 等已补齐。
///
/// 以**代码**为准：名称差异（如 sh515050 官方简称"5G通信ETF"，规格叫"通信ETF华夏"）不影响打分期。
const List<String> etfRotationDefaultPool = [
  // 宽基
  'sh510300', 'sh510500', 'sh588000', 'sz159915', 'sh512100',
  'sz159949', 'sh510050', 'sz159901',
  // 科技
  'sh512480', 'sz159995', 'sh512760', 'sh515880', 'sh515050', 'sz159852',
  // 金融
  'sh512800', 'sh512000', 'sh512070',
  // 医药
  'sh512010', 'sh512170', 'sz159992',
  // 消费
  'sh512690', 'sz159928',
  // 制造 / 周期
  'sh512660', 'sh515030', 'sh515790',
  'sh512400', 'sh515220', 'sz159980', 'sh518880',
  // 海外
  'sh513050', 'sh513180', 'sh513500',
  // 其他
  'sz159825',
];

/// 默认池代码 → 展示名称（规格一节给出的名称）。
///
/// 池内每个代码都必须在此表中 —— 否则界面只能显示裸代码
/// （历史上"ETF 名称不显示"的成因），故有单测断言两者完全覆盖。
const Map<String, String> etfRotationDefaultNames = {
  'sh510300': '沪深300ETF', 'sh510500': '中证500ETF', 'sh588000': '科创50ETF',
  'sz159915': '创业板ETF', 'sh512100': '中证1000ETF', 'sz159949': '创业板50ETF',
  'sh510050': '上证50ETF', 'sz159901': '深证100ETF',
  'sh512480': '半导体ETF', 'sz159995': '芯片ETF华夏', 'sh512760': '芯片ETF国泰',
  'sh515880': '通信ETF国泰', 'sh515050': '通信ETF华夏', 'sz159852': '软件ETF嘉实',
  'sh512800': '银行ETF', 'sh512000': '券商ETF', 'sh512070': '证券保险ETF',
  'sh512010': '医药ETF', 'sh512170': '医疗ETF', 'sz159992': '创新药ETF',
  'sh512690': '酒ETF', 'sz159928': '消费ETF汇添富',
  'sh512660': '军工ETF', 'sh515030': '新能源车ETF', 'sh515790': '光伏ETF',
  'sh512400': '有色金属ETF', 'sh515220': '煤炭ETF', 'sz159980': '有色ETF大成',
  'sh518880': '黄金ETF',
  'sh513050': '中概互联ETF', 'sh513180': '恒生科技ETF', 'sh513500': '标普500ETF',
  'sz159825': '农业ETF',
};

/// 存量池是否应被当前默认池覆盖（代码里的默认池换代时的一次性迁移）。
///
/// 返回 false 的两个条件都很重要：
/// - 用户自定义过（增删过条目）→ 绝不覆盖，否则会删掉他自己加的标的；
/// - 存量池已与当前默认池一致 → 无需重建，避免每次启动都写盘。
///
/// ⚠️ 这是唯一会改动用户持久化数据的分支，故提成纯函数单独测。
bool shouldReseedEtfPool({
  required List<String> stored,
  required List<String> currentDefault,
  required bool customized,
}) {
  if (customized) return false;
  final sa = stored.toSet();
  final sb = currentDefault.toSet();
  return sa.length != sb.length || !sa.containsAll(sb);
}
