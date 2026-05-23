import 'dart:io';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../providers/settings_provider.dart';
import 'scan_screen.dart';
import 'chart_screen.dart';
import 'sector_detail_screen.dart';
import 'sentiment_screen.dart';
import 'macro_screen.dart';
import 'news_screen.dart';
import 'ai_chat_screen.dart';
import 'compare_screen.dart';
import 'fund_flow_screen.dart';
import 'comparable_company_screen.dart';
import '../../data/datasources/search_api.dart';
import '../../data/datasources/sentiment_api.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/datasources/local/ai_history_storage.dart';
import '../../data/models/ai_report.dart';
import '../widgets/markdown_card.dart';

/// 大盘指数数据
class IndexData {
  final String name;
  final String code;
  final double price;
  final double change;
  final double changePercent;

  const IndexData({
    required this.name,
    required this.code,
    required this.price,
    required this.change,
    required this.changePercent,
  });
}

/// 热门板块数据
class SectorData {
  final String name;
  final double changePercent;
  final int upCount;
  final int downCount;
  final String leader;
  final String? bkCode; // 东方财富板块代码

  const SectorData({
    required this.name,
    required this.changePercent,
    required this.upCount,
    required this.downCount,
    required this.leader,
    this.bkCode,
  });
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  List<IndexData> _indices = [];
  List<SectorData> _sectors = [];
  bool _isLoading = true;
  String? _error;
  final _sentimentApi = SentimentApi();

  // ── 热点资讯 ──
  final _hotspotController = TextEditingController(text: '今日热点');
  final _hotspotStorage = AiHistoryStorage();
  List<HotspotItem> _hotspotItems = [];
  String _hotspotMarkdown = '';
  bool _hotspotLoading = false;

