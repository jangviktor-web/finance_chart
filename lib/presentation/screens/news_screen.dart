import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../data/datasources/news_api.dart';
import '../../data/models/news_data.dart';
import 'chart_screen.dart';

/// 新闻资讯页面 — 3 Tab
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = NewsApi();

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
        title: const Text('财经新闻'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '7x24快讯'),
            Tab(text: '财联社'),
            Tab(text: '新闻搜索'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LiveNewsTab(api: _api, source: '7x24'),
          _LiveNewsTab(api: _api, source: 'cls'),
          _NewsSearchTab(api: _api),
        ],
      ),
    );
  }
}

/// 快讯 Tab（7x24 / 财联社共用）
class _LiveNewsTab extends StatefulWidget {
  final NewsApi api;
  final String source;
  const _LiveNewsTab({required this.api, required this.source});

  @override
  State<_LiveNewsTab> createState() => _LiveNewsTabState();
}

class _LiveNewsTabState extends State<_LiveNewsTab> {
  final List<LiveNewsItem> _data = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final data = widget.source == '7x24'
          ? await widget.api.get7x24News(page: 1)
          : await widget.api.getCLSNews(page: 1);
      if (mounted) setState(() { _data.clear(); _data.addAll(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final data = widget.source == '7x24'
          ? await widget.api.get7x24News(page: _page)
          : await widget.api.getCLSNews(page: _page);
      if (mounted) setState(() { _data.addAll(data); _loadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _buildError();
    if (_data.isEmpty) return Center(child: Text('暂无新闻', style: TextStyle(color: AppColors.textSecondary)));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _data.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _data.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            );
          }
          return _buildLiveNewsItem(_data[i]);
        },
      ),
    );
  }

  Widget _buildLiveNewsItem(LiveNewsItem item) {
    // 格式化时间：如果是今天的显示 HH:mm，否则显示 MM/DD HH:mm
    final now = DateTime.now();
    final isToday = item.time.year == now.year && item.time.month == now.month && item.time.day == now.day;
    final timeStr = isToday
        ? '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}'
        : '${item.time.month.toString().padLeft(2, '0')}/${item.time.day.toString().padLeft(2, '0')} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => _showNewsDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Text(timeStr, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.content, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4)),
                  if (item.stockCode != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChartScreen(stockCode: item.stockCode!),
                      )),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${item.stockName ?? ''} ${item.stockCode?.toUpperCase() ?? ''}',
                            style: TextStyle(color: AppColors.primary, fontSize: 10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewsDetail(LiveNewsItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 时间
            Text(
              '${item.time.year}-${item.time.month.toString().padLeft(2, '0')}-${item.time.day.toString().padLeft(2, '0')} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // 内容
            Text(item.content, style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, height: 1.6,
            )),
            const SizedBox(height: 16),
            // 股票链接
            if (item.stockCode != null)
              ListTile(
                leading: Icon(Icons.show_chart, color: AppColors.primary),
                title: Text('${item.stockName ?? ''} ${item.stockCode?.toUpperCase() ?? ''}',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('查看K线图', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChartScreen(stockCode: item.stockCode!),
                  ));
                },
              ),
            const SizedBox(height: 8),
            // 关闭按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('关闭', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
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
          Icon(Icons.cloud_off, color: AppColors.warning, size: 40),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(color: AppColors.textPrimary)),
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
}

/// 新闻搜索 Tab
class _NewsSearchTab extends StatefulWidget {
  final NewsApi api;
  const _NewsSearchTab({required this.api});

  @override
  State<_NewsSearchTab> createState() => _NewsSearchTabState();
}

class _NewsSearchTabState extends State<_NewsSearchTab> {
  final _controller = TextEditingController();
  final List<NewsItem> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() { _loading = true; _searched = true; });
    try {
      final data = await widget.api.searchNews(keyword);
      if (mounted) setState(() { _results.clear(); _results.addAll(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索财经新闻...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('搜索', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : !_searched
                  ? Center(child: Text('输入关键词搜索财经新闻', style: TextStyle(color: AppColors.textSecondary)))
                  : _results.isEmpty
                      ? Center(child: Text('未找到相关新闻', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) => _buildNewsItem(_results[i]),
                        ),
        ),
      ],
    );
  }

  Widget _buildNewsItem(NewsItem item) {
    final timeStr = '${item.time.month}/${item.time.day} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: item.url.isNotEmpty ? () => _launchUrl(item.url) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            if (item.digest.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.digest, style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(item.source, style: TextStyle(color: AppColors.primary, fontSize: 11)),
                const Spacer(),
                Text(timeStr, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                if (item.url.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: AppColors.textSecondary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
