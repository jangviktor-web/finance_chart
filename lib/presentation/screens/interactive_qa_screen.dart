import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/hudong_api.dart';
import '../../data/models/hudong_data.dart';

/// 互动易问答页（A3）
class InteractiveQaScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const InteractiveQaScreen({super.key, required this.stockCode, required this.stockName});

  @override
  State<InteractiveQaScreen> createState() => _InteractiveQaScreenState();
}

class _InteractiveQaScreenState extends State<InteractiveQaScreen> {
  final _api = HudongApi();
  List<InteractiveQA> _data = [];
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
      final data = await _api.searchByCode(widget.stockCode);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.stockName} 互动问答'),
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
                  ? Center(child: Text('暂无互动问答', style: TextStyle(color: AppColors.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        itemCount: _data.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (ctx, i) {
                          final qa = _data[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.help_outline, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(qa.question,
                                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.forum_outlined, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(qa.answer.isEmpty ? '（暂无回复）' : qa.answer,
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('提问: ${_fmtDate(qa.date)}',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
