import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/ai_report.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/datasources/local/ai_history_storage.dart';
import '../providers/settings_provider.dart';
import '../widgets/markdown_card.dart';

/// 市场热点发现页面
class HotspotScreen extends ConsumerStatefulWidget {
  const HotspotScreen({super.key});

  @override
  ConsumerState<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends ConsumerState<HotspotScreen> {
  final _searchController = TextEditingController(text: '今日热点');
  final _storage = AiHistoryStorage();
  String _markdown = '';
  List<HotspotItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHotspot();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EmAiApi _getApi() {
    final apiKey = ref.read(settingsProvider).emApiKey;
    return EmAiApi(apiKey: apiKey);
  }

  Future<void> _loadHotspot() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    AppLog.instance.info('Hotspot', '开始查询热点: $query');

    try {
      final result = await _getApi().getHotspot(question: query);
      AppLog.instance.info('Hotspot', '查询成功, 结果长度=${result.length}');
      setState(() {
        _markdown = result;
        _items = _parseHotspotItems(result);
        _loading = false;
      });
    } catch (e) {
      AppLog.instance.error('Hotspot', '查询失败: $e');
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  /// 将 Markdown 解析为热点条目列表
  /// Markdown 格式通常为: 1. **标题** - 内容...  2. **标题** - 内容...
  List<HotspotItem> _parseHotspotItems(String markdown) {
    if (markdown.isEmpty || markdown.startsWith('查询失败') || markdown.startsWith('暂无')) {
      return [];
    }

    final items = <HotspotItem>[];
    // 按编号分割: 匹配 "1." "2." 等开头的行
    final sections = markdown.split(RegExp(r'(?=\n?\d+[\.\、\）\)]\s)', multiLine: true));

    for (final section in sections) {
      final trimmed = section.trim();
      if (trimmed.isEmpty) continue;

      // 提取排名编号
      final rankMatch = RegExp(r'^(\d+)[\.\、\）\)]').firstMatch(trimmed);
      if (rankMatch == null) continue;

      final rank = int.tryParse(rankMatch.group(1) ?? '0') ?? 0;

      // 提取标题: **粗体** 内容
      final titleMatch = RegExp(r'\*\*(.+?)\*\*').firstMatch(trimmed);
      final title = titleMatch?.group(1)?.trim() ?? trimmed.substring(0, trimmed.length.clamp(0, 50));

      // 提取时间: HH:MM 格式
      final timeMatch = RegExp(r'(\d{1,2}:\d{2})').firstMatch(trimmed);
      final time = timeMatch?.group(1) ?? '';

      // 内容: 去掉编号和标题后的剩余部分
      var content = trimmed;
      if (titleMatch != null) {
        content = trimmed.substring(titleMatch.end).trim();
        if (content.startsWith('-') || content.startsWith('：') || content.startsWith(':')) {
          content = content.substring(1).trim();
        }
      }
      if (content.isEmpty) content = title;

      items.add(HotspotItem(
        rank: rank,
        title: title,
        content: content,
        time: time,
      ));
    }

    // 如果解析失败，将整段 Markdown 作为一条
    if (items.isEmpty && markdown.trim().isNotEmpty) {
      items.add(HotspotItem(
        rank: 1,
        title: '热点资讯',
        content: markdown,
        time: '',
      ));
    }

    return items;
  }

  Future<void> _saveToHistory() async {
    if (_markdown.isEmpty || _markdown.startsWith('查询失败') || _markdown.startsWith('暂无')) return;
    final record = AiQueryRecord(
      id: const Uuid().v4(),
      type: 'hotspot',
      query: _searchController.text.trim(),
      resultMarkdown: _markdown,
      timestamp: DateTime.now(),
    );
    await _storage.saveRecord(record);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('已保存到历史'), backgroundColor: AppColors.success, duration: const Duration(seconds: 1)),
      );
    }
  }

  void _showHistory() async {
    final records = await _storage.loadHistory(type: 'hotspot');
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
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
                      onPressed: () async {
                        await _storage.clearHistory();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
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
                          subtitle: Text(
                            '${r.timestamp.month}/${r.timestamp.day} ${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _searchController.text = r.query;
                              _markdown = r.resultMarkdown;
                              _items = _parseHotspotItems(r.resultMarkdown);
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

  void _showItemDetail(HotspotItem item) {
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
            // 顶部拖拽指示条
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _buildRankBadge(item.rank, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            // 内容
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

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return AppColors.up;
      case 2: return const Color(0xFFFF6D00);
      case 3: return const Color(0xFFFFA000);
      default: return AppColors.textSecondary;
    }
  }

  Widget _buildRankBadge(int rank, {double size = 32}) {
    final color = _rankColor(rank);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          color: color,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('市场热点'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistory),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '输入查询内容...',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _loadHotspot(),
                  ),
                ),
                const SizedBox(width: 8),
                _buildQuickChip('今日热点'),
                const SizedBox(width: 4),
                _buildQuickChip('A股热点'),
              ],
            ),
          ),
          // 内容区
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text('正在获取热点资讯...', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.down),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: AppColors.down)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadHotspot,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text('暂无热点数据', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  itemCount: _items.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                                  itemBuilder: (ctx, i) {
                                    final item = _items[i];
                                    return _buildItemCard(item);
                                  },
                                ),
                              ),
                              // 底部操作按钮
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), // 底部按钮间距
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _saveToHistory,
                                        icon: Icon(Icons.bookmark_add, size: 18, color: AppColors.primary),
                                        label: Text('保存记录', style: TextStyle(color: AppColors.primary)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.primary),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showHistory,
                                        icon: Icon(Icons.history, size: 18, color: AppColors.textSecondary),
                                        label: Text('查看历史', style: TextStyle(color: AppColors.textSecondary)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.divider),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(HotspotItem item) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showItemDetail(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _buildRankBadge(item.rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.time,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return ActionChip(
      label: Text(label, style: TextStyle(color: AppColors.primary, fontSize: 12)),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      side: BorderSide.none,
      onPressed: () {
        _searchController.text = label;
        _loadHotspot();
      },
    );
  }
}
