import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/research_api.dart';
import '../../data/models/research_data.dart';

/// 个股研究报告页（A2）
class ResearchScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const ResearchScreen({super.key, required this.stockCode, required this.stockName});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final _api = ResearchApi();
  List<ResearchReport> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getReports(widget.stockCode, days: 90, pageSize: 20);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.stockName} 研报'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('加载失败: $_error', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _data.isEmpty
                  ? Center(child: Text('近90天无研报', style: TextStyle(color: AppColors.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        itemCount: _data.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (ctx, i) {
                          final r = _data[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (r.rating.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(r.rating,
                                            style: TextStyle(color: AppColors.primary, fontSize: 11)),
                                      ),
                                    const SizedBox(width: 8),
                                    Text(r.org, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    const Spacer(),
                                    Text('${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                  ],
                                ),
                                if (r.author.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('分析师: ${r.author}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
