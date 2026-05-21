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
                // 快捷标签
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
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            MarkdownCard(markdown: _markdown),
                            const SizedBox(height: 16),
                            // 操作按钮
                            Row(
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
                          ],
                        ),
                      ),
          ),
        ],
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
