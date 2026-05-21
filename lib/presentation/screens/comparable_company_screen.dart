import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/ai_report.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/datasources/local/ai_history_storage.dart';
import '../providers/settings_provider.dart';

/// 可比公司分析页面
class ComparableCompanyScreen extends ConsumerStatefulWidget {
  const ComparableCompanyScreen({super.key});

  @override
  ConsumerState<ComparableCompanyScreen> createState() => _ComparableCompanyScreenState();
}

class _ComparableCompanyScreenState extends ConsumerState<ComparableCompanyScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _storage = AiHistoryStorage();
  ComparableCompanyData? _data;
  bool _loading = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  EmAiApi _getApi() {
    final apiKey = ref.read(settingsProvider).emApiKey;
    return EmAiApi(apiKey: apiKey);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    AppLog.instance.info('PeerCompare', '开始分析同业: $query');

    try {
      final result = await _getApi().getComparableCompany(query);
      AppLog.instance.info('PeerCompare', '分析成功: ${result.companies.length}家公司');
      setState(() {
        _data = result;
        _loading = false;
      });
      if (result.companies.isEmpty) {
        setState(() => _error = '未找到可比公司数据');
      }
    } catch (e) {
      AppLog.instance.error('PeerCompare', '分析失败: $e');
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveToHistory() async {
    if (_data == null || _data!.companies.isEmpty) return;
    // 构建 Markdown 用于存储
    final md = _buildMarkdown();
    final record = AiQueryRecord(
      id: const Uuid().v4(),
      type: 'comparable',
      query: _searchController.text.trim(),
      resultMarkdown: md,
      timestamp: DateTime.now(),
    );
    await _storage.saveRecord(record);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('已保存到历史'), backgroundColor: AppColors.success, duration: const Duration(seconds: 1)),
      );
    }
  }

  String _buildMarkdown() {
    if (_data == null) return '';
    final buf = StringBuffer();
    buf.writeln('## ${_data!.targetCompany} — 同业对比');
    buf.writeln('**可比公司**: ${_data!.companies.join("、")}');
    buf.writeln();
    buf.writeln('### 经营指标');
    buf.writeln('| ${_data!.financeHeaders.join(" | ")} |');
    buf.writeln('| ${_data!.financeHeaders.map((_) => "---").join(" | ")} |');
    for (int i = 0; i < _data!.companies.length; i++) {
      final row = i < _data!.financeData.length ? _data!.financeData[i] : [];
      buf.writeln('| ${row.join(" | ")} |');
    }
    buf.writeln();
    buf.writeln('### 估值指标');
    buf.writeln('| ${_data!.valuationHeaders.join(" | ")} |');
    buf.writeln('| ${_data!.valuationHeaders.map((_) => "---").join(" | ")} |');
    for (int i = 0; i < _data!.companies.length; i++) {
      final row = i < _data!.valuationData.length ? _data!.valuationData[i] : [];
      buf.writeln('| ${row.join(" | ")} |');
    }
    return buf.toString();
  }

  void _showHistory() async {
    final records = await _storage.loadHistory(type: 'comparable');
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
                              // 从 Markdown 恢复不了结构化数据，但可以显示 Markdown
                              _data = null;
                              _error = null;
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
        title: const Text('同业对比'),
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
                      hintText: '输入公司名称，如"贵州茅台"',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.business, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('分析'),
                ),
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
                        Text('正在分析同业公司...', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : _data == null || _data!.companies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('输入公司名称开始分析', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                              ],
                            ),
                          )
                        : _buildResult(),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final d = _data!;
    return Column(
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${d.targetCompany} vs 同业',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${d.companies.length} 家公司',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        // Tab 栏
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '经营指标'),
            Tab(text: '估值指标'),
          ],
        ),
        // 表格
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDataTable(d.financeHeaders, d.financeData, d.companies),
              _buildDataTable(d.valuationHeaders, d.valuationData, d.companies),
            ],
          ),
        ),
        // 底部操作
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveToHistory,
              icon: Icon(Icons.bookmark_add, size: 18, color: AppColors.primary),
              label: Text('保存到历史', style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<String> headers, List<List<String>> data, List<String> companies) {
    if (headers.isEmpty) {
      return Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surface),
          dataRowColor: WidgetStateProperty.all(AppColors.cardBackground),
          border: TableBorder.all(color: AppColors.divider, width: 0.5),
          columnSpacing: 16,
          headingTextStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
          columns: [
            DataColumn(label: Text('指标')),
            ...companies.map((c) => DataColumn(label: Text(c, overflow: TextOverflow.ellipsis))),
          ],
          rows: List.generate(headers.length, (rowIdx) {
            return DataRow(
              cells: [
                DataCell(Text(headers[rowIdx], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ...List.generate(companies.length, (colIdx) {
                  final value = rowIdx < data.length && colIdx < data[rowIdx].length
                      ? data[rowIdx][colIdx]
                      : '-';
                  return DataCell(Text(_formatValue(value), style: const TextStyle(fontSize: 11)));
                }),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _formatValue(String value) {
    // 尝试格式化大数字（元→亿）
    final num = double.tryParse(value);
    if (num != null && num.abs() > 100000000) {
      return '${(num / 100000000).toStringAsFixed(2)}亿';
    }
    if (num != null && num.abs() > 10000) {
      return '${(num / 10000).toStringAsFixed(2)}万';
    }
    return value;
  }
}
