import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/models/ai_data.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/screens/chart_screen.dart';
import '../../presentation/screens/settings_screen.dart';

/// 智能选股器（妙想自然语言筛选）
///
/// 复用 EmAiApi.selectStocks（妙想 claw stock-screen 端点，BYOK 妙想 Key）。
/// 与既有「选股扫描 / AI 助手-潜力股」区分：本页提供自然语言输入 + 市场类型选择，
/// 面向「按条件/排序/推荐筛选多标的」场景，结果可直接跳转个股行情。
class SmartScreenerScreen extends ConsumerStatefulWidget {
  const SmartScreenerScreen({super.key});

  @override
  ConsumerState<SmartScreenerScreen> createState() => _SmartScreenerScreenState();
}

class _SmartScreenerScreenState extends ConsumerState<SmartScreenerScreen> {
  final _queryController = TextEditingController();
  final List<String> _types = ['A股', '港股', '美股', '基金', 'ETF', '可转债', '板块'];
  String _type = 'A股';
  bool _loading = false;
  List<AiStockPick> _results = [];
  String? _error;
  bool _searched = false;

  static const _examples = [
    '股价大于100元，主力流入，成交额排名前50',
    '创业板市盈率最低的50只',
    '半导体板块市值前20',
    '连续3天上涨且放量突破年线',
    '白酒主题基金近一年收益排名',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = '请输入筛选条件，如「股价大于100元的股票」');
      return;
    }
    final apiKey = ref.read(settingsProvider).emApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _error = '未配置妙想 API Key';
        _results = [];
        _searched = true;
      });
      return;
    }

    setState(() { _loading = true; _error = null; _searched = true; _results = []; });
    try {
      final api = EmAiApi(apiKey: apiKey);
      final list = await api.selectStocks(query, pageSize: 30, selectType: _type);
      if (mounted) setState(() { _results = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('智能选股器'), centerTitle: true),
      body: Column(
        children: [
          _buildInputBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '自然语言选股，如：股价大于100元的股票',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _run(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('筛选', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _types.map((t) {
              final selected = _type == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) => setState(() => _type = t),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _examples.map((ex) {
              return ActionChip(
                label: Text(ex, style: TextStyle(color: AppColors.primary, fontSize: 11)),
                backgroundColor: AppColors.primary.withOpacity(0.08),
                onPressed: () {
                  _queryController.text = ex;
                  _run();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _error!.contains('未配置')) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key, color: AppColors.warning, size: 40),
            const SizedBox(height: 12),
            Text('未配置妙想 API Key，无法使用智能选股', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('去设置页填入 Key', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: AppColors.warning, size: 40),
            const SizedBox(height: 12),
            Text('筛选失败', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _run,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!_searched) {
      return Center(
        child: Text('输入条件后点击「筛选」，用自然语言选出符合条件的标的',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text('未找到符合条件的标的，试试更宽泛的条件',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, _index) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildResultItem(_results[i]),
    );
  }

  Widget _buildResultItem(AiStockPick s) {
    final color = s.changePercent == null
        ? AppColors.textSecondary
        : (s.changePercent! >= 0 ? AppColors.up : AppColors.down);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChartScreen(stockCode: s.code)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name.isNotEmpty ? s.name : s.code,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (s.code.isNotEmpty)
                    Text(s.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(s.price == null ? '--' : s.price!.toStringAsFixed(2),
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                if (s.changePercent != null)
                  Text('${s.changePercent! >= 0 ? '+' : ''}${s.changePercent!.toStringAsFixed(2)}%',
                      style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
