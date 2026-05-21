import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/backtest_result.dart';
import '../../data/datasources/search_api.dart';
import '../../domain/services/backtest_engine.dart';
import '../providers/market_provider.dart';
import '../providers/indicator_params_provider.dart';
import '../widgets/common/error_widget.dart';
import '../../app/theme.dart';

class StrategyScreen extends ConsumerStatefulWidget {
  const StrategyScreen({super.key});

  @override
  ConsumerState<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends ConsumerState<StrategyScreen> {
  String _selectedStrategy = 'ma_cross';
  BacktestResult? _result;
  bool _isRunning = false;
  String? _error;
  String _loadingStatus = '';
  final _codeController = TextEditingController(text: 'sh600519');

  // 可调参数
  double _commissionRate = 0.0003;
  double _slippage = 0.001;
  double _stopLoss = 0.08;
  double _takeProfit = 0.20;
  bool _showParams = false;

  // 策略对比
  bool _compareMode = false;
  final Set<String> _compareStrategies = {};
  final Map<String, BacktestResult> _compareResults = {};

  // 搜索联想
  final _searchApi = SearchApi();
  List<SearchResult> _suggestions = [];
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  static const _strategies = [
    ('buy_hold', '买入持有', '第1天买入持有到最后一天，基准策略'),
    ('ma_cross', '均线交叉', 'MA5 上穿 MA20 买入，下穿卖出'),
    ('macd_cross', 'MACD 金叉', 'DIF 上穿 DEA 买入，下穿卖出'),
    ('kdj_cross', 'KDJ 金叉', 'K 上穿 D 且 J<50 买入，J>80 卖出'),
    ('rsi_oversold', 'RSI 超卖反弹', 'RSI 从下方突破30买入，从上方跌破70卖出'),
    ('boll_bounce', '布林带反弹', '触及下轨买入，触及上轨卖出'),
    ('ensemble', '多信号共振', '至少3个指标同时发出信号才交易'),
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length < 2) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _searchApi.search(value.trim());
      if (mounted) {
        setState(() {
          _suggestions = results.take(5).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    });
  }

  void _selectSuggestion(SearchResult result) {
    _codeController.text = result.code;
    setState(() { _showSuggestions = false; _suggestions = []; });
    _runBacktest();
  }

  String _normalizeCode(String input) {
    final code = input.trim().toLowerCase();
    if (RegExp(r'^(sh|sz)\d{6}$').hasMatch(code)) return code;
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      return code.startsWith('6') ? 'sh$code' : 'sz$code';
    }
    return code;
  }

