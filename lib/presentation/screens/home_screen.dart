import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/search_api.dart';
import '../../data/models/watchlist_group.dart';
import '../providers/market_provider.dart';
import '../providers/watchlist_provider.dart';
import 'chart_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  int _selectedGroupIndex = 0;
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  void _openChart(String code) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChartScreen(stockCode: code)),
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults.clear();
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchByName(query.trim(), autocomplete: true);
    });
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (RegExp(r'^\d{6}$').hasMatch(query)) {
      final code = query.startsWith('6') ? 'sh$query' : 'sz$query';
      _openChart(code);
      return;
    }

    if (RegExp(r'^(sh|sz)\d{6}$', caseSensitive: false).hasMatch(query)) {
      _openChart(query.toLowerCase());
      return;
    }

    _searchByName(query);
  }

  Future<void> _searchByName(String query, {bool autocomplete = false}) async {
    setState(() {
      _isSearching = true;
      if (!autocomplete) _searchResults.clear();
    });

    try {
      final repo = ref.read(marketRepositoryProvider);
      final results = await repo.search(query);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _showSuggestions = autocomplete && results.isNotEmpty;
      });

      if (!autocomplete) {
        if (_searchResults.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('未找到"$query"相关股票'),
              backgroundColor: AppColors.down,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (_searchResults.length == 1) {
          _openChart(_searchResults.first.code);
        } else {
          _showSearchResults();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      if (!autocomplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: AppColors.down,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSearchResults() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('搜索结果',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('共${_searchResults.length}个结果',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (ctx, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          item.code.length > 5 ? item.code.substring(0, 3) : item.code,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ),
                    title: Text(item.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                    subtitle: Text(item.code.toUpperCase(),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openChart(item.code);
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

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('新建分组', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '输入分组名称',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(watchlistProvider.notifier).addGroup(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showGroupContextMenu(WatchlistGroup group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(group.name,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (group.id != 'default')
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: Text('重命名', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameGroupDialog(group);
                },
              ),
            if (group.id != 'default')
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.down),
                title: Text('删除分组', style: TextStyle(color: AppColors.down)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(watchlistProvider.notifier).removeGroup(group.id);
                  if (_selectedGroupIndex >= ref.read(watchlistProvider).length) {
                    setState(() => _selectedGroupIndex = 0);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameGroupDialog(WatchlistGroup group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('重命名分组', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(watchlistProvider.notifier).renameGroup(group.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showStockContextMenu(String code, String groupName) {
    final groups = ref.read(watchlistProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(code.toUpperCase(),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (groups.length > 1)
              ...groups.where((g) => g.name != groupName).map((g) => ListTile(
                leading: const Icon(Icons.move_to_inbox, color: AppColors.primary),
                title: Text('移到 "${g.name}"', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(watchlistProvider.notifier).moveStock(
                    groups.firstWhere((gg) => gg.name == groupName).id,
                    g.id,
                    code,
                  );
                },
              )),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.down),
              title: Text('从自选移除', style: TextStyle(color: AppColors.down)),
              onTap: () {
                Navigator.pop(ctx);
                final group = groups.firstWhere((g) => g.name == groupName);
                ref.read(watchlistProvider.notifier).removeStock(group.id, code);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(watchlistProvider);
    final currentGroup = groups.isNotEmpty
        ? groups[_selectedGroupIndex.clamp(0, groups.length - 1)]
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('策盈'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '输入股票代码或名称',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults.clear();
                                _showSuggestions = false;
                              });
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _onSearch(),
                ),
                // 搜索联想下拉
                if (_showSuggestions && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length.clamp(0, 5),
                      itemBuilder: (ctx, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.name,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          subtitle: Text(item.code.toUpperCase(),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults.clear();
                              _showSuggestions = false;
                            });
                            _openChart(item.code);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 分组 Tab 栏
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...groups.asMap().entries.map((entry) {
                  final index = entry.key;
                  final group = entry.value;
                  final isSelected = index == _selectedGroupIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGroupIndex = index),
                      onLongPress: () => _showGroupContextMenu(group),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          group.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // 添加分组按钮
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: _showAddGroupDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Icon(Icons.add, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 股票列表
          Expanded(
            child: currentGroup == null || currentGroup.codes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_border, color: AppColors.textSecondary.withOpacity(0.5), size: 64),
                        const SizedBox(height: 16),
                        Text('暂无自选股',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('在搜索或分析页面添加股票到自选',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      // 刷新当前分组所有股票行情
                      for (final code in currentGroup.codes) {
                        ref.read(klineProvider(code).notifier).load(period: 'day');
                      }
                      // 等待所有刷新完成
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: currentGroup.codes.length,
                      itemBuilder: (ctx, index) {
                        final code = currentGroup.codes[index];
                        return _StockCard(
                          code: code,
                          onTap: () => _openChart(code),
                          onLongPress: () => _showStockContextMenu(code, currentGroup.name),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

/// 带实时价格的股票卡片
class _StockCard extends ConsumerWidget {
  final String code;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StockCard({required this.code, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(klineProvider(code));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 股票名称 + 代码
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quoteAsync.quote.name,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(code.toUpperCase(),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            // 成交量 + 成交额
            if (quoteAsync.quote.volume > 0)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatVolume(quoteAsync.quote.volume),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatAmount(quoteAsync.quote.amount),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            // 价格 + 涨跌幅
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (quoteAsync.quote.now > 0)
                  Text(quoteAsync.quote.now.toStringAsFixed(2),
                    style: TextStyle(
                      color: quoteAsync.quote.isUp ? AppColors.up : AppColors.down,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                if (quoteAsync.quote.now > 0)
                  Text(
                    '${quoteAsync.quote.changePercent >= 0 ? '+' : ''}${quoteAsync.quote.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: quoteAsync.quote.isUp ? AppColors.up : AppColors.down,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(1)}亿手';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(1)}万手';
    }
    return '${volume.toStringAsFixed(0)}手';
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(1)}亿';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(0);
  }
}
