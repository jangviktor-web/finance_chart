import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/datasources/stock_info_api.dart';
import '../../data/models/stock_info_data.dart';

/// 个股深度数据页面
class StockDetailScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const StockDetailScreen({super.key, required this.stockCode, this.stockName = ''});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final _api = StockInfoApi();

  ValuationData? _valuation;
  List<ShareholderData> _shareholders = [];
  List<BlockTrade> _blockTrades = [];
  List<RestrictedShare> _restricted = [];
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
        _api.getValuation(widget.stockCode),
        _api.getShareholders(widget.stockCode, limit: 8),
        _api.getBlockTrades(widget.stockCode, limit: 10),
        _api.getRestrictedShares(widget.stockCode, limit: 5),
      ]);

      if (mounted) {
        setState(() {
          _valuation = results[0] as ValuationData;
          _shareholders = results[1] as List<ShareholderData>;
          _blockTrades = results[2] as List<BlockTrade>;
          _restricted = results[3] as List<RestrictedShare>;
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
      appBar: AppBar(
        title: Text(widget.stockName.isNotEmpty ? '${widget.stockName} 详情' : '个股详情'),
        centerTitle: true,
      ),
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
                      _buildValuationCard(),
                      const SizedBox(height: 12),
                      _buildShareholderCard(),
                      const SizedBox(height: 12),
                      _buildBlockTradeCard(),
                      const SizedBox(height: 12),
                      _buildRestrictedCard(),
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

  Widget _buildValuationCard() {
    final v = _valuation;
    if (v == null) return const SizedBox.shrink();

    return _card(
      '估值数据',
      Icons.assessment,
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _valItem('市盈率(PE)', v.pe.toStringAsFixed(2)),
          _valItem('市净率(PB)', v.pb.toStringAsFixed(2)),
          _valItem('总市值', '${v.totalMarketCap.toStringAsFixed(0)}亿'),
          _valItem('流通市值', '${v.circulatingCap.toStringAsFixed(0)}亿'),
        ],
      ),
    );
  }

  Widget _valItem(String label, String value) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildShareholderCard() {
    if (_shareholders.isEmpty) return const SizedBox.shrink();

    return _card(
      '股东人数变化',
      Icons.people,
      Column(
        children: _shareholders.map((s) {
          final changeColor = s.changePercent > 0 ? AppColors.up : (s.changePercent < 0 ? AppColors.down : AppColors.textSecondary);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(s.date, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Expanded(child: Text('${_formatCount(s.holderCount)}人',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                Text('${s.changePercent >= 0 ? '+' : ''}${s.changePercent.toStringAsFixed(1)}%',
                    style: TextStyle(color: changeColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockTradeCard() {
    if (_blockTrades.isEmpty) return const SizedBox.shrink();

    return _card(
      '大宗交易',
      Icons.swap_horiz,
      Column(
        children: _blockTrades.take(8).map((t) {
          final premiumColor = t.premiumRate > 0 ? AppColors.up : (t.premiumRate < 0 ? AppColors.down : AppColors.textSecondary);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text('${t.date.month}/${t.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                SizedBox(width: 60, child: Text(t.price.toStringAsFixed(2),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                Expanded(child: Text('${t.amount.toStringAsFixed(0)}万',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                Text('${t.premiumRate >= 0 ? '+' : ''}${t.premiumRate.toStringAsFixed(1)}%',
                    style: TextStyle(color: premiumColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestrictedCard() {
    if (_restricted.isEmpty) return const SizedBox.shrink();

    return _card(
      '限售解禁',
      Icons.lock_open,
      Column(
        children: _restricted.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('${r.date.year}/${r.date.month}/${r.date.day}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Expanded(child: Text('${r.amount.toStringAsFixed(1)}亿',
                    style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold))),
                Text(r.type, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
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
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count.toString();
  }
}
