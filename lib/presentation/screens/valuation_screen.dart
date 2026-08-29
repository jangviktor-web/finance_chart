import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/thinks_api.dart';
import '../../data/models/ths_extra_data.dart';
import '../../presentation/providers/settings_provider.dart';

/// 个股估值快照 — 同花顺 PE/PB/PS/PCF
class ValuationScreen extends ConsumerStatefulWidget {
  final String stockCode;
  final String stockName;
  const ValuationScreen({super.key, required this.stockCode, this.stockName = ''});

  @override
  ConsumerState<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends ConsumerState<ValuationScreen> {
  ValuationSnapshot? _data;
  bool _loading = true;
  String? _error;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _configured = ref.read(settingsProvider).thinksApiKey.isNotEmpty;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final key = ref.read(settingsProvider).thinksApiKey;
      if (key.isEmpty) {
        if (mounted) setState(() => _error = '未配置同花顺 API Key');
        return;
      }
      final ths = ThinksApi(apiKey: key);
      final list = await ths.getValuationSnapshot([widget.stockCode]);
      if (mounted) setState(() => _data = list.isNotEmpty ? list.first : null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.stockName.isNotEmpty ? '${widget.stockName} 估值' : '估值快照';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.warning, size: 36),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('重试', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
    }
    if (_data == null) {
      return Center(child: Text(_configured ? '暂无估值数据' : '请先在设置中配置同花顺 Key',
          style: TextStyle(color: AppColors.textSecondary)));
    }

    final items = <Map<String, dynamic>>[
      {'label': '市盈率 TTM', 'value': _data!.peTtm, 'hint': 'PE-TTM'},
      {'label': '市盈率 MRQ', 'value': _data!.peMrq, 'hint': 'PE-MRQ'},
      {'label': '市净率 MRQ', 'value': _data!.pbMrq, 'hint': 'PB-MRQ'},
      {'label': '市销率 TTM', 'value': _data!.psTtm, 'hint': 'PS-TTM'},
      {'label': '市现率 TTM', 'value': _data!.pcfTtm, 'hint': 'PCF-TTM'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.stockCode.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        ...items.map((m) => Card(
              color: AppColors.cardBackground,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(m['label'] as String, style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(m['hint'] as String, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                trailing: Text(
                  m['value'] == null ? '—' : (m['value'] as double).toStringAsFixed(2),
                  style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            )),
        const SizedBox(height: 8),
        Text('数据来源：同花顺估值快照（仅最新值，可能为 null，不做补零）',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}
