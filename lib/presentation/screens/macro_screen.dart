import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/macro_api.dart';
import '../../data/models/macro_data.dart';

/// 宏观数据页面
class MacroScreen extends StatefulWidget {
  const MacroScreen({super.key});

  @override
  State<MacroScreen> createState() => _MacroScreenState();
}

class _MacroScreenState extends State<MacroScreen> {
  final _api = MacroApi();
  final Map<String, MacroIndicator> _indicators = {};
  List<LprData> _lprData = [];
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
      final results = await Future.wait([
        _api.getCpi(limit: 12),
        _api.getPpi(limit: 12),
        _api.getGdp(limit: 8),
        _api.getPmi(limit: 12),
        _api.getM2(limit: 12),
        _api.getLpr(limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _indicators['CPI'] = results[0] as MacroIndicator;
          _indicators['PPI'] = results[1] as MacroIndicator;
          _indicators['GDP'] = results[2] as MacroIndicator;
          _indicators['PMI'] = results[3] as MacroIndicator;
          _indicators['M2'] = results[4] as MacroIndicator;
          _lprData = results[5] as List<LprData>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('宏观数据'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMacroCard('CPI（居民消费价格指数）', _indicators['CPI']),
                      _buildMacroCard('PPI（工业生产者出厂价格指数）', _indicators['PPI']),
                      _buildMacroCard('GDP（国内生产总值增速）', _indicators['GDP']),
                      _buildMacroCard('PMI（制造业采购经理指数）', _indicators['PMI']),
                      _buildMacroCard('M2（广义货币供应量增速）', _indicators['M2']),
                      _buildLprCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: AppColors.warning, size: 48),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('重试', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String title, MacroIndicator? indicator) {
    if (indicator == null || indicator.data.isEmpty) return const SizedBox.shrink();

    final latest = indicator.data.last;
    final prev = indicator.data.length > 1 ? indicator.data[indicator.data.length - 2] : null;
    final trend = prev != null ? latest.value - prev.value : 0.0;
    final trendColor = trend > 0 ? AppColors.up : (trend < 0 ? AppColors.down : AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold))),
              Text('${latest.value.toStringAsFixed(1)}${indicator.unit}',
                  style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(latest.period, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              if (latest.yoy != null)
                Text('同比 ${latest.yoy!.toStringAsFixed(1)}%',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              if (trend != 0)
                Text('${trend > 0 ? '↑' : '↓'} ${trend.abs().toStringAsFixed(1)}',
                    style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size.infinite,
              painter: _MiniLinePainter(
                data: indicator.data.map((d) => d.value).toList(),
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLprCard() {
    if (_lprData.isEmpty) return const SizedBox.shrink();

    final latest = _lprData.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LPR（贷款市场报价利率）',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Column(
                children: [
                  Text('1年期', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${latest.lpr1y.toStringAsFixed(2)}%',
                      style: TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              )),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(child: Column(
                children: [
                  Text('5年期', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${latest.lpr5y.toStringAsFixed(2)}%',
                      style: TextStyle(color: AppColors.ma5, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              )),
            ],
          ),
          const SizedBox(height: 8),
          Text('更新: ${latest.date}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 迷你折线图 Painter
class _MiniLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniLinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height * (1 - (data[i] - minVal) / range);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // 填充
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter old) => old.data != data;
}
