import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/search_api.dart';
import 'home_screen.dart';
import 'strategy_screen.dart';
import 'discover_screen.dart';
import 'settings_screen.dart';
import 'chart_screen.dart';

/// 主框架 — 底部导航
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          _AnalysisTab(),
          StrategyScreen(),
          DiscoverScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.trending_up, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.trending_up, color: AppColors.primary),
            label: '行情',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.analytics, color: AppColors.primary),
            label: '分析',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.psychology, color: AppColors.primary),
            label: '策略',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.explore, color: AppColors.primary),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 分析 Tab — 输入股票名称或代码进入技术分析
class _AnalysisTab extends ConsumerStatefulWidget {
  const _AnalysisTab();

  @override
  ConsumerState<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends ConsumerState<_AnalysisTab> {
  final _controller = TextEditingController();
  final _searchApi = SearchApi();
  final _focusNode = FocusNode();
  List<SearchResult> _suggestions = [];
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();

    // 6位纯数字 → 自动识别交易所，隐藏联想
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      setState(() => _showSuggestions = false);
      return;
    }

    // 不足2字符 → 不搜索
    if (trimmed.length < 2) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }

    // 汉字/字母 → 搜索联想
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchApi.search(trimmed);
      if (mounted) {
        setState(() {
          _suggestions = results.take(8).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    });
  }

  void _selectSuggestion(SearchResult result) {
    _controller.text = result.code;
    setState(() { _showSuggestions = false; });
    _openChart(result.code);
  }

  String _normalizeCode(String input) {
    final trimmed = input.trim().toLowerCase();
    // 已有前缀
    if (RegExp(r'^(sh|sz)\d{6}$').hasMatch(trimmed)) return trimmed;
    // 6位纯数字 → 自动补前缀
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return trimmed.startsWith('6') ? 'sh$trimmed' : 'sz$trimmed';
    }
    return trimmed;
  }

  void _onSubmit() {
    final code = _normalizeCode(_controller.text);
    if (RegExp(r'^(sh|sz)\d{6}$').hasMatch(code)) {
      _openChart(code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('输入股票名称或代码即可查询'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openChart(String code) {
    final normalized = _normalizeCode(code);
    if (!RegExp(r'^(sh|sz)\d{6}$').hasMatch(normalized)) return;
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChartScreen(stockCode: normalized),
    ));
  }

  String _exchangeLabel(String code) {
    if (code.startsWith('sh')) return '沪';
    if (code.startsWith('sz')) return '深';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('技术分析'), centerTitle: true),
      body: GestureDetector(
        onTap: () { _focusNode.unfocus(); setState(() => _showSuggestions = false); },
        behavior: HitTestBehavior.translucent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('输入股票名称或代码即可查询',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '如 贵州茅台 / 600519 / sh600519',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: _onChanged,
                          onSubmitted: (_) => _onSubmit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('分析'),
                      ),
                    ],
                  ),
                  if (_showSuggestions) _buildSuggestionsList(),
                ],
              ),
              const SizedBox(height: 24),
              Text('快捷入口',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickChip('贵州茅台', 'sh600519'),
                  _buildQuickChip('中国平安', 'sh601318'),
                  _buildQuickChip('五粮液', 'sz000858'),
                  _buildQuickChip('招商银行', 'sh600036'),
                  _buildQuickChip('宁德时代', 'sz300750'),
                  _buildQuickChip('比亚迪', 'sz002594'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _suggestions.map((s) {
          final exchange = _exchangeLabel(s.code);
          return InkWell(
            onTap: () => _selectSuggestion(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 交易所标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: s.code.startsWith('sh')
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.ma5.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(exchange, style: TextStyle(
                      color: s.code.startsWith('sh') ? AppColors.primary : AppColors.ma5,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                  const SizedBox(width: 8),
                  // 股票名称
                  Expanded(
                    child: Text(s.name, style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  // 股票代码
                  Text(s.code.toUpperCase(), style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickChip(String name, String code) {
    return ActionChip(
      label: Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(color: AppColors.divider),
      onPressed: () => _openChart(code),
    );
  }
}