  static const _indexCodes = [
    ('sh000001', '上证指数'),
    ('sz399001', '深证成指'),
    ('sz399006', '创业板指'),
    ('sh000688', '科创50'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHotspot();
  }

  @override
  void dispose() {
    _hotspotController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 并行加载大盘指数和热门板块
      final indicesFuture = _fetchIndices();
      final sectorsFuture = _sentimentApi.getHotSectors(limit: 8);

      final results = await Future.wait([indicesFuture, sectorsFuture]);
      final indices = results[0] as List<IndexData>;
      final sectorMaps = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _indices = indices;
        _sectors = sectorMaps.map((s) => SectorData(
          name: s['name'] ?? '',
          changePercent: (s['changePercent'] ?? 0).toDouble(),
          upCount: (s['upCount'] ?? 0).toInt(),
          downCount: (s['downCount'] ?? 0).toInt(),
          leader: s['leader'] ?? '',
          bkCode: s['bkCode'],
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<IndexData>> _fetchIndices() async {
    final codes = _indexCodes.map((c) => c.$1).join(',');
    final url = 'https://qt.gtimg.cn/q=$codes';
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      ).then((b) => b.toBytes());

      // 腾讯 API 返回 GBK 编码，用 fast_gbk 解码
      final body = gbk.decode(bytes);
      final results = <IndexData>[];

      for (final line in body.split('\n')) {
        final match = RegExp(r'"(.+?)"').firstMatch(line);
        if (match == null) continue;
        final fields = match.group(1)!.split('~');
        if (fields.length < 35) continue;

        final name = fields[1].trim();
        if (name.isEmpty) continue;

        results.add(IndexData(
          name: name,
          code: fields[2],
          price: double.tryParse(fields[3]) ?? 0,
          change: double.tryParse(fields[31]) ?? 0,
          changePercent: double.tryParse(fields[32]) ?? 0,
        ));
      }

      return results;
    } finally {
      client.close();
    }
  }

  // ── 热点资讯方法 ──

  EmAiApi _getHotspotApi() {
    final apiKey = ref.read(settingsProvider).emApiKey;
    return EmAiApi(apiKey: apiKey);
  }

  Future<void> _loadHotspot() async {
    final query = _hotspotController.text.trim();
    if (query.isEmpty) return;
    setState(() => _hotspotLoading = true);
    try {
      final result = await _getHotspotApi().getHotspot(question: query);
      setState(() {
        _hotspotMarkdown = result;
        _hotspotItems = _parseHotspotItems(result);
        _hotspotLoading = false;
      });
    } catch (e) {
      setState(() => _hotspotLoading = false);
    }
  }

  List<HotspotItem> _parseHotspotItems(String markdown) {
    if (markdown.isEmpty || markdown.startsWith('查询失败') || markdown.startsWith('暂无')) return [];
    final items = <HotspotItem>[];
    final sections = markdown.split(RegExp(r'(?=\n?\d+[\.\、\）\)]\s)', multiLine: true));
    for (final section in sections) {
      final trimmed = section.trim();
      if (trimmed.isEmpty) continue;
      final rankMatch = RegExp(r'^(\d+)[\.\、\）\)]').firstMatch(trimmed);
      if (rankMatch == null) continue;
      final rank = int.tryParse(rankMatch.group(1) ?? '0') ?? 0;
      final titleMatch = RegExp(r'\*\*(.+?)\*\*').firstMatch(trimmed);
      final title = titleMatch?.group(1)?.trim() ?? trimmed.substring(0, trimmed.length.clamp(0, 50));
      final timeMatch = RegExp(r'(\d{1,2}:\d{2})').firstMatch(trimmed);
      final time = timeMatch?.group(1) ?? '';
      var content = trimmed;
      if (titleMatch != null) {
        content = trimmed.substring(titleMatch.end).trim();
        if (content.startsWith('-') || content.startsWith('：') || content.startsWith(':')) {
          content = content.substring(1).trim();
        }
      }
      if (content.isEmpty) content = title;
      items.add(HotspotItem(rank: rank, title: title, content: content, time: time));
    }
    if (items.isEmpty && markdown.trim().isNotEmpty) {
      items.add(HotspotItem(rank: 1, title: '热点资讯', content: markdown, time: ''));
    }
    return items;
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return AppColors.up;
      case 2: return const Color(0xFFFF6D00);
      case 3: return const Color(0xFFFFA000);
      default: return AppColors.textSecondary;
    }
  }

  void _showHotspotDetail(HotspotItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _rankColor(item.rank).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text('${item.rank}', style: TextStyle(color: _rankColor(item.rank), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.title, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: MarkdownCard(markdown: item.content),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveHotspotToHistory() {
    if (_hotspotMarkdown.isEmpty || _hotspotMarkdown.startsWith('查询失败') || _hotspotMarkdown.startsWith('暂无')) return;
    final record = AiQueryRecord(
      id: const Uuid().v4(),
      type: 'hotspot',
      query: _hotspotController.text.trim(),
      resultMarkdown: _hotspotMarkdown,
      timestamp: DateTime.now(),
    );
    _hotspotStorage.saveRecord(record);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('已保存到历史'), backgroundColor: AppColors.success, duration: const Duration(seconds: 1)),
    );
  }

  void _showHotspotHistory() async {
    final records = await _hotspotStorage.loadHistory(type: 'hotspot');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('查询历史', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (records.isNotEmpty)
                    TextButton(
                      onPressed: () async { await _hotspotStorage.clearHistory(); if (ctx.mounted) Navigator.pop(ctx); },
                      child: Text('清空', style: TextStyle(color: AppColors.down)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? Center(child: Text('暂无历史记录', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: records.length,
                      itemBuilder: (ctx, i) {
                        final r = records[i];
                        return ListTile(
                          title: Text(r.query, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          subtitle: Text('${r.timestamp.month}/${r.timestamp.day} ${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _hotspotController.text = r.query;
                              _hotspotMarkdown = r.resultMarkdown;
                              _hotspotItems = _parseHotspotItems(r.resultMarkdown);
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hasScan = settings.enableScan;
    final hasAnyFeature = settings.enableSentiment || settings.enableMacro || settings.enableNews || settings.enableScan || settings.enableAi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('发现'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (hasScan) ...[
                    _buildScanEntry(),
                    const SizedBox(height: 16),
                  ],
                  if (hasAnyFeature) ...[
                    _buildSectionTitle('功能入口'),
                    const SizedBox(height: 8),
                    _buildFunctionGrid(),
                    const SizedBox(height: 16),
                  ],
                  if (settings.enableHotspot) ...[
                    _buildSectionTitle('市场热点'),
                    const SizedBox(height: 8),
                    _buildHotspotSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionTitle('大盘指数'),
                  const SizedBox(height: 8),
                  _buildIndicesGrid(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('热门板块'),
                  const SizedBox(height: 8),
                  _buildSectorList(),
                  const SizedBox(height: 24),
                  _buildDisclaimer(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildIndicesGrid() {
    if (_indices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('指数数据加载中...', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _indices.length,
      itemBuilder: (ctx, i) {
        final idx = _indices[i];
        final color = idx.changePercent >= 0 ? AppColors.up : AppColors.down;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(idx.name, style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(idx.price.toStringAsFixed(2),
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${idx.change >= 0 ? '+' : ''}${idx.changePercent.toStringAsFixed(2)}%',
                style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectorList() {
    return Column(
      children: _sectors.map((sector) {
        final color = sector.changePercent >= 0 ? AppColors.up : AppColors.down;
        return GestureDetector(
          onTap: () => _showSectorDetail(sector),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sector.name, style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('领涨: ${sector.leader}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text('${sector.changePercent >= 0 ? '+' : ''}${sector.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${sector.upCount}↑', style: TextStyle(color: AppColors.up, fontSize: 11)),
                          const SizedBox(width: 8),
                          Text('${sector.downCount}↓', style: TextStyle(color: AppColors.down, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  sector.changePercent >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: color, size: 20,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showSectorDetail(SectorData sector) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SectorDetailScreen(
        sectorName: sector.name,
        sectorChangePercent: sector.changePercent,
        bkCode: sector.bkCode,
      ),
    ));
  }

  Widget _buildScanEntry() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.radar, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('开盘扫描选股',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('全市场A股智能扫描，发现今日潜力股',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionGrid() {
    final settings = ref.watch(settingsProvider);
    final items = <(String, IconData, Color, Widget Function())>[
      if (settings.enableSentiment)
        ('市场情绪', Icons.favorite_border, AppColors.up, () => const SentimentScreen()),
      if (settings.enableMacro)
        ('宏观数据', Icons.show_chart, AppColors.primary, () => const MacroScreen()),
      if (settings.enableNews)
        ('财经新闻', Icons.article_outlined, AppColors.ma5, () => const NewsScreen()),
      if (settings.enableScan)
        ('选股扫描', Icons.radar, AppColors.warning, () => const ScanScreen()),
      ('多股对比', Icons.compare_arrows, AppColors.ma10, () => const CompareScreen()),
      ('资金流向', Icons.account_balance, AppColors.ma60, () => const FundFlowScreen()),
      if (settings.enableAi)
        ('AI 助手', Icons.smart_toy, AppColors.primary, () => const AiChatScreen()),
      if (settings.enablePeerCompare)
        ('同业对比', Icons.bar_chart, AppColors.ma20, () => const ComparableCompanyScreen()),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final (name, icon, color, builder) = items[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => builder())),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotspotSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索栏 + 快捷标签
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hotspotController,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '输入查询内容...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadHotspot(),
                ),
              ),
              const SizedBox(width: 6),
              _buildHotspotChip('今日热点'),
              const SizedBox(width: 4),
              _buildHotspotChip('A股热点'),
            ],
          ),
          const SizedBox(height: 10),
          // 热点列表
          if (_hotspotLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (_hotspotItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('暂无热点数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            )
          else
            ...(_hotspotItems.take(8).map((item) => _buildHotspotItem(item))),
          // 底部按钮
          if (_hotspotItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveHotspotToHistory,
                    icon: Icon(Icons.bookmark_add, size: 14, color: AppColors.primary),
                    label: Text('保存记录', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showHotspotHistory,
                    icon: Icon(Icons.history, size: 14, color: AppColors.textSecondary),
                    label: Text('查看历史', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.divider), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHotspotChip(String label) {
    return ActionChip(
      label: Text(label, style: TextStyle(color: AppColors.primary, fontSize: 11)),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        _hotspotController.text = label;
        _loadHotspot();
      },
    );
  }

  Widget _buildHotspotItem(HotspotItem item) {
    final color = _rankColor(item.rank);
    return InkWell(
      onTap: () => _showHotspotDetail(item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text('${item.rank}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title.length > 20 ? '${item.title.substring(0, 20)}...' : item.title,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.time.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(item.time, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ],
        ),
      ),
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
        '数据来源: 腾讯财经 | 板块数据仅供参考',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
