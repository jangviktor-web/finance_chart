import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app/theme.dart';
import 'chart_screen.dart';
import 'scan_screen.dart';

/// 板块成分股数据
class SectorStock {
  final String code;
  final String name;
  final double price;
  final double changePercent;
  final double volume;
  final double amount;

  const SectorStock({
    required this.code,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.volume,
    required this.amount,
  });
}

/// 排序字段
enum SortField { changePercent, volume, code }
enum SortOrder { asc, desc }

/// 板块详情页 — 成分股列表 + 排序 + 策略扫描
class SectorDetailScreen extends StatefulWidget {
  final String sectorName;
  final double sectorChangePercent;
  final String? bkCode; // 东方财富板块代码（可选，优先使用）

  const SectorDetailScreen({
    super.key,
    required this.sectorName,
    required this.sectorChangePercent,
    this.bkCode,
  });

  @override
  State<SectorDetailScreen> createState() => _SectorDetailScreenState();
}

class _SectorDetailScreenState extends State<SectorDetailScreen> {
  List<SectorStock> _stocks = [];
  bool _isLoading = true;
  String? _error;
  SortField _sortField = SortField.changePercent;
  SortOrder _sortOrder = SortOrder.desc;

  @override
  void initState() {
    super.initState();
    _loadConstituents();
  }

  Future<void> _loadConstituents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<SectorStock> stocks = [];
      String? lastError;

      // 策略 1: BK 代码直接查 push2
      if (widget.bkCode != null && widget.bkCode!.isNotEmpty) {
        try {
          stocks = await _fetchConstituentsByCode(widget.bkCode!);
          if (stocks.isEmpty) lastError = 'BK代码 ${widget.bkCode} 返回空数据';
        } catch (e) {
          lastError = 'BK代码查询失败: $e';
        }
      }

      // 策略 2: 名称搜索行业板块 + 概念板块
      if (stocks.isEmpty) {
        try {
          final boardCode = await _searchBoardCode(widget.sectorName);
          if (boardCode != null) {
            stocks = await _fetchConstituentsByCode(boardCode);
            if (stocks.isEmpty) lastError = '板块代码 $boardCode 返回空数据';
          } else {
            lastError = '未找到板块: ${widget.sectorName}';
          }
        } catch (e) {
          lastError = '名称搜索失败: $e';
        }
      }

      // 策略 3: 模糊匹配行业板块列表
      if (stocks.isEmpty) {
        try {
          stocks = await _fetchViaFuzzySearch(widget.sectorName);
          if (stocks.isEmpty) lastError = '模糊搜索未匹配到板块';
        } catch (e) {
          lastError = '模糊搜索失败: $e';
        }
      }

      if (stocks.isEmpty) {
        throw Exception(lastError ?? '无法获取板块 "${widget.sectorName}" 的成分股数据');
      }

      setState(() {
        _stocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 通过板块代码获取成分股（使用 Dio + ut/Referer 头）
  Future<List<SectorStock>> _fetchConstituentsByCode(String boardCode) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ));

    final response = await dio.get(
      'https://push2.eastmoney.com/api/qt/clist/get',
      queryParameters: {
        'pn': '1',
        'pz': '200',
        'po': '1',
        'np': '1',
        'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
        'fltt': '2',
        'invt': '2',
        'fid': 'f3',
        'fs': 'b:$boardCode+f:!50',
        'fields': 'f2,f3,f5,f6,f12,f13,f14',
      },
    );

    final data = response.data is String
        ? json.decode(response.data as String)
        : response.data as Map<String, dynamic>;

    final diff = data['data']?['diff'];
    if (diff is! List || diff.isEmpty) return [];

