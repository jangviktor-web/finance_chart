import 'dart:io';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../providers/settings_provider.dart';
import 'scan_screen.dart';
import 'chart_screen.dart';
import 'sector_detail_screen.dart';
import 'sentiment_screen.dart';
import 'macro_screen.dart';
import 'news_screen.dart';
import 'ai_chat_screen.dart';
import '../../data/datasources/search_api.dart';

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

  static const _indexCodes = [
    ('sh000001', '上证指数'),
    ('sz399001', '深证成指'),
    ('sz399006', '创业板指'),
    ('sh000688', '科创50'),
  ];

  static const _hotSectors = [
    ('半导体', '+3.21%', 45, 12, '中芯国际', 'BK1036'),
    ('新能源', '+2.15%', 38, 18, '宁德时代', 'BK0493'),
    ('医药生物', '+1.87%', 52, 23, '恒瑞医药', 'BK0485'),
    ('白酒', '+1.23%', 15, 8, '贵州茅台', 'BK0491'),
    ('银行', '+0.95%', 30, 5, '招商银行', 'BK0475'),
    ('房地产', '-1.45%', 8, 35, '万科A', 'BK0451'),
    ('军工', '-0.88%', 20, 28, '中航沈飞', 'BK0541'),
    ('人工智能', '+4.56%', 55, 8, '科大讯飞', 'BK0807'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final indices = await _fetchIndices();
      setState(() {
        _indices = indices;
        _sectors = _hotSectors
            .map((s) => SectorData(
                  name: s.$1,
                  changePercent: double.parse(s.$2.replaceAll('%', '')),
                  upCount: s.$3,
                  downCount: s.$4,
                  leader: s.$5,
                  bkCode: s.$6,
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // 使用默认数据
        _sectors = _hotSectors
            .map((s) => SectorData(
                  name: s.$1,
                  changePercent: double.parse(s.$2.replaceAll('%', '')),
                  upCount: s.$3,
                  downCount: s.$4,
                  leader: s.$5,
                  bkCode: s.$6,
                ))
            .toList();
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
      if (settings.enableAi)
        ('AI 助手', Icons.smart_toy, AppColors.primary, () => const AiChatScreen()),
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
