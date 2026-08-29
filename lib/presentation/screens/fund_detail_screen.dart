import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/models/fund_data.dart';
import '../../presentation/providers/market_provider.dart';

/// 公募基金详情（同花顺 BYOK）
///
/// 展示基本资料、区间收益、最新净值与重仓股。数据未披露时按服务端原值留空，不补零。
class FundDetailScreen extends ConsumerStatefulWidget {
  final String thscode;
  final String fundName;
  final String fundType; // otc / exchange / reits

  const FundDetailScreen({
    super.key,
    required this.thscode,
    this.fundName = '',
    required this.fundType,
  });

  @override
  ConsumerState<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends ConsumerState<FundDetailScreen> {
  FundProfile? _profile;
  FundReturns? _returns;
  List<FundNavPoint> _nav = [];
  List<FundHolding> _holdings = [];
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
      final api = ref.read(marketApiProvider);
      final code = widget.thscode;
      final type = widget.fundType;
      final results = await Future.wait<dynamic>([
        api.getFundProfile(type, code),
        api.getFundReturns(type, code),
        api.getFundNav(type, code, range: 'year'),
        api.getFundHoldings(type, code).catchError((_) => <FundHolding>[]),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as FundProfile;
          _returns = results[1] as FundReturns;
          _nav = results[2] as List<FundNavPoint>;
          _holdings = results[3] as List<FundHolding>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.fundName.isNotEmpty ? widget.fundName : widget.thscode;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16)), centerTitle: true),
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
                      _buildProfileCard(),
                      const SizedBox(height: 12),
                      _buildReturnsCard(),
                      const SizedBox(height: 12),
                      _buildNavCard(),
                      const SizedBox(height: 12),
                      _buildHoldingsCard(),
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

  Widget _buildProfileCard() {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();
    return _card('基本资料', Icons.account_balance_wallet, Column(
      children: [
        _row('基金代码', p.thscode),
        _row('基金管理人', p.companyName ?? '--'),
        _row('基金经理', p.managerName ?? '--'),
        _row('基金规模', p.fundScale == null ? '--' : '${p.fundScale!.toStringAsFixed(2)} 亿'),
        _row('最新单位净值', p.unitNav == null ? '--' : p.unitNav!.toStringAsFixed(4)),
        _row('成立日期', p.estabDate == null ? '--' : '${p.estabDate!.year}-${p.estabDate!.month}-${p.estabDate!.day}'),
      ],
    ));
  }

  Widget _buildReturnsCard() {
    final r = _returns;
    if (r == null) return const SizedBox.shrink();
    return _card('区间收益', Icons.trending_up, Column(
      children: r.labels.map((label) {
        final v = r.returns[label];
        final peer = r.peerAverage[label];
        final color = v == null ? AppColors.textSecondary : (v >= 0 ? AppColors.up : AppColors.down);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 76, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              Expanded(child: Text(v == null ? '--' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold))),
              if (peer != null)
                Text('同类 ${peer >= 0 ? '+' : ''}${peer.toStringAsFixed(2)}%',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    ));
  }

  Widget _buildNavCard() {
    if (_nav.isEmpty) return const SizedBox.shrink();
    final latest = _nav.last;
    final prev = _nav.length > 1 ? _nav[_nav.length - 2] : null;
    final change = (latest.unitNav != null && prev?.unitNav != null)
        ? latest.unitNav! - prev!.unitNav!
        : null;
    return _card('最新净值', Icons.show_chart, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(latest.unitNav?.toStringAsFixed(4) ?? '--', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            _changeText(change),
          ],
        ),
        const SizedBox(height: 4),
        Text('截至 ${_fmtDate(latest.navDateMs)}（近一年 ${_nav.length} 个净值点）',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    ));
  }

  Widget _buildHoldingsCard() {
    if (_holdings.isEmpty) return const SizedBox.shrink();
    return _card('重仓股（定期披露）', Icons.pie_chart, Column(
      children: _holdings.take(10).map((h) {
        final ratio = h.holdRatio;
        final inc = h.periodIncreaseRatePct;
        final ratioStr = ratio == null ? '--' : '${ratio.toStringAsFixed(2)}%';
        final incStr = inc == null ? '--' : '${inc >= 0 ? '+' : ''}${inc.toStringAsFixed(2)}%';
        final color = inc == null ? AppColors.textSecondary : (inc >= 0 ? AppColors.up : AppColors.down);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text('${h.investmentRank ?? ''}. ${h.stockName}', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
              SizedBox(width: 70, child: Text(ratioStr,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
              SizedBox(width: 64, child: Text(incStr,
                  style: TextStyle(color: color, fontSize: 12), textAlign: TextAlign.end)),
            ],
          ),
        );
      }).toList(),
    ));
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _changeText(double? change) {
    if (change == null) return const SizedBox.shrink();
    final color = change >= 0 ? AppColors.up : AppColors.down;
    return Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(4)}',
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold));
  }
}
