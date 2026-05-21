import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';
import '../../data/models/scan_result.dart';
import '../../data/datasources/local/scan_history_storage.dart';
import '../../domain/services/market_scanner.dart';
import '../providers/market_provider.dart';
import '../providers/watchlist_provider.dart';
import 'chart_screen.dart';

/// 全市场扫描选股页面
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  ScanStatus _status = ScanStatus.idle;
  ScanConfig _config = const ScanConfig();
  List<ScanResult> _results = [];
  List<Map<String, dynamic>> _history = [];
  List<ScanConfig> _savedConfigs = [];
  int _currentProgress = 0;
  int _totalStocks = 0;
  String _currentCode = '';
  bool _showConfig = false;
  bool _showHistory = false;

  final _historyStorage = ScanHistoryStorage();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSavedConfigs();
  }

  Future<void> _loadSavedConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_scan_configs');
    if (jsonStr != null) {
      try {
        final list = json.decode(jsonStr) as List;
        setState(() {
          _savedConfigs = list.map((e) => ScanConfig(
            strategy: e['strategy'] ?? 'all',
            filterST: e['filterST'] ?? true,
            filterSTAR: e['filterSTAR'] ?? false,
            filterChiNext: e['filterChiNext'] ?? false,
          )).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveCurrentConfig() async {
    // 保存当前配置（最多3个，去重）
    final config = _config;
    _savedConfigs.removeWhere((c) =>
      c.strategy == config.strategy &&
      c.filterST == config.filterST &&
      c.filterSTAR == config.filterSTAR &&
      c.filterChiNext == config.filterChiNext);
    _savedConfigs.insert(0, config);
    if (_savedConfigs.length > 3) _savedConfigs = _savedConfigs.sublist(0, 3);

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(_savedConfigs.map((c) => {
      'strategy': c.strategy,
      'filterST': c.filterST,
      'filterSTAR': c.filterSTAR,
      'filterChiNext': c.filterChiNext,
    }).toList());
    await prefs.setString('saved_scan_configs', jsonStr);
    setState(() {});
  }

  Future<bool> _checkNetwork() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://quote.eastmoney.com/',
        'Accept': 'application/json, text/plain, */*',
      },
    ));
    // 用两个域名做降级检测
    final urls = [
      'https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=1&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fs=m:1+t:2&fields=f12',
      'https://push3.eastmoney.com/api/qt/clist/get?pn=1&pz=1&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fs=m:1+t:2&fields=f12',
    ];
    for (final url in urls) {
      try {
        final response = await dio.get(url);
        final data = response.data is String ? json.decode(response.data) : response.data;
        if (data['data'] != null) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<void> _loadHistory() async {
    final history = await _historyStorage.loadHistory();
    setState(() => _history = history);
  }

  Future<void> _startScan() async {
    // 网络检查
    final hasNetwork = await _checkNetwork();
    if (!hasNetwork && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络连接失败，请检查网络后重试'), backgroundColor: AppColors.down),
      );
      return;
    }

    // 保存当前配置
    await _saveCurrentConfig();

    setState(() {
      _status = ScanStatus.scanning;
      _currentProgress = 0;
      _totalStocks = 0;
      _results.clear();
    });

    try {
      final scanner = MarketScanner(
        repo: ref.read(marketRepositoryProvider),
        onProgress: (current, total, code) {
          setState(() {
            _currentProgress = current;
            _totalStocks = total;
            _currentCode = code;
          });
        },
      );

      final results = await scanner.scan(_config);

      setState(() {
        _results = results;
        _status = ScanStatus.completed;
      });

      // 保存扫描历史
      await _historyStorage.saveScan(results, _config);
      await _loadHistory();
    } catch (e) {
      setState(() => _status = ScanStatus.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e'), backgroundColor: AppColors.down),
        );
      }
    }
  }

  void _openChart(String code) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChartScreen(stockCode: code)));
  }

  void _addToWatchlist(ScanResult result) {
    final groups = ref.read(watchlistProvider);
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂无自选分组'), backgroundColor: AppColors.warning),
      );
      return;
    }
    // 添加到第一个分组
    final group = groups.first;
    final notifier = ref.read(watchlistProvider.notifier);
    if (group.codes.contains(result.code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} 已在自选中'), backgroundColor: AppColors.warning, duration: Duration(seconds: 1)),
      );
    } else {
      notifier.addStock(group.id, result.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${result.name} 到"${group.name}"'), backgroundColor: AppColors.up, duration: Duration(seconds: 1)),
      );
    }
  }

  /// 一键批量添加扫描结果到指定自选分组
  void _batchAddToWatchlist() {
    if (_results.isEmpty) return;
    final groups = ref.read(watchlistProvider);
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂无自选分组，请先创建'), backgroundColor: AppColors.warning),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('选择自选分组', style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('共 ${_results.length} 只', style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              ...groups.map((group) {
                final newCount = _results.where((r) => !group.codes.contains(r.code)).length;
                final dupCount = _results.length - newCount;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${group.codes.length}',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  title: Text(group.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    dupCount > 0 ? '新增 $newCount 只 · 已存在 $dupCount 只' : '新增 $newCount 只',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _doBatchAdd(group.id, group.name);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _doBatchAdd(String groupId, String groupName) {
    final notifier = ref.read(watchlistProvider.notifier);
    final groups = ref.read(watchlistProvider);
    final group = groups.firstWhere((g) => g.id == groupId, orElse: () => groups.first);

    int added = 0;
    int skipped = 0;
    for (final r in _results) {
      if (group.codes.contains(r.code)) {
        skipped++;
      } else {
        notifier.addStock(groupId, r.code);
        added++;
      }
    }

    String msg;
    Color color;
    if (added == 0) {
      msg = '全部已在"${groupName}"中';
      color = AppColors.warning;
    } else if (skipped > 0) {
      msg = '已添加 $added 只到"$groupName"，跳过 $skipped 只重复';
      color = AppColors.up;
    } else {
      msg = '已添加全部 $added 只到"$groupName"';
      color = AppColors.up;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: Duration(seconds: 2)),
    );
  }

  /// 导出扫描数据到 CSV 文件
  Future<void> _exportResults() async {
    if (_results.isEmpty) return;

    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'scan_${dateStr}_$timeStr.csv';

    // 构建 CSV 内容
    final sb = StringBuffer();
    sb.writeln('代码,名称,现价,涨跌幅%,信号,策略,胜率%,预期涨幅%');
    for (final r in _results) {
      sb.writeln('${r.code},${r.name},${r.price.toStringAsFixed(2)},'
          '${r.changePercent.toStringAsFixed(2)},${r.signal},${r.strategy},'
          '${r.winRate.toStringAsFixed(0)},${r.expectedRange.toStringAsFixed(1)}');
    }
    final csvContent = sb.toString();

    // 尝试写入文件
    String? savedPath;
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(csvContent, encoding: utf8);
        savedPath = file.path;
      }
    } catch (_) {}

    // 同时复制到剪贴板
    await Clipboard.setData(ClipboardData(text: csvContent));

    if (mounted) {
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 $fileName 到 Download 目录'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已复制 ${_results.length} 条数据到剪贴板（CSV格式）'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('开盘扫描选股'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
            tooltip: '扫描历史',
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildScanView(),
    );
  }

  Widget _buildScanView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScanButton(),
        const SizedBox(height: 16),
        _buildConfigSection(),
        const SizedBox(height: 16),
        if (_status == ScanStatus.scanning) _buildProgressCard(),
        if (_status == ScanStatus.error) _buildErrorCard(),
        if (_results.isNotEmpty) ...[
          _buildResultHeader(),
          const SizedBox(height: 8),
          ..._results.map((r) => _buildResultCard(r)),
        ],
        if (_status == ScanStatus.completed && _results.isEmpty) _buildEmptyResult(),
      ],
    );
  }

  Widget _buildScanButton() {
    final isScanning = _status == ScanStatus.scanning;
    final progress = _totalStocks > 0 ? _currentProgress / _totalStocks : 0.0;

    return GestureDetector(
      onTap: isScanning ? null : _startScan,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isScanning
                ? [AppColors.surface, AppColors.surface]
                : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (isScanning) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.background,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '扫描中 (${(_currentProgress / _totalStocks * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '正在分析 $_currentCode ($_currentProgress/$_totalStocks)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ] else ...[
              Icon(Icons.search, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text(
                '点击扫描今日潜力股',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '覆盖全市场A股，使用策略信号智能筛选',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showConfig = !_showConfig),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('扫描配置', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(_showConfig ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
              ],
            ),
          ),
          if (_showConfig) ...[
            const SizedBox(height: 16),
            _buildConfigOption('扫描策略', _config.strategy, {
              'all': '综合策略（全部）',
              'ma_cross': 'MA均线交叉',
              'kdj_cross': 'KDJ金叉',
              'rsi_oversold': 'RSI超卖反弹',
              'macd_cross': 'MACD金叉',
              'volume_break': '放量突破',
            }, (v) => setState(() => _config = ScanConfig(strategy: v!, filterST: _config.filterST, filterSTAR: _config.filterSTAR, filterChiNext: _config.filterChiNext))),
            const SizedBox(height: 8),
            _buildSwitchOption('过滤ST股票', _config.filterST, (v) => setState(() => _config = ScanConfig(strategy: _config.strategy, filterST: v, filterSTAR: _config.filterSTAR, filterChiNext: _config.filterChiNext))),
            _buildSwitchOption('过滤科创板(688)', _config.filterSTAR, (v) => setState(() => _config = ScanConfig(strategy: _config.strategy, filterST: _config.filterST, filterSTAR: v, filterChiNext: _config.filterChiNext))),
            _buildSwitchOption('过滤创业板(300)', _config.filterChiNext, (v) => setState(() => _config = ScanConfig(strategy: _config.strategy, filterST: _config.filterST, filterSTAR: _config.filterSTAR, filterChiNext: v))),
            if (_savedConfigs.isNotEmpty) ...[
              Divider(color: AppColors.divider, height: 24),
              Text('最近使用', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              ..._savedConfigs.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return GestureDetector(
                  onTap: () => setState(() => _config = c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _config == c ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: _config == c ? Border.all(color: AppColors.primary, width: 0.5) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('${_getStrategyName(c.strategy)} ${c.filterST ? '·过滤ST' : ''}',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildConfigOption(String label, String value, Map<String, String> options, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          underline: const SizedBox.shrink(),
          items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchOption(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('扫描进度', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  value: _totalStocks > 0 ? _currentProgress / _totalStocks : 0,
                  strokeWidth: 4,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已扫描 $_currentProgress / $_totalStocks',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('发现 ${_results.length} 只潜力股',
                      style: TextStyle(color: AppColors.up, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.down.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.down.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.down),
          const SizedBox(width: 12),
          Expanded(
            child: Text('扫描失败，请检查网络后重试', style: TextStyle(color: AppColors.down)),
          ),
          TextButton(
            onPressed: _startScan,
            child: const Text('重试', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: AppColors.up, size: 20),
            const SizedBox(width: 8),
            Text('扫描结果 (${_results.length}只)',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('按胜率排序',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _batchAddToWatchlist,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('一键加自选'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportResults,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('导出数据'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResultCard(ScanResult result) {
    return GestureDetector(
      onTap: () => _openChart(result.code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.name,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(result.code.toUpperCase(),
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(result.price.toStringAsFixed(2),
                      style: TextStyle(
                        color: result.changePercent >= 0 ? AppColors.up : AppColors.down,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '${result.changePercent >= 0 ? '+' : ''}${result.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: result.changePercent >= 0 ? AppColors.up : AppColors.down,
                        fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(result.signal,
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniMetric('策略', result.strategy),
                const SizedBox(width: 12),
                _buildMiniMetric('胜率', '${result.winRate.toStringAsFixed(0)}%'),
                const SizedBox(width: 12),
                _buildMiniMetric('预期涨幅', '${result.expectedRange.toStringAsFixed(1)}%'),
                const Spacer(),
                GestureDetector(
                  onTap: () => _addToWatchlist(result),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('+ 自选', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyResult() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, color: AppColors.textSecondary.withOpacity(0.5), size: 64),
          const SizedBox(height: 16),
          Text('当前策略下未筛选到符合条件的个股',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Text('可尝试切换策略或放宽过滤条件',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          // 一键放宽条件
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _config = const ScanConfig(); // 恢复默认（全部策略，不过滤）
                _showConfig = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已恢复默认配置，点击扫描重试'), backgroundColor: AppColors.primary),
              );
            },
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('一键放宽条件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          // 策略推荐
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('推荐策略', style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStrategyRecommendation('MA均线交叉', '适合趋势行情，捕捉中期拐点'),
                _buildStrategyRecommendation('KDJ金叉', '适合震荡行情，短线反弹信号'),
                _buildStrategyRecommendation('放量突破', '适合突破行情，关注成交量变化'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyRecommendation(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 14),
          const SizedBox(width: 6),
          Text(name, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(child: Text(desc, style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
        ],
      ),
    );
  }

  int? _expandedHistoryIndex;

  Widget _buildHistoryView() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: AppColors.textSecondary.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text('暂无扫描历史', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text('完成一次扫描后，历史记录会显示在这里',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, index) => _buildHistoryItem(index),
    );
  }

  Widget _buildHistoryItem(int index) {
    final record = _history[index];
    final scanTime = DateTime.tryParse(record['scanTime'] ?? '') ?? DateTime.now();
    final resultCount = record['resultCount'] ?? 0;
    final strategy = record['strategy'] ?? 'all';
    final isExpanded = _expandedHistoryIndex == index;

    // 解析结果列表
    final resultsList = (record['results'] as List?)?.map((r) {
      try { return ScanResult.fromJson(r as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<ScanResult>().toList() ?? [];

    // 状态判定
    final status = _getHistoryStatus(resultCount, scanTime);
    final statusColor = status.$2;
    final statusIcon = status.$3;

    return GestureDetector(
      onTap: () => setState(() => _expandedHistoryIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isExpanded ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${scanTime.month}/${scanTime.day} ${scanTime.hour.toString().padLeft(2, '0')}:${scanTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(status.$1, style: TextStyle(color: statusColor, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_getStrategyName(strategy),
                      style: TextStyle(color: AppColors.primary, fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),

            // 展开内容
            if (isExpanded) ...[
              Divider(color: AppColors.divider, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 结果摘要
                    if (resultsList.isNotEmpty) ...[
                      Text('扫描结果 (${resultsList.length}只)',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...resultsList.take(5).map((r) => _buildHistoryResultRow(r)),
                      if (resultsList.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('... 还有 ${resultsList.length - 5} 只',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ),
                    ] else
                      Text('无详细结果数据',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),

                    const SizedBox(height: 12),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reuseConfig(strategy),
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text('复用此策略'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteHistory(index),
                          icon: Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
                          tooltip: '删除记录',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 返回 (状态文字, 颜色, 图标)
  (String, Color, IconData) _getHistoryStatus(int resultCount, DateTime scanTime) {
    if (resultCount == 0) {
      return ('无符合条件股', AppColors.textSecondary, Icons.search_off);
    }
    if (resultCount >= 10) {
      return ('发现 $resultCount 只 · 热门有效策略', AppColors.success, Icons.local_fire_department);
    }
    return ('发现 $resultCount 只潜力股', AppColors.up, Icons.check_circle_outline);
  }

  Widget _buildHistoryResultRow(ScanResult r) {
    final color = r.changePercent >= 0 ? AppColors.up : AppColors.down;
    return GestureDetector(
      onTap: () => _openChart(r.code),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(r.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text(r.signal, style: TextStyle(color: AppColors.primary, fontSize: 10)),
            ),
            Text('${r.changePercent >= 0 ? '+' : ''}${r.changePercent.toStringAsFixed(2)}%',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _reuseConfig(String strategy) {
    setState(() {
      _config = ScanConfig(
        strategy: strategy,
        filterST: _config.filterST,
        filterSTAR: _config.filterSTAR,
        filterChiNext: _config.filterChiNext,
      );
      _showHistory = false;
      _showConfig = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已加载策略: ${_getStrategyName(strategy)}，点击扫描执行'), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _deleteHistory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setString('scan_history', json.encode(_history));
    setState(() => _expandedHistoryIndex = null);
  }

  String _getStrategyName(String strategy) {
    switch (strategy) {
      case 'all': return '综合策略';
      case 'ma_cross': return 'MA均线';
      case 'kdj_cross': return 'KDJ金叉';
      case 'rsi_oversold': return 'RSI超卖';
      case 'macd_cross': return 'MACD金叉';
      case 'volume_break': return '放量突破';
      default: return strategy;
    }
  }
}
