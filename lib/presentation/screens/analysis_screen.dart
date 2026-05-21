import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/kline_data.dart';
import '../../data/models/indicator_data.dart';
import '../../data/models/pattern_result.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ai_data.dart';
import '../../data/models/ai_report.dart';
import '../../data/datasources/local/ai_history_storage.dart';
import '../widgets/markdown_card.dart';
import '../../data/models/sentiment_data.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/datasources/fund_flow_api.dart';
import '../../domain/services/indicator_calculator.dart';
import '../../domain/services/pattern_detector.dart';
import '../../app/theme.dart';
import '../providers/settings_provider.dart';
import 'ai_chat_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final String stockCode;
  final String stockName;
  final List<KlineData> klines;
  final IndicatorData indicators;

  const AnalysisScreen({
    super.key,
    required this.stockCode,
    required this.stockName,
    required this.klines,
    required this.indicators,
  });

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late List<PatternResult> _patterns;
  EmAiApi? _aiApi;
  AiDiagnosisResult? _aiResult;
  bool _aiLoading = false;

  String _deepAnalysisMarkdown = '';
  bool _deepAnalysisLoading = false;

  List<FundFlowDetail> _fundFlowData = [];
  bool _fundFlowLoading = false;

  @override
  void initState() {
    super.initState();
    _patterns = PatternDetector().detectAll(widget.klines);
    _loadFundFlow();
  }

  Future<void> _loadFundFlow() async {
    setState(() => _fundFlowLoading = true);
    try {
      final api = FundFlowApi();
      final data = await api.getStockFundFlow(widget.stockCode, days: 10);
      if (mounted) setState(() => _fundFlowData = data);
    } catch (_) {}
    if (mounted) setState(() => _fundFlowLoading = false);
  }

  EmAiApi _getApi() {
    if (_aiApi == null) {
      final settings = ref.read(settingsProvider);
      _aiApi = EmAiApi(apiKey: settings.emApiKey);
    } else {
      final settings = ref.read(settingsProvider);
      _aiApi!.updateApiKey(settings.emApiKey);
    }
    return _aiApi!;
  }

  Future<void> _runAiDiagnosis() async {
    setState(() => _aiLoading = true);
    try {
      final api = _getApi();
      final result = await api.diagnose(widget.stockCode);
      setState(() {
        _aiResult = result;
        _aiLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiResult = AiDiagnosisResult(
          code: widget.stockCode,
          name: widget.stockName,
          summary: '诊断失败: $e',
          suggestion: '请稍后重试',
          riskLevel: '未知',
        );
        _aiLoading = false;
      });
    }
  }

  Future<void> _runDeepAnalysis() async {
    setState(() => _deepAnalysisLoading = true);
    AppLog.instance.info('DeepAnalysis', '开始深度分析: ${widget.stockName}');
    try {
      final api = _getApi();
      final result = await api.getStockAnalysis('${widget.stockName}值得持有吗');
      AppLog.instance.info('DeepAnalysis', '深度分析完成: ${widget.stockName}, 结果长度=${result.length}');
      if (mounted) {
        setState(() {
          _deepAnalysisMarkdown = result;
          _deepAnalysisLoading = false;
        });
        // 保存到历史
        final storage = AiHistoryStorage();
        await storage.saveRecord(AiQueryRecord(
          id: const Uuid().v4(),
          type: 'diagnosis',
          query: '${widget.stockName} 深度分析',
          resultMarkdown: result,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLog.instance.error('DeepAnalysis', '深度分析失败: $e');
      if (mounted) {
        setState(() {
          _deepAnalysisMarkdown = '深度分析失败: $e';
          _deepAnalysisLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final klines = widget.klines;
    final indicators = widget.indicators;
    final lastIndex = klines.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.stockName} 技术分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_patterns.isNotEmpty) _buildPatternAnalysis(),
          _buildMAAnalysis(indicators, lastIndex),
          _buildMACDAnalysis(indicators, lastIndex),
          _buildKDJAnalysis(indicators, lastIndex),
          _buildRSIAnalysis(indicators, lastIndex),
          _buildBOLLAnalysis(indicators, klines, lastIndex),
          _buildVolumeAnalysis(klines, lastIndex),
          _buildOverallSummary(indicators, klines, lastIndex),
          _buildFundFlowCard(),
          _buildAiDiagnosis(),
        ],
      ),
    );
  }

  // MA 均线分析
  Widget _buildMAAnalysis(IndicatorData indicators, int lastIndex) {
    final ma5 = indicators.maLines[0][lastIndex];
    final ma10 = indicators.maLines[1][lastIndex];
    final ma20 = indicators.maLines[2][lastIndex];
    final ma60 = indicators.maLines.length > 3 ? indicators.maLines[3][lastIndex] : 0.0;

    // 判断多头/空头排列
    bool isBullishAlignment = ma5 > ma10 && ma10 > ma20;
    bool isBearishAlignment = ma5 < ma10 && ma10 < ma20;

    // 判断金叉/死叉
    String signal = '';
    Color signalColor = AppColors.textSecondary;

    if (isBullishAlignment) {
      signal = '多头排列 - 看涨信号';
      signalColor = AppColors.up;
    } else if (isBearishAlignment) {
      signal = '空头排列 - 看跌信号';
      signalColor = AppColors.down;
    } else {
      signal = '均线交织 - 震荡格局';
    }

    return _buildAnalysisCard(
      title: 'MA 均线分析',
      icon: Icons.show_chart,
      children: [
        _buildIndicatorRow('MA5', ma5, AppColors.ma5),
        _buildIndicatorRow('MA10', ma10, AppColors.ma10),
        _buildIndicatorRow('MA20', ma20, AppColors.ma20),
        if (ma60 > 0) _buildIndicatorRow('MA60', ma60, AppColors.ma60),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // MACD 分析
  Widget _buildMACDAnalysis(IndicatorData indicators, int lastIndex) {
    final dif = indicators.dif[lastIndex];
    final dea = indicators.dea[lastIndex];
    final hist = indicators.macdHist[lastIndex];

    // 金叉/死叉
    String signal = '';
    Color signalColor = AppColors.textSecondary;

    if (lastIndex > 0) {
      final prevDif = indicators.dif[lastIndex - 1];
      final prevDea = indicators.dea[lastIndex - 1];

      if (prevDif < prevDea && dif >= dea) {
        signal = '金叉 - 买入信号';
        signalColor = AppColors.up;
      } else if (prevDif > prevDea && dif <= dea) {
        signal = '死叉 - 卖出信号';
        signalColor = AppColors.down;
      } else if (dif > dea && hist > 0) {
        signal = '多头 - 持有';
        signalColor = AppColors.up;
      } else if (dif < dea && hist < 0) {
        signal = '空头 - 观望';
        signalColor = AppColors.down;
      } else {
        signal = '观望 - 等待信号';
      }
    }

    return _buildAnalysisCard(
      title: 'MACD 分析',
      icon: Icons.analytics,
      children: [
        _buildIndicatorRow('DIF', dif, AppColors.macdDif),
        _buildIndicatorRow('DEA', dea, AppColors.macdDea),
        _buildIndicatorRow('MACD柱', hist, hist >= 0 ? AppColors.up : AppColors.down),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // KDJ 分析
  Widget _buildKDJAnalysis(IndicatorData indicators, int lastIndex) {
    final k = indicators.k[lastIndex];
    final d = indicators.d[lastIndex];
    final j = indicators.j[lastIndex];

    String signal = '';
    Color signalColor = AppColors.textSecondary;

    // 超买超卖判断
    if (j > 100) {
      signal = '超买区域 - 注意回调风险';
      signalColor = AppColors.down;
    } else if (j < 0) {
      signal = '超卖区域 - 可能反弹';
      signalColor = AppColors.up;
    } else if (k > d && k > 80) {
      signal = '高位钝化 - 注意风险';
      signalColor = AppColors.down;
    } else if (k < d && k < 20) {
      signal = '低位钝化 - 关注机会';
      signalColor = AppColors.up;
    } else {
      signal = '正常区域';
    }

    // 金叉/死叉
    if (lastIndex > 0) {
      final prevK = indicators.k[lastIndex - 1];
      final prevD = indicators.d[lastIndex - 1];
      if (prevK < prevD && k >= d) {
        signal = '金叉 - 买入信号';
        signalColor = AppColors.up;
      } else if (prevK > prevD && k <= d) {
        signal = '死叉 - 卖出信号';
        signalColor = AppColors.down;
      }
    }

    return _buildAnalysisCard(
      title: 'KDJ 分析',
      icon: Icons.speed,
      children: [
        _buildIndicatorRow('K值', k, AppColors.kdjK),
        _buildIndicatorRow('D值', d, AppColors.kdjD),
        _buildIndicatorRow('J值', j, AppColors.kdjJ),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // RSI 分析
  Widget _buildRSIAnalysis(IndicatorData indicators, int lastIndex) {
    final rsi = indicators.rsi[lastIndex];

    String signal = '';
    Color signalColor = AppColors.textSecondary;

    if (rsi > 80) {
      signal = '超买 - 注意回调风险';
      signalColor = AppColors.down;
    } else if (rsi > 70) {
      signal = '偏强 - 可能回调';
      signalColor = AppColors.down;
    } else if (rsi < 20) {
      signal = '超卖 - 可能反弹';
      signalColor = AppColors.up;
    } else if (rsi < 30) {
      signal = '偏弱 - 可能反弹';
      signalColor = AppColors.up;
    } else if (rsi > 50) {
      signal = '多方占优';
      signalColor = AppColors.up;
    } else if (rsi < 50) {
      signal = '空方占优';
      signalColor = AppColors.down;
    } else {
      signal = '多空平衡';
    }

    return _buildAnalysisCard(
      title: 'RSI 分析',
      icon: Icons.trending_up,
      children: [
        _buildIndicatorRow('RSI(14)', rsi, rsi > 50 ? AppColors.up : AppColors.down),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // BOLL 分析
  Widget _buildBOLLAnalysis(IndicatorData indicators, List<KlineData> klines, int lastIndex) {
    final mid = indicators.bollMid[lastIndex];
    final upper = indicators.bollUpper[lastIndex];
    final lower = indicators.bollLower[lastIndex];
    final close = klines[lastIndex].close;

    String signal = '';
    Color signalColor = AppColors.textSecondary;

    if (close > upper) {
      signal = '突破上轨 - 强势但注意回调';
      signalColor = AppColors.down;
    } else if (close < lower) {
      signal = '跌破下轨 - 弱势但可能反弹';
      signalColor = AppColors.up;
    } else if (close > mid) {
      signal = '在中轨上方 - 偏强';
      signalColor = AppColors.up;
    } else if (close < mid) {
      signal = '在中轨下方 - 偏弱';
      signalColor = AppColors.down;
    } else {
      signal = '在中轨附近 - 震荡';
    }

    return _buildAnalysisCard(
      title: 'BOLL 布林带分析',
      icon: Icons.straighten,
      children: [
        _buildIndicatorRow('上轨', upper, AppColors.down),
        _buildIndicatorRow('中轨', mid, AppColors.ma20),
        _buildIndicatorRow('下轨', lower, AppColors.up),
        _buildIndicatorRow('当前价', close, AppColors.textPrimary),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // 成交量分析
  Widget _buildVolumeAnalysis(List<KlineData> klines, int lastIndex) {
    if (klines.length < 20) {
      return const SizedBox.shrink();
    }

    // 计算5日和20日平均成交量
    double sum5 = 0, sum20 = 0;
    for (int i = lastIndex; i > lastIndex - 5 && i >= 0; i--) {
      sum5 += klines[i].volume;
    }
    for (int i = lastIndex; i > lastIndex - 20 && i >= 0; i--) {
      sum20 += klines[i].volume;
    }

    final avg5 = sum5 / 5;
    final avg20 = sum20 / 20;
    final currentVolume = klines[lastIndex].volume;
    final volumeRatio = avg20 > 0 ? currentVolume / avg20 : 1.0;

    String signal = '';
    Color signalColor = AppColors.textSecondary;

    if (volumeRatio > 2) {
      signal = '放量 - 关注突破方向';
      signalColor = AppColors.primary;
    } else if (volumeRatio > 1.5) {
      signal = '温和放量';
      signalColor = AppColors.up;
    } else if (volumeRatio < 0.5) {
      signal = '缩量 - 观望为主';
      signalColor = AppColors.textSecondary;
    } else {
      signal = '正常成交量';
    }

    return _buildAnalysisCard(
      title: '成交量分析',
      icon: Icons.bar_chart,
      children: [
        _buildIndicatorRow('当前量', currentVolume, AppColors.textPrimary),
        _buildIndicatorRow('5日均量', avg5, AppColors.ma5),
        _buildIndicatorRow('20日均量', avg20, AppColors.ma20),
        _buildIndicatorRow('量比', volumeRatio, volumeRatio > 1.5 ? AppColors.up : AppColors.textSecondary),
        Divider(color: AppColors.divider),
        _buildSignalRow('信号', signal, signalColor),
      ],
    );
  }

  // 综合分析
  Widget _buildOverallSummary(IndicatorData indicators, List<KlineData> klines, int lastIndex) {
    int bullishCount = 0;
    int bearishCount = 0;

    // MA
    final ma5 = indicators.maLines[0][lastIndex];
    final ma10 = indicators.maLines[1][lastIndex];
    final ma20 = indicators.maLines[2][lastIndex];
    if (ma5 > ma10 && ma10 > ma20) bullishCount++;
    if (ma5 < ma10 && ma10 < ma20) bearishCount++;

    // MACD
    if (indicators.dif[lastIndex] > indicators.dea[lastIndex]) bullishCount++;
    else bearishCount++;

    // KDJ
    final j = indicators.j[lastIndex];
    if (j > 80) bearishCount++;
    else if (j < 20) bullishCount++;
    else if (indicators.k[lastIndex] > indicators.d[lastIndex]) bullishCount++;
    else bearishCount++;

    // RSI
    final rsi = indicators.rsi[lastIndex];
    if (rsi > 60) bullishCount++;
    else if (rsi < 40) bearishCount++;

    // BOLL
    final close = klines[lastIndex].close;
    if (close > indicators.bollMid[lastIndex]) bullishCount++;
    else bearishCount++;

    String overall = '';
    Color overallColor;

    if (bullishCount >= 4) {
      overall = '强烈看涨 - 多头信号明显';
      overallColor = AppColors.up;
    } else if (bullishCount >= 3) {
      overall = '偏多 - 可以考虑逢低买入';
      overallColor = AppColors.up;
    } else if (bearishCount >= 4) {
      overall = '强烈看跌 - 空头信号明显';
      overallColor = AppColors.down;
    } else if (bearishCount >= 3) {
      overall = '偏空 - 建议观望或减仓';
      overallColor = AppColors.down;
    } else {
      overall = '多空交织 - 建议观望';
      overallColor = AppColors.textSecondary;
    }

    return _buildAnalysisCard(
      title: '综合分析',
      icon: Icons.assessment,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildScoreColumn('看涨', bullishCount, AppColors.up),
            _buildScoreColumn('看跌', bearishCount, AppColors.down),
          ],
        ),
        Divider(color: AppColors.divider),
        _buildSignalRow('综合', overall, overallColor),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '免责声明：以上分析仅供参考，不构成投资建议。股市有风险，投资需谨慎。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // 资金流向分析
  Widget _buildFundFlowCard() {
    return _buildAnalysisCard(
      title: '资金流向',
      icon: Icons.account_balance_wallet,
      children: [
        if (_fundFlowLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_fundFlowData.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('暂无资金流数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          )
        else ...[
          // 最近一天汇总
          _buildFundFlowSummary(_fundFlowData.last),
          Divider(color: AppColors.divider),
          // 近5日明细
          Text('近5日主力净流入', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          ..._fundFlowData.reversed.take(5).map((d) => _buildFundFlowRow(d)),
        ],
      ],
    );
  }

  Widget _buildFundFlowSummary(FundFlowDetail latest) {
    final mainNet = latest.mainNet;
    final isMainIn = mainNet >= 0;
    final color = isMainIn ? AppColors.up : AppColors.down;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFlowColumn('主力净流入', mainNet, color),
            _buildFlowColumn('超大单', latest.superLargeNet, latest.superLargeNet >= 0 ? AppColors.up : AppColors.down),
            _buildFlowColumn('大单', latest.largeNet, latest.largeNet >= 0 ? AppColors.up : AppColors.down),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFlowColumn('中单', latest.mediumNet, latest.mediumNet >= 0 ? AppColors.up : AppColors.down),
            _buildFlowColumn('小单', latest.smallNet, latest.smallNet >= 0 ? AppColors.up : AppColors.down),
            _buildFlowColumn('主力占比', latest.mainPercent, color, isPercent: true),
          ],
        ),
      ],
    );
  }

  Widget _buildFlowColumn(String label, double value, Color color, {bool isPercent = false}) {
    final display = isPercent
        ? '${value.toStringAsFixed(1)}%'
        : _formatFlowAmount(value);
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(display, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFundFlowRow(FundFlowDetail d) {
    final dateStr = '${d.date.month}/${d.date.day}';
    final mainColor = d.mainNet >= 0 ? AppColors.up : AppColors.down;
    final maxVal = 1e10; // 100亿作为柱状图最大宽度参考
    final ratio = (d.mainNet.abs() / maxVal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(dateStr, style: TextStyle(color: AppColors.textSecondary, fontSize: 10))),
          Expanded(
            child: Stack(
              children: [
                Container(height: 16, decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(height: 16, decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.6), borderRadius: BorderRadius.circular(3))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(_formatFlowAmount(d.mainNet),
              style: TextStyle(color: mainColor, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  String _formatFlowAmount(double value) {
    final abs = value.abs();
    final sign = value >= 0 ? '+' : '-';
    if (abs >= 1e8) return '$sign${(abs / 1e8).toStringAsFixed(2)}亿';
    if (abs >= 1e4) return '$sign${(abs / 1e4).toStringAsFixed(0)}万';
    return '$sign${abs.toStringAsFixed(0)}';
  }

  // AI 诊断
  Widget _buildAiDiagnosis() {
    return _buildAnalysisCard(
      title: 'AI 诊断',
      icon: Icons.smart_toy,
      children: [
        if (_aiResult == null && !_aiLoading)
          Center(
            child: Column(
              children: [
                Text(
                  '使用 AI 分析 ${widget.stockName}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _runAiDiagnosis,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('开始诊断'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          )
        else if (_aiLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('正在分析...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
        else ...[
          // 风险等级标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _riskColor(_aiResult!.riskLevel).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '风险等级: ${_aiResult!.riskLevel}',
              style: TextStyle(
                color: _riskColor(_aiResult!.riskLevel),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 诊断摘要
          Text(
            _aiResult!.summary,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          // 操作建议
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiResult!.suggestion,
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // 信号标签
          if (_aiResult!.signals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _aiResult!.signals.map((s) => Chip(
                label: Text(s, style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                backgroundColor: AppColors.surface,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
          const SizedBox(height: 12),
          // 深度分析 + AI 对话按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _deepAnalysisLoading ? null : _runDeepAnalysis,
                icon: _deepAnalysisLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.analytics, size: 18),
                label: const Text('深度分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AiChatScreen(
                      initialCode: widget.stockCode,
                      initialName: widget.stockName,
                    ),
                  ));
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('AI 对话'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          // 深度分析结果
          if (_deepAnalysisMarkdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            MarkdownCard(markdown: _deepAnalysisMarkdown),
          ],
        ],
      ],
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case '高': return AppColors.down;
      case '低': return AppColors.up;
      default: return AppColors.ma5;
    }
  }

  // 形态识别分析
  Widget _buildPatternAnalysis() {
    return _buildAnalysisCard(
      title: '形态识别',
      icon: Icons.auto_graph,
      children: [
        ..._patterns.take(5).map((p) => _buildPatternItem(p)),
        if (_patterns.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '还有 ${_patterns.length - 5} 个形态...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        if (_patterns.isEmpty)
          Text('未检测到明显形态', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildPatternItem(PatternResult pattern) {
    final color = pattern.isBullish ? AppColors.up : AppColors.down;
    final direction = pattern.isBullish ? '看涨' : '看跌';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(direction, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(pattern.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('置信度 ${pattern.confidencePercent}',
                    style: TextStyle(color: AppColors.primary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(pattern.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // 构建分析卡片
  Widget _buildAnalysisCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // 指标行
  Widget _buildIndicatorRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 信号行
  Widget _buildSignalRow(String label, String signal, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label：',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Expanded(
            child: Text(
              signal,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 得分行
  Widget _buildScoreColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 14),
        ),
      ],
    );
  }
}