  Future<void> _runBacktest() async {
    setState(() {
      _isRunning = true;
      _error = null;
      _result = null;
      _loadingStatus = '正在获取回测数据...';
    });

    final code = _normalizeCode(_codeController.text);
    if (!RegExp(r'^(sh|sz)\d{6}$').hasMatch(code)) {
      setState(() { _error = '请输入有效的股票代码'; _isRunning = false; });
      return;
    }
    _codeController.text = code;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        setState(() => _loadingStatus = '正在获取回测数据... (第$attempt次尝试)');

        final repo = ref.read(marketRepositoryProvider);
        final results = await Future.wait([
          repo.getKline(code: code, period: 'day', count: 250),
          repo.getKline(code: 'sh000001', period: 'day', count: 250),
        ]);

        final klines = results[0];
        final benchmarkKlines = results[1];

        if (klines.length < 60) throw Exception('数据不足，需要至少60根K线');

        setState(() => _loadingStatus = '正在运行回测引擎...');

        final params = ref.read(indicatorParamsProvider);
        final engine = BacktestEngine();

        final result = engine.run(
          klines: klines,
          strategy: _selectedStrategy,
          params: params,
          commissionRate: _commissionRate,
          slippage: _slippage,
          stopLoss: _stopLoss,
          takeProfit: _takeProfit,
          benchmarkKlines: benchmarkKlines,
        );

        if (mounted) {
          setState(() { _result = result; _isRunning = false; });
        }
        return;
      } catch (e) {
        if (attempt >= 3) {
          if (mounted) {
            setState(() {
              _error = '数据加载失败（已重试$attempt次）：${e.toString()}';
              _isRunning = false;
            });
          }
          return;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  Future<void> _runCompare() async {
    if (_compareStrategies.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请至少选择2个策略'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
      _compareResults.clear();
      _loadingStatus = '正在获取数据...';
    });

    final code = _normalizeCode(_codeController.text);
    if (!RegExp(r'^(sh|sz)\d{6}$').hasMatch(code)) {
      setState(() { _error = '请输入有效的股票代码'; _isRunning = false; });
      return;
    }

    try {
      final repo = ref.read(marketRepositoryProvider);
      final results = await Future.wait([
        repo.getKline(code: code, period: 'day', count: 250),
        repo.getKline(code: 'sh000001', period: 'day', count: 250),
      ]);

      final klines = results[0];
      final benchmarkKlines = results[1];

      if (klines.length < 60) throw Exception('数据不足');

      final params = ref.read(indicatorParamsProvider);
      final engine = BacktestEngine();

      for (final strategy in _compareStrategies) {
        setState(() => _loadingStatus = '正在回测: ${_strategyName(strategy)}...');
        final result = engine.run(
          klines: klines,
          strategy: strategy,
          params: params,
          commissionRate: _commissionRate,
          slippage: _slippage,
          stopLoss: _stopLoss,
          takeProfit: _takeProfit,
          benchmarkKlines: benchmarkKlines,
        );
        _compareResults[strategy] = result;
      }

      if (mounted) {
        setState(() { _isRunning = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isRunning = false; });
      }
    }
  }

  String _strategyName(String key) {
    for (final s in _strategies) {
      if (s.$1 == key) return s.$2;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('策略回测'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputSection(),
          const SizedBox(height: 16),
          _buildStrategySelector(),
          const SizedBox(height: 12),
          _buildParamsToggle(),
          const SizedBox(height: 12),
          _buildCompareToggle(),
          const SizedBox(height: 16),
          if (_isRunning) _buildLoading(),
          if (_error != null) AppErrorWidget(message: _error!, onRetry: _compareMode ? _runCompare : _runBacktest),
          if (!_compareMode && _result != null) ...[
            _buildResultCard(_result!),
            const SizedBox(height: 12),
            _buildTradeLogCard(_result!),
          ],
          if (_compareMode && _compareResults.isNotEmpty) _buildCompareCard(),
        ],
      ),
    );
  }

