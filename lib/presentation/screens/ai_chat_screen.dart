import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/datasources/em_ai_api.dart';
import '../../data/models/ai_data.dart';
import '../providers/settings_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  final String? initialName;

  const AiChatScreen({super.key, this.initialCode, this.initialName});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  EmAiApi? _api;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <AiChatMessage>[];
  bool _isLoading = false;

  EmAiApi _getApi() {
    final settings = ref.read(settingsProvider);
    if (_api == null) {
      _api = EmAiApi(apiKey: settings.emApiKey);
    } else {
      _api!.updateApiKey(settings.emApiKey);
    }
    return _api!;
  }

  @override
  void initState() {
    super.initState();
    // 欢迎消息
    _messages.add(AiChatMessage(
      role: 'assistant',
      content: '你好！我是 AI 助手，可以帮你：\n\n'
          '• 查询股票数据（如"贵州茅台最新价"）\n'
          '• 筛选股票（如"今日涨幅超过5%的股票"）\n'
          '• 分析板块（如"半导体板块资金流向"）\n\n'
          '有什么想了解的？',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = AiChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _getApi().chat(text, code: widget.initialCode);
      final assistantMsg = AiChatMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(assistantMsg);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: '请求失败: $e',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _diagnoseStock() async {
    final code = widget.initialCode;
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一只股票')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _messages.add(AiChatMessage(
      role: 'user',
      content: '诊断 $code',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();

    try {
      final result = await _getApi().diagnose(code);
      final buffer = StringBuffer();
      buffer.writeln('【${result.name} ($code) 诊断结果】');
      buffer.writeln('');
      buffer.writeln(result.summary);
      buffer.writeln('');
      buffer.writeln('风险等级: ${result.riskLevel}');
      buffer.writeln('建议: ${result.suggestion}');
      if (result.signals.isNotEmpty) {
        buffer.writeln('信号: ${result.signals.join('、')}');
      }

      setState(() {
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: buffer.toString(),
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: '诊断失败: $e',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _selectStocks() async {
    setState(() => _isLoading = true);
    _messages.add(AiChatMessage(
      role: 'user',
      content: '推荐潜力股',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();

    try {
      final stocks = await _getApi().selectStocks('今日涨幅超过2%的股票');
      final buffer = StringBuffer();
      buffer.writeln('【潜力股推荐】');
      buffer.writeln('');
      if (stocks.isEmpty) {
        buffer.writeln('暂无符合条件的股票');
      } else {
        for (int i = 0; i < stocks.length && i < 10; i++) {
          final s = stocks[i];
          final price = s.price != null ? s.price!.toStringAsFixed(2) : '--';
          final change = s.changePercent != null
              ? '${s.changePercent! >= 0 ? '+' : ''}${s.changePercent!.toStringAsFixed(2)}%'
              : '--';
          buffer.writeln('${i + 1}. ${s.name} (${s.code}) $price $change');
        }
      }

      setState(() {
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: buffer.toString(),
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AiChatMessage(
          role: 'assistant',
          content: '选股失败: $e',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.initialName != null
            ? 'AI 助手 - ${widget.initialName}'
            : 'AI 助手'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 快捷操作
          _buildQuickActions(),
          // 消息列表
          Expanded(child: _buildMessageList()),
          // 输入框
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          if (widget.initialCode != null)
            _buildChip('诊断股票', Icons.analytics, _diagnoseStock),
          if (widget.initialCode != null) const SizedBox(width: 8),
          _buildChip('潜力股', Icons.trending_up, _selectStocks),
          const SizedBox(width: 8),
          _buildChip('大盘', Icons.show_chart, () => _sendMessage('上证指数最新行情')),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: TextStyle(color: AppColors.primary, fontSize: 12)),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      onPressed: onTap,
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(AiChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          msg.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (ctx, value, child) {
        final delay = index * 0.2;
        final opacity = ((value - delay) % 1.0).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity < 0.5 ? opacity * 2 : (1 - opacity) * 2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '输入问题...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
