import 'dart:ui';

/// 形态类型枚举
enum PatternType {
  wBottom,        // W底
  vReversal,      // V型反转
  cupHandle,      // 杯柄形态
  tripleBottom,   // 三重底
  dipBuy,         // 回踩买入
  headShoulder,   // 头肩顶
}

/// 形态检测结果
class PatternResult {
  final PatternType type;
  final String name;
  final String description;
  final double confidence;    // 0-1
  final int startIndex;
  final int endIndex;
  final List<Offset> pivotPoints;  // 枢轴点（用于绘制）
  final bool isBullish;

  const PatternResult({
    required this.type,
    required this.name,
    required this.description,
    required this.confidence,
    required this.startIndex,
    required this.endIndex,
    required this.pivotPoints,
    required this.isBullish,
  });

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  String get typeLabel {
    switch (type) {
      case PatternType.wBottom:
        return 'W底';
      case PatternType.vReversal:
        return 'V型反转';
      case PatternType.cupHandle:
        return '杯柄形态';
      case PatternType.tripleBottom:
        return '三重底';
      case PatternType.dipBuy:
        return '回踩买入';
      case PatternType.headShoulder:
        return '头肩顶';
    }
  }
}
