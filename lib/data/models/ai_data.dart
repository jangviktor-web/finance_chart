/// AI 诊断结果
class AiDiagnosisResult {
  final String code;
  final String name;
  final String summary;
  final String suggestion;
  final String riskLevel; // 低/中/高
  final List<String> signals;

  const AiDiagnosisResult({
    required this.code,
    required this.name,
    required this.summary,
    required this.suggestion,
    required this.riskLevel,
    this.signals = const [],
  });
}

/// AI 选股结果
class AiStockPick {
  final String code;
  final String name;
  final String reason;
  final double score;
  final double? price;
  final double? changePercent;

  const AiStockPick({
    required this.code,
    required this.name,
    required this.reason,
    this.score = 0,
    this.price,
    this.changePercent,
  });
}

/// AI 对话消息
class AiChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const AiChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
