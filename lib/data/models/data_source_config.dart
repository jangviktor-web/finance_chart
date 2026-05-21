/// 数据源类型枚举
enum DataSourceType {
  /// 东方财富
  eastmoney,

  /// 腾讯财经
  tencent,

  /// 新浪财经
  sina,

  /// 百度财经
  baidu,

  /// 自动模式（按优先级降级）
  auto,
}

/// 数据源配置
class DataSourceConfig {
  /// 实时行情数据源
  final DataSourceType realtimeSource;

  /// K线数据源
  final DataSourceType klineSource;

  /// 新闻数据源
  final DataSourceType newsSource;

  /// 资金流向数据源
  final DataSourceType fundFlowSource;

  const DataSourceConfig({
    this.realtimeSource = DataSourceType.auto,
    this.klineSource = DataSourceType.auto,
    this.newsSource = DataSourceType.auto,
    this.fundFlowSource = DataSourceType.auto,
  });

  DataSourceConfig copyWith({
    DataSourceType? realtimeSource,
    DataSourceType? klineSource,
    DataSourceType? newsSource,
    DataSourceType? fundFlowSource,
  }) {
    return DataSourceConfig(
      realtimeSource: realtimeSource ?? this.realtimeSource,
      klineSource: klineSource ?? this.klineSource,
      newsSource: newsSource ?? this.newsSource,
      fundFlowSource: fundFlowSource ?? this.fundFlowSource,
    );
  }

  /// 从字符串解析
  static DataSourceType fromString(String value) {
    switch (value) {
      case 'eastmoney': return DataSourceType.eastmoney;
      case 'tencent': return DataSourceType.tencent;
      case 'sina': return DataSourceType.sina;
      case 'baidu': return DataSourceType.baidu;
      case 'auto': return DataSourceType.auto;
      default: return DataSourceType.auto;
    }
  }

  /// 转换为字符串
  static String toString2(DataSourceType type) {
    return type.toString().split('.').last;
  }

  /// 获取显示名称
  static String getDisplayName(DataSourceType type) {
    switch (type) {
      case DataSourceType.eastmoney: return '东方财富';
      case DataSourceType.tencent: return '腾讯财经';
      case DataSourceType.sina: return '新浪财经';
      case DataSourceType.baidu: return '百度财经';
      case DataSourceType.auto: return '自动选择';
    }
  }

  /// 获取数据源图标
  static String getIcon(DataSourceType type) {
    switch (type) {
      case DataSourceType.eastmoney: return '📊';
      case DataSourceType.tencent: return '🐧';
      case DataSourceType.sina: return '📱';
      case DataSourceType.baidu: return '🔍';
      case DataSourceType.auto: return '⚡';
    }
  }
}
