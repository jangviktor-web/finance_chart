import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../presentation/providers/market_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/screens/settings_screen.dart';
import 'fund_detail_screen.dart';

/// 公募基金模块（同花顺 BYOK）
///
/// 流程：meta 搜索（按名称/代码消歧为 thscode + asset_type）→ 列表 → 详情。
/// 复用 MarketApi.searchFunds / getFundProfile 等同花顺端点，不重复实现底层。
class FundModuleScreen extends ConsumerStatefulWidget {
  const FundModuleScreen({super.key});

  @override
  ConsumerState<FundModuleScreen> createState() => _FundModuleScreenState();
}

class _FundModuleScreenState extends ConsumerState<FundModuleScreen> {
  final _queryController = TextEditingController();
  final List<(String, String)> _filters = const [
    ('全部', 'fund-otc,fund-etf,fund-lof,fund-reits'),
    ('场外', 'fund-otc'),
    ('ETF', 'fund-etf'),
    ('LOF', 'fund-lof'),
    ('REITs', 'fund-reits'),
  ];
  int _filterIdx = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) {
      setState(() => _error = '请输入基金代码或名称');
      return;
    }
    final apiKey = ref.read(settingsProvider).thinksApiKey;
    if (apiKey.isEmpty) {
      setState(() { _error = '未配置同花顺 API Key'; _results = []; });
      return;
    }
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final api = ref.read(marketApiProvider);
      final list = await api.searchFunds(q, assetType: _filters[_filterIdx].$2);
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
          if (list.isEmpty) _error = '未找到匹配的公募基金';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// asset_type（fund-otc 等）→ fund_type（otc/exchange/reits）
  String _toFundType(String assetType) {
    if (assetType.contains('otc')) return 'otc';
    if (assetType.contains('reits')) return 'reits';
    return 'exchange'; // etf / lof
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('公募基金'), centerTitle: true),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
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
                    hintText: '基金代码或名称，如：沪深300ETF',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _search,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
                child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('搜索', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _filters.map((f) {
              final selected = _filterIdx == _filters.indexOf(f);
              return ChoiceChip(
                label: Text(f.$1),
                selected: selected,
                onSelected: (_) => setState(() => _filterIdx = _filters.indexOf(f)),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12),
                visualDensity: VisualDensity.compact,
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
            Text('未配置同花顺 API Key，无法使用公募基金', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('输入基金代码或名称后搜索', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, _i) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _results[i];
        final name = item['name']?.toString() ?? '';
        final thscode = item['thscode']?.toString() ?? '';
        final assetType = item['asset_type']?.toString() ?? '';
        final typeLabel = assetType.replaceFirst('fund-', '');
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FundDetailScreen(
                thscode: thscode,
                fundName: name,
                fundType: _toFundType(assetType),
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(thscode, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(typeLabel.toUpperCase(), style: TextStyle(color: AppColors.primary, fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
