import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/data_source_config.dart';
import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _backendUrlController = TextEditingController();
  bool _isTestingConnection = false;
  String _connectionStatus = '未连接';
  Color _connectionColor = AppColors.textSecondary;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    _backendUrlController.text = settings.backendUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          _buildSection('行情设置', [
            _buildRefreshIntervalDropdown(settings.refreshInterval),
            _buildSwitch('自动刷新行情', settings.autoRefresh,
                (v) => ref.read(settingsProvider.notifier).setAutoRefresh(v)),
            _buildInfoRow('实时性说明', '间隔越短越耗电，建议5秒', AppColors.textSecondary),
          ]),
          _buildSection('图表设置', [
            _buildSwitch('显示均线', settings.showMA,
                (v) => ref.read(settingsProvider.notifier).setShowMA(v)),
            _buildIndicatorDropdown(settings.defaultIndicator),
          ]),
          _buildSection('外观个性化', [
            _buildSwitch('深色模式', settings.isDarkMode,
                (v) => ref.read(settingsProvider.notifier).setDarkMode(v)),
            _buildColorStyleSelector(settings.colorStyle),
          ]),
          _buildSection('功能开关', [
            _buildSwitch('市场情绪', settings.enableSentiment,
                (v) => ref.read(settingsProvider.notifier).setEnableSentiment(v)),
            _buildSwitch('宏观数据', settings.enableMacro,
                (v) => ref.read(settingsProvider.notifier).setEnableMacro(v)),
            _buildSwitch('财经新闻', settings.enableNews,
                (v) => ref.read(settingsProvider.notifier).setEnableNews(v)),
            _buildSwitch('选股扫描', settings.enableScan,
                (v) => ref.read(settingsProvider.notifier).setEnableScan(v)),
            _buildSwitch('AI 功能', settings.enableAi,
                (v) => ref.read(settingsProvider.notifier).setEnableAi(v)),
          ]),
          _buildSection('AI 配置', [
            _buildApiKeyInput(settings.emApiKey),
          ]),
          _buildSection('数据源设置', [
            _buildDataSourceSelector('实时行情', settings.realtimeSource,
                (v) => ref.read(settingsProvider.notifier).setRealtimeSource(v)),
            _buildDataSourceSelector('K 线数据', settings.klineSource,
                (v) => ref.read(settingsProvider.notifier).setKlineSource(v)),
            _buildDataSourceSelector('新闻资讯', settings.newsSource,
                (v) => ref.read(settingsProvider.notifier).setNewsSource(v)),
            _buildDataSourceSelector('资金流向', settings.fundFlowSource,
                (v) => ref.read(settingsProvider.notifier).setFundFlowSource(v)),
          ]),
          _buildSection('数据管理', [
            _buildActionRow('清除缓存', '清除本地缓存的行情数据', _clearCache),
            _buildActionRow('导出自选股', '导出自选股列表到剪贴板', _exportWatchlist),
            _buildActionRow('导出运行日志', '复制最近500条日志到剪贴板', _exportLogs),
          ]),
          _buildSection('关于', [
            _buildInfoRow('应用名称', '策盈 QuantWin', AppColors.primary),
            _buildInfoRow('版本', 'v1.2.0', AppColors.textPrimary),
            _buildInfoRow('数据来源', '东方财富 / 腾讯 / 新浪', AppColors.textSecondary),
            _buildInfoRow('免责声明', '仅供参考，不构成投资建议', AppColors.textSecondary),
          ]),
          // ── 高级设置（后端配置，可选） ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                children: [
                  Text('高级设置',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          if (_showAdvanced) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('后端服务（可选）',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('所有行情、K线、指标、回测功能均为本地计算，无需后端。后端仅用于 AI 等扩展功能。',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  _buildTextField('服务器地址', _backendUrlController,
                      hint: '如 http://192.168.1.100:8000',
                      onChanged: (v) => ref.read(settingsProvider.notifier).setBackendUrl(v)),
                  _buildResetDefaultRow(),
                  _buildConnectionStatus(),
                  _buildActionRow('测试连接', '检测后端服务是否可用', _testConnection),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 涨跌色选择器 ──

  Widget _buildColorStyleSelector(String currentStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('涨跌色风格', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'cn',
                label: Text('红涨绿跌',
                    style: TextStyle(fontSize: 12, color: currentStyle == 'cn' ? Colors.white : AppColors.textPrimary)),
              ),
              ButtonSegment(
                value: 'us',
                label: Text('绿涨红跌',
                    style: TextStyle(fontSize: 12, color: currentStyle == 'us' ? Colors.white : AppColors.textPrimary)),
              ),
            ],
            selected: {currentStyle},
            onSelectionChanged: (v) {
              ref.read(settingsProvider.notifier).setColorStyle(v.first);
              AppColors.setColorStyle(v.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return AppColors.surface;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── 刷新间隔下拉框（带单位） ──

  Widget _buildRefreshIntervalDropdown(int current) {
    const options = [
      (1, '1秒（高频）'),
      (3, '3秒'),
      (5, '5秒（推荐）'),
      (10, '10秒'),
      (30, '30秒'),
      (60, '1分钟（省电）'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('刷新间隔', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          DropdownButton<int>(
            value: current,
            dropdownColor: AppColors.surface,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            underline: const SizedBox.shrink(),
            items: options.map((o) => DropdownMenuItem(
              value: o.$1,
              child: Text(o.$2, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) {
              if (v != null) ref.read(settingsProvider.notifier).setRefreshInterval(v);
            },
          ),
        ],
      ),
    );
  }

  // ── 指标下拉框 ──

  Widget _buildIndicatorDropdown(String current) {
    const options = [
      'MACD', 'KDJ', 'RSI', 'CCI', 'WR', 'DMI', 'BIAS',
      'ATR', 'OBV', 'TRIX', 'EMV', 'MFI', 'VR', 'ROC',
      'MTM', 'PSY', 'CR', 'DPO', 'BRAR', 'MASS', 'ASI',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('默认副图指标', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          DropdownButton<String>(
            value: current,
            dropdownColor: AppColors.surface,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            underline: const SizedBox.shrink(),
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v != null) ref.read(settingsProvider.notifier).setDefaultIndicator(v);
            },
          ),
        ],
      ),
    );
  }

  // ── 测试连接（多端点探测）──

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = '测试中...';
      _connectionColor = AppColors.primary;
    });

    try {
      final url = ref.read(settingsProvider).backendUrl;
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!url.startsWith('http://') && !url.startsWith('https://'))) {
        setState(() {
          _isTestingConnection = false;
          _connectionStatus = '地址格式错误（需要 http:// 或 https://）';
          _connectionColor = AppColors.down;
        });
        return;
      }

      // 尝试多个端点，任意一个返回 200 即视为连接成功
      final endpoints = ['/', '/health', '/api/v1/health', '/docs', '/redoc', '/openapi.json'];
      bool connected = false;
      String connectedVia = '';
      int lastStatusCode = 0;

      for (final endpoint in endpoints) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
          final request = await client.getUrl(Uri.parse('$url$endpoint'));
          final response = await request.close().timeout(const Duration(seconds: 3));
          client.close();
          lastStatusCode = response.statusCode;
          if (response.statusCode >= 200 && response.statusCode < 400) {
            connected = true;
            connectedVia = endpoint;
            break;
          }
        } catch (_) {
          continue;
        }
      }

      if (!mounted) return;

      setState(() {
        _isTestingConnection = false;
        if (connected) {
          _connectionStatus = '已连接 (via $connectedVia)';
          _connectionColor = AppColors.success;
        } else if (lastStatusCode > 0) {
          _connectionStatus = '服务器响应异常 ($lastStatusCode)';
          _connectionColor = AppColors.warning;
        } else {
          _connectionStatus = '无法连接';
          _connectionColor = AppColors.down;
        }
      });

      // 连接失败时弹出引导
      if (!connected && mounted) {
        _showConnectionGuide();
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = '无法连接 — 地址不可达';
        _connectionColor = AppColors.down;
      });
      _showConnectionGuide();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = '连接超时 — 服务器可能未启动';
        _connectionColor = AppColors.down;
      });
      _showConnectionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = '连接失败: ${e.runtimeType}';
        _connectionColor = AppColors.down;
      });
    }
  }

  void _showConnectionGuide() {
    final url = ref.read(settingsProvider).backendUrl;
    final isEmulator = url.contains('10.0.2.2');
    final isLocalhost = url.contains('localhost') || url.contains('127.0.0.1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text('连接失败排查', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前地址: $url', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (isEmulator) ...[
                _guideItem('1', '确认后端已启动', '在电脑终端运行 Python 后端服务'),
                _guideItem('2', '检查端口', '确认后端监听在 8000 端口'),
                _guideItem('3', '模拟器限制', '10.0.2.2 仅限 Android 模拟器访问宿主机\n真机请使用电脑的局域网 IP'),
              ] else if (isLocalhost) ...[
                _guideItem('1', 'localhost 无效', '手机无法访问自身的 localhost\n请改为电脑的局域网 IP（如 192.168.x.x:8000）'),
              ] else ...[
                _guideItem('1', '确认后端已启动', '在电脑终端运行: python main.py'),
                _guideItem('2', '检查网络', '手机和电脑需在同一 WiFi 网络'),
                _guideItem('3', '检查防火墙', 'Windows 防火墙可能阻止了 8000 端口'),
                _guideItem('4', '检查端口', '确认后端监听 0.0.0.0:8000 而非 127.0.0.1:8000'),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('快速获取本机 IP:', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Windows: 终端输入 ipconfig', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('Mac/Linux: 终端输入 ifconfig', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('找到 WiFi 适配器的 IPv4 地址', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('关闭', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (isEmulator || isLocalhost)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _suggestLanAddress();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('自动探测局域网', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _guideItem(String num, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text(num, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(detail, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 探测局域网常见网段的后端
  Future<void> _suggestLanAddress() async {
    setState(() {
      _connectionStatus = '探测局域网中...';
      _connectionColor = AppColors.primary;
    });

    // 常见局域网网段
    final bases = ['192.168.1', '192.168.0', '192.168.31', '192.168.50', '10.0.0'];
    const port = 8000;

    for (final base in bases) {
      for (int i = 1; i <= 5; i++) {
        final ip = '$base.$i';
        try {
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 500);
          final request = await client.getUrl(Uri.parse('http://$ip:$port/'));
          final response = await request.close().timeout(const Duration(milliseconds: 500));
          client.close();
          if (response.statusCode >= 200 && response.statusCode < 400) {
            final foundUrl = 'http://$ip:$port';
            ref.read(settingsProvider.notifier).setBackendUrl(foundUrl);
            if (mounted) {
              setState(() {
                _connectionStatus = '已发现: $ip:$port';
                _connectionColor = AppColors.success;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已自动配置: $foundUrl'), backgroundColor: AppColors.success),
              );
            }
            return;
          }
        } catch (_) {
          continue;
        }
      }
    }

    if (mounted) {
      setState(() {
        _connectionStatus = '未发现后端服务';
        _connectionColor = AppColors.down;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('局域网未发现后端，请确认后端已启动'), backgroundColor: AppColors.warning),
      );
    }
  }

  void _resetBackendUrl() {
    const defaultUrl = 'http://10.0.2.2:8000';
    _backendUrlController.text = defaultUrl;
    ref.read(settingsProvider.notifier).setBackendUrl(defaultUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已恢复默认地址: $defaultUrl'), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 保留设置项，清除数据缓存
      final keys = prefs.getKeys().where((k) =>
        k.startsWith('scan_history') ||
        k.startsWith('saved_scan_configs') ||
        k.startsWith('cache_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存已清除（${keys.length}项）'), backgroundColor: AppColors.up),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e'), backgroundColor: AppColors.down),
        );
      }
    }
  }

  void _exportWatchlist() {
    final groups = ref.read(watchlistProvider);
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂无自选股'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final buffer = StringBuffer();
    for (final group in groups) {
      buffer.writeln('【${group.name}】');
      for (final code in group.codes) {
        buffer.writeln('  ${code.toUpperCase()}');
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${groups.fold<int>(0, (sum, g) => sum + g.codes.length)} 只自选股到剪贴板'),
        backgroundColor: AppColors.up,
      ),
    );
  }

  Future<void> _exportLogs() async {
    final count = AppLog.instance.length;
    if (count == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('暂无运行日志'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    await AppLog.instance.toClipboard();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制 $count 条日志到剪贴板'),
          backgroundColor: AppColors.up,
        ),
      );
    }
  }

  // ── 通用构建方法 ──

  Widget _buildResetDefaultRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('默认地址', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          GestureDetector(
            onTap: _resetBackendUrl,
            child: Text('http://10.0.2.2:8000 (点击恢复)',
              style: TextStyle(color: AppColors.primary, fontSize: 12, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('连接状态', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: _connectionColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(_connectionStatus, style: TextStyle(color: _connectionColor, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? hint, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildDataSourceSelector(String label, DataSourceType current, ValueChanged<DataSourceType> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DataSourceType>(
                value: current,
                isDense: true,
                items: DataSourceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      '${DataSourceConfig.getIcon(type)} ${DataSourceConfig.getDisplayName(type)}',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyInput(String currentKey) {
    final controller = TextEditingController(text: currentKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('东方财富妙想 API Key', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '输入 API Key',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  ref.read(settingsProvider.notifier).setEmApiKey(controller.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API Key 已保存'), duration: Duration(seconds: 1)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '在东方财富妙想 Skills 页面获取',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