    final stocks = <SectorStock>[];
    for (final item in diff) {
      final code = item['f12']?.toString() ?? '';
      final name = item['f14']?.toString() ?? '';
      if (code.isEmpty || name.isEmpty) continue;

      // f13: 0=深圳, 1=上海
      final market = item['f13'];
      String prefix;
      if (market == 1) {
        prefix = 'sh';
      } else if (market == 0) {
        prefix = 'sz';
      } else {
        prefix = code.startsWith('6') ? 'sh' : 'sz';
      }

      final price = (item['f2'] is num) ? (item['f2'] as num).toDouble() : 0.0;
      final changePct = (item['f3'] is num) ? (item['f3'] as num).toDouble() : 0.0;
      final volume = (item['f5'] is num) ? (item['f5'] as num).toDouble() : 0.0;
      final amount = (item['f6'] is num) ? (item['f6'] as num).toDouble() : 0.0;

      stocks.add(SectorStock(
        code: '$prefix$code',
        name: name,
        price: price,
        changePercent: changePct,
        volume: volume,
        amount: amount,
      ));
    }
    return stocks;
  }

  /// 板块名称别名映射（常见简称 → 搜索关键词）
  static const _nameAliases = {
    '军工': '国防军工',
    '白酒': '白酒概念',
    '人工智能': '人工智能',
    '半导体': '半导体',
    '新能源': '新能源',
    '医药生物': '医药生物',
    '房地产': '房地产',
    '银行': '银行板块',
  };

  /// 搜索板块代码（支持行业板块和概念板块）
  Future<String?> _searchBoardCode(String name) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ));

    // 搜索行业板块
    var code = await _searchInCategory(dio, name, 'm:90+t:2+f:!50');
    if (code != null) return code;

    // 搜索概念板块
    code = await _searchInCategory(dio, name, 'm:90+t:3+f:!50');
    if (code != null) return code;

    // 使用别名重试
    final alias = _nameAliases[name];
    if (alias != null && alias != name) {
      code = await _searchInCategory(dio, alias, 'm:90+t:2+f:!50');
      if (code != null) return code;
      code = await _searchInCategory(dio, alias, 'm:90+t:3+f:!50');
      if (code != null) return code;
    }

    return null;
  }

  Future<String?> _searchInCategory(Dio dio, String name, String fs) async {
    try {
      final response = await dio.get(
        'https://push2.eastmoney.com/api/qt/clist/get',
        queryParameters: {
          'pn': '1',
          'pz': '500',
          'po': '1',
          'np': '1',
          'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
          'fltt': '2',
          'invt': '2',
          'fid': 'f3',
          'fs': fs,
          'fields': 'f12,f14',
        },
      );

      final data = response.data is String
          ? json.decode(response.data as String)
          : response.data as Map<String, dynamic>;

      final diff = data['data']?['diff'];
      if (diff is! List) return null;

      for (final item in diff) {
        final boardName = item['f14']?.toString() ?? '';
        final boardCode = item['f12']?.toString() ?? '';
        if (boardName == name || boardName.contains(name) || name.contains(boardName)) {
          return boardCode;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 备用数据源: 模糊匹配行业/概念板块列表
  Future<List<SectorStock>> _fetchViaFuzzySearch(String sectorName) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ));

    // 同时搜索行业和概念板块
    for (final fs in ['m:90+t:2+f:!50', 'm:90+t:3+f:!50']) {
      try {
        final response = await dio.get(
          'https://push2.eastmoney.com/api/qt/clist/get',
          queryParameters: {
            'pn': '1',
            'pz': '500',
            'po': '1',
            'np': '1',
            'ut': 'bd1d9ddb04089700cf9c27f6f7426281',
            'fltt': '2',
            'invt': '2',
            'fid': 'f3',
            'fs': fs,
            'fields': 'f12,f14',
          },
        );

        final data = response.data is String
            ? json.decode(response.data as String)
            : response.data as Map<String, dynamic>;

        final diff = data['data']?['diff'];
        if (diff is! List) continue;

        // 模糊匹配板块名
        for (final item in diff) {
          final boardName = item['f14']?.toString() ?? '';
          final boardCode = item['f12']?.toString() ?? '';
          if (boardName == sectorName ||
              boardName.contains(sectorName) ||
              sectorName.contains(boardName)) {
            return await _fetchConstituentsByCode(boardCode);
          }
        }
      } catch (_) {}
    }
    return [];
  }

  List<SectorStock> get _sortedStocks {
    final list = List<SectorStock>.from(_stocks);
    int Function(SectorStock, SectorStock) cmp;
    switch (_sortField) {
      case SortField.changePercent:
        cmp = (a, b) => a.changePercent.compareTo(b.changePercent);
        break;
      case SortField.volume:
        cmp = (a, b) => a.volume.compareTo(b.volume);
        break;
      case SortField.code:
        cmp = (a, b) => a.code.compareTo(b.code);
        break;
    }
    list.sort(cmp);
    if (_sortOrder == SortOrder.desc) return list.reversed.toList();
    return list;
  }

  void _toggleSort(SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortOrder = _sortOrder == SortOrder.desc ? SortOrder.asc : SortOrder.desc;
      } else {
        _sortField = field;
        _sortOrder = SortOrder.desc;
      }
    });
  }

  void _openChart(String code) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChartScreen(stockCode: code),
    ));
  }

  void _scanSector() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScanScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.sectorChangePercent >= 0 ? AppColors.up : AppColors.down;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.sectorName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: '策略扫描此板块',
            onPressed: _scanSector,
          ),
        ],
      ),
      body: Column(
        children: [
          // 板块概览
          _buildHeader(color),
          // 排序栏
          _buildSortBar(),
          // 成分股列表
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.sectorName, style: TextStyle(
                color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${widget.sectorChangePercent >= 0 ? '+' : ''}${widget.sectorChangePercent.toStringAsFixed(2)}%',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          if (!_isLoading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('成分股 ${_stocks.length} 只', style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${_stocks.where((s) => s.changePercent >= 0).length}↑ '
                  '${_stocks.where((s) => s.changePercent < 0).length}↓',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildSortChip('涨跌幅', SortField.changePercent),
          const SizedBox(width: 12),
          _buildSortChip('成交量', SortField.volume),
          const SizedBox(width: 12),
          _buildSortChip('代码', SortField.code),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, SortField field) {
    final isActive = _sortField == field;
    final icon = isActive
        ? (_sortOrder == SortOrder.desc ? Icons.arrow_downward : Icons.arrow_upward)
        : Icons.unfold_more;
    return GestureDetector(
      onTap: () => _toggleSort(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
          const SizedBox(width: 2),
          Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();
    if (_error != null) return _buildError();
    if (_stocks.isEmpty) return _buildEmpty();
    return _buildStockList();
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(width: 60, height: 14, color: AppColors.surface),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 14, color: AppColors.surface)),
            Container(width: 50, height: 14, color: AppColors.surface),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.down, size: 48),
          const SizedBox(height: 16),
          Text('加载失败', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConstituents,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('重试', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: AppColors.textSecondary.withOpacity(0.5), size: 64),
          const SizedBox(height: 16),
          Text('暂无成分股数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStockList() {
    return RefreshIndicator(
      onRefresh: _loadConstituents,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _sortedStocks.length,
        itemBuilder: (ctx, i) => _buildStockTile(_sortedStocks[i]),
      ),
    );
  }

  Widget _buildStockTile(SectorStock stock) {
    final color = stock.changePercent >= 0 ? AppColors.up : AppColors.down;
    return GestureDetector(
      onTap: () => _openChart(stock.code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 名称 + 代码
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.name, style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(stock.code.toUpperCase(), style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            // 价格
            Expanded(
              flex: 2,
              child: Text(stock.price.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            // 涨跌幅
            SizedBox(
              width: 72,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
