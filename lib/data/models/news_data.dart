/// 新闻条目
class NewsItem {
  final String title;
  final String digest;
  final String source;
  final DateTime time;
  final String url;
  final String? imageUrl;
  final List<String> stockCodes;  // 关联股票

  const NewsItem({
    required this.title,
    this.digest = '',
    this.source = '',
    required this.time,
    this.url = '',
    this.imageUrl,
    this.stockCodes = const [],
  });
}

/// 7x24 快讯
class LiveNewsItem {
  final String content;
  final DateTime time;
  final String? stockCode;
  final String? stockName;

  const LiveNewsItem({
    required this.content,
    required this.time,
    this.stockCode,
    this.stockName,
  });
}