  // ── 输入区 ──

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('回测参数',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Column(
            children: [
              TextField(
                controller: _codeController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '输入代码或名称 (如 600519 / 茅台)',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _compareMode ? _runCompare() : _runBacktest(),
              ),
              if (_showSuggestions) _buildSuggestionsList(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRunning ? null : (_compareMode ? _runCompare : _runBacktest),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isRunning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_compareMode ? '运行策略对比' : '运行回测'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _suggestions.map((s) => ListTile(
          dense: true,
          title: Text(s.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          subtitle: Text(s.code.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          onTap: () => _selectSuggestion(s),
        )).toList(),
      ),
    );
  }

  // ── 策略选择器 ──

  Widget _buildStrategySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_compareMode ? '选择要对比的策略（至少2个）' : '选择策略',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._strategies.map((s) {
            if (_compareMode) {
              return CheckboxListTile(
                value: _compareStrategies.contains(s.$1),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _compareStrategies.add(s.$1);
                    } else {
                      _compareStrategies.remove(s.$1);
                    }
                  });
                },
                title: Text(s.$2, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text(s.$3, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                activeColor: AppColors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }
            return RadioListTile<String>(
              value: s.$1,
              groupValue: _selectedStrategy,
              onChanged: (v) => setState(() => _selectedStrategy = v!),
              title: Text(s.$2, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text(s.$3, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              activeColor: AppColors.primary,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }

  // ── 参数调节 ──

  Widget _buildParamsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showParams = !_showParams),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('回测参数调节', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(_showParams ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
            if (_showParams) ...[
              const SizedBox(height: 12),
              _buildSlider('手续费率', _commissionRate, 0.0001, 0.003,
                  (v) => setState(() => _commissionRate = v), '${(_commissionRate * 10000).toStringAsFixed(1)}‱'),
              _buildSlider('滑点', _slippage, 0.0, 0.005,
                  (v) => setState(() => _slippage = v), '${(_slippage * 100).toStringAsFixed(2)}%'),
              _buildSlider('止损线', _stopLoss, 0.02, 0.20,
                  (v) => setState(() => _stopLoss = v), '${(_stopLoss * 100).toStringAsFixed(0)}%'),
              _buildSlider('止盈线', _takeProfit, 0.05, 0.50,
                  (v) => setState(() => _takeProfit = v), '${(_takeProfit * 100).toStringAsFixed(0)}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String display) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.divider,
            ),
          ),
          SizedBox(width: 50, child: Text(display,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ── 对比模式开关 ──

  Widget _buildCompareToggle() {
    return GestureDetector(
      onTap: () => setState(() {
        _compareMode = !_compareMode;
        if (!_compareMode) {
          _compareStrategies.clear();
          _compareResults.clear();
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _compareMode ? AppColors.primary.withOpacity(0.1) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: _compareMode ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.compare_arrows, color: _compareMode ? AppColors.primary : AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('策略对比模式',
                  style: TextStyle(color: _compareMode ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Switch(
              value: _compareMode,
              onChanged: (v) => setState(() {
                _compareMode = v;
                if (!v) { _compareStrategies.clear(); _compareResults.clear(); }
              }),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ── 加载中 ──

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(_loadingStatus, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── 单策略结果卡片 ──

  Widget _buildResultCard(BacktestResult result) {
    final returnColor = result.totalReturn >= 0 ? AppColors.up : AppColors.down;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('回测结果', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_strategyName(result.strategy),
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 核心指标 2x2
          Row(
            children: [
              _buildMetric('总收益率', '${result.totalReturn.toStringAsFixed(2)}%', returnColor),
              _buildMetric('年化收益', '${result.annualizedReturn.toStringAsFixed(2)}%',
                  result.annualizedReturn >= 0 ? AppColors.up : AppColors.down),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('最大回撤', '${result.maxDrawdown.toStringAsFixed(2)}%', AppColors.down),
              _buildMetric('Sharpe', result.sharpeRatio.toStringAsFixed(2),
                  result.sharpeRatio >= 1 ? AppColors.up : (result.sharpeRatio >= 0 ? AppColors.textPrimary : AppColors.down)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('交易次数', '${result.tradeCount}', AppColors.textPrimary),
              _buildMetric('胜率', '${result.winRate.toStringAsFixed(1)}%',
                  result.winRate >= 50 ? AppColors.up : AppColors.down),
            ],
          ),

          // 基准对比
          if (result.benchmarkReturn != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetric('基准收益', '${result.benchmarkReturn!.toStringAsFixed(2)}%',
                    result.benchmarkReturn! >= 0 ? AppColors.up : AppColors.down),
                _buildMetric('超额收益', '${result.alpha!.toStringAsFixed(2)}%',
                    result.alpha! >= 0 ? AppColors.up : AppColors.down),
              ],
            ),
          ],

          // 展开更多指标
          const SizedBox(height: 12),
          _buildExpandedMetrics(result),

          const SizedBox(height: 16),
          if (result.equityCurve.length > 1) _buildEquityCurve(result),
        ],
      ),
    );
  }

  Widget _buildExpandedMetrics(BacktestResult result) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Text('更多指标', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildMiniMetric('利润因子', result.profitFactor.toStringAsFixed(2)),
              _buildMiniMetric('平均盈利', '${result.avgWin.toStringAsFixed(2)}%'),
              _buildMiniMetric('平均亏损', '${result.avgLoss.toStringAsFixed(2)}%'),
              _buildMiniMetric('最大盈利', '${result.maxWin.toStringAsFixed(2)}%'),
              _buildMiniMetric('最大亏损', '${result.maxLoss.toStringAsFixed(2)}%'),
              _buildMiniMetric('平均持仓', '${result.avgHoldingDays.toStringAsFixed(1)}天'),
              _buildMiniMetric('回撤持续', '${result.maxDrawdownDuration}天'),
              _buildMiniMetric('手续费', result.totalCommission.toStringAsFixed(0)),
              _buildMiniMetric('滑点成本', result.totalSlippage.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  // ── 交易日志卡片 ──

  Widget _buildTradeLogCard(BacktestResult result) {
    if (result.tradeLog.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('无交易记录', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('交易日志 (${result.tradeLog.length}笔)',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          children: [
            // 表头
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _logHeader('买入', 2),
                  _logHeader('卖出', 2),
                  _logHeader('仓位', 1),
                  _logHeader('盈亏额', 1),
                  _logHeader('盈亏%', 1),
                  _logHeader('信号', 1),
                ],
              ),
            ),
            Divider(color: AppColors.divider, height: 1),
            ...result.tradeLog.map((t) => _buildTradeRow(t)),
          ],
        ),
      ),
    );
  }

  Widget _logHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTradeRow(TradeLogEntry t) {
    final color = t.isWin ? AppColors.up : AppColors.down;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(
            '${t.entryDate.month}/${t.entryDate.day}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
          Expanded(flex: 2, child: Text(
            '${t.exitDate.month}/${t.exitDate.day}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
          Expanded(child: Text(_formatMoney(t.investedCapital),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 11))),
          Expanded(child: Text('${t.pnl >= 0 ? '+' : ''}${_formatMoney(t.pnl)}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(child: Text('${(t.pnlPercent * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(child: Text(t.exitSignal,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10))),
        ],
      ),
    );
  }

  String _formatMoney(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return v.toStringAsFixed(0);
  }

  // ── 策略对比卡片 ──

  Widget _buildCompareCard() {
    // 按总收益排序
    final sorted = _compareResults.entries.toList()
      ..sort((a, b) => b.value.totalReturn.compareTo(a.value.totalReturn));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('策略对比结果',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 对比表格
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              columns: [
                DataColumn(label: Text('策略')),
                DataColumn(label: Text('总收益'), numeric: true),
                DataColumn(label: Text('年化'), numeric: true),
                DataColumn(label: Text('回撤'), numeric: true),
                DataColumn(label: Text('Sharpe'), numeric: true),
                DataColumn(label: Text('胜率'), numeric: true),
                DataColumn(label: Text('交易数'), numeric: true),
              ],
              rows: sorted.map((e) {
                final r = e.value;
                final isBest = e == sorted.first;
                return DataRow(
                  color: isBest ? WidgetStateProperty.all(AppColors.up.withOpacity(0.08)) : null,
                  cells: [
                    DataCell(Text(_strategyName(e.key),
                        style: TextStyle(fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12))),
                    DataCell(Text('${r.totalReturn.toStringAsFixed(1)}%',
                        style: TextStyle(color: r.totalReturn >= 0 ? AppColors.up : AppColors.down,
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('${r.annualizedReturn.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12))),
                    DataCell(Text('${r.maxDrawdown.toStringAsFixed(1)}%',
                        style: TextStyle(color: AppColors.down, fontSize: 12))),
                    DataCell(Text(r.sharpeRatio.toStringAsFixed(2), style: TextStyle(fontSize: 12))),
                    DataCell(Text('${r.winRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12))),
                    DataCell(Text('${r.tradeCount}', style: TextStyle(fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          ),

          // 对比权益曲线
          if (sorted.isNotEmpty && sorted.first.value.equityCurve.length > 1) ...[
            const SizedBox(height: 16),
            Text('权益曲线对比', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: Size.infinite,
                painter: _CompareCurvePainter(
                  results: sorted.map((e) => (e.key, e.value)).toList(),
                  colors: [AppColors.primary, AppColors.ma5, AppColors.up, AppColors.warning, AppColors.down],
                ),
              ),
            ),
            // 图例
            Wrap(
              spacing: 12,
              children: sorted.asMap().entries.map((e) {
                final colors = [AppColors.primary, AppColors.ma5, AppColors.up, AppColors.warning, AppColors.down];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 2, color: colors[e.key % colors.length]),
                    const SizedBox(width: 4),
                    Text(_strategyName(e.value.key), style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── 通用指标 ──

  Widget _buildMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ── 权益曲线 ──

  Widget _buildEquityCurve(BacktestResult result) {
    final curve = result.equityCurve;
    final benchCurve = result.benchmarkCurve;

    double minVal = curve.reduce((a, b) => a < b ? a : b);
    double maxVal = curve.reduce((a, b) => a > b ? a : b);
    if (benchCurve != null) {
      for (final v in benchCurve) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }
    final range = maxVal - minVal;

    final initialCapital = curve.first;
    final finalCapital = curve.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('资金曲线', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Container(width: 12, height: 2, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('策略', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            if (benchCurve != null) ...[
              const SizedBox(width: 8),
              Container(width: 12, height: 2, color: AppColors.ma5),
              const SizedBox(width: 4),
              Text('基准(上证)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('初始: ${initialCapital.toStringAsFixed(0)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(width: 8),
            Text('最终: ${finalCapital.toStringAsFixed(0)}',
                style: TextStyle(
                  color: finalCapital >= initialCapital ? AppColors.up : AppColors.down,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: CustomPaint(
            size: Size.infinite,
            painter: _EquityCurvePainter(
              curve: curve,
              benchmarkCurve: benchCurve,
              minVal: minVal,
              range: range,
              initialCapital: initialCapital,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 单策略权益曲线 Painter ──

class _EquityCurvePainter extends CustomPainter {
  final List<double> curve;
  final List<double>? benchmarkCurve;
  final double minVal;
  final double range;
  final double initialCapital;

  _EquityCurvePainter({
    required this.curve,
    this.benchmarkCurve,
    required this.minVal,
    required this.range,
    required this.initialCapital,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.length < 2) return;

    final padding = const EdgeInsets.only(left: 40, right: 8, top: 8, bottom: 20);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    _drawGrid(canvas, size, padding, chartWidth, chartHeight);

    // 初始资金参考线
    final initialY = padding.top + chartHeight * (1 - (initialCapital - minVal) / range);
    final dashPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.3)
      ..strokeWidth = 0.5;
    _drawDashedLine(canvas, Offset(padding.left, initialY), Offset(size.width - padding.right, initialY), dashPaint);

    // 资金曲线
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < curve.length; i++) {
      final x = padding.left + i / (curve.length - 1) * chartWidth;
      final y = padding.top + chartHeight * (1 - (curve[i] - minVal) / range);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // 填充
    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    final fillPath = Path.from(path);
    fillPath.lineTo(padding.left + chartWidth, padding.top + chartHeight);
    fillPath.lineTo(padding.left, padding.top + chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // 基准曲线
    if (benchmarkCurve != null && benchmarkCurve!.length > 1) {
      final benchPaint = Paint()
        ..color = AppColors.ma5
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final benchPath = Path();
      for (int i = 0; i < benchmarkCurve!.length; i++) {
        final x = padding.left + i / (benchmarkCurve!.length - 1) * chartWidth;
        final y = padding.top + chartHeight * (1 - (benchmarkCurve![i] - minVal) / range);
        if (i == 0) benchPath.moveTo(x, y);
        else benchPath.lineTo(x, y);
      }
      canvas.drawPath(benchPath, benchPaint);
    }
  }

  void _drawGrid(Canvas canvas, Size size, EdgeInsets padding, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 3; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);

      final value = minVal + range * (1 - i / 4);
      final label = value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : value.toStringAsFixed(0);
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(padding.left - textPainter.width - 4, y - textPainter.height / 2));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    final steps = length / (dashWidth + dashSpace);

    for (int i = 0; i < steps; i++) {
      final startOffset = Offset(start.dx + dx * i / steps, start.dy + dy * i / steps);
      final endOffset = Offset(start.dx + dx * (i + 0.5) / steps, start.dy + dy * (i + 0.5) / steps);
      canvas.drawLine(startOffset, endOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EquityCurvePainter oldDelegate) {
    return oldDelegate.curve != curve || oldDelegate.benchmarkCurve != benchmarkCurve;
  }
}

// ── 多策略对比曲线 Painter ──

class _CompareCurvePainter extends CustomPainter {
  final List<(String, BacktestResult)> results;
  final List<Color> colors;

  _CompareCurvePainter({required this.results, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    final padding = const EdgeInsets.only(left: 40, right: 8, top: 8, bottom: 20);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    // 计算全局 min/max
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final (_, r) in results) {
      for (final v in r.equityCurve) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }
    final range = maxVal - minVal;
    if (range == 0) return;

    // 网格
    final gridPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 3; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);

      final value = minVal + range * (1 - i / 4);
      final label = value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : value.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding.left - tp.width - 4, y - tp.height / 2));
    }

    // 绘制各策略曲线
    for (int idx = 0; idx < results.length; idx++) {
      final curve = results[idx].$2.equityCurve;
      if (curve.length < 2) continue;

      final linePaint = Paint()
        ..color = colors[idx % colors.length]
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < curve.length; i++) {
        final x = padding.left + i / (curve.length - 1) * chartWidth;
        final y = padding.top + chartHeight * (1 - (curve[i] - minVal) / range);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompareCurvePainter oldDelegate) {
    return oldDelegate.results != results;
  }
}
