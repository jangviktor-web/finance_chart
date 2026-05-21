/// 热点资讯条目
class HotspotItem {
  final int rank;
  final String title;
  final String content;
  final String time;

  HotspotItem({
    required this.rank,
    required this.title,
    required this.content,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'title': title,
    'content': content,
    'time': time,
  };

  factory HotspotItem.fromJson(Map<String, dynamic> json) => HotspotItem(
    rank: json['rank'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    time: json['time'] as String? ?? '',
  );
}

/// 可比公司分析数据
class ComparableCompanyData {
  final String targetCompany;
  final List<String> companies;
  final List<String> financeHeaders;
  final List<List<String>> financeData;
  final List<String> valuationHeaders;
  final List<List<String>> valuationData;

  ComparableCompanyData({
    required this.targetCompany,
    required this.companies,
    required this.financeHeaders,
    required this.financeData,
    required this.valuationHeaders,
    required this.valuationData,
  });

  Map<String, dynamic> toJson() => {
    'targetCompany': targetCompany,
    'companies': companies,
    'financeHeaders': financeHeaders,
    'financeData': financeData,
    'valuationHeaders': valuationHeaders,
    'valuationData': valuationData,
  };

  factory ComparableCompanyData.fromJson(Map<String, dynamic> json) =>
      ComparableCompanyData(
        targetCompany: json['targetCompany'] as String? ?? '',
        companies: (json['companies'] as List?)?.cast<String>() ?? [],
        financeHeaders: (json['financeHeaders'] as List?)?.cast<String>() ?? [],
        financeData: (json['financeData'] as List?)
            ?.map((e) => (e as List).cast<String>())
            .toList() ?? [],
        valuationHeaders: (json['valuationHeaders'] as List?)?.cast<String>() ?? [],
        valuationData: (json['valuationData'] as List?)
            ?.map((e) => (e as List).cast<String>())
            .toList() ?? [],
      );
}

/// 通用 AI 查询历史记录
class AiQueryRecord {
  final String id;
  final String type;      // 'hotspot' / 'comparable' / 'diagnosis'
  final String query;
  final String resultMarkdown;
  final DateTime timestamp;

  AiQueryRecord({
    required this.id,
    required this.type,
    required this.query,
    required this.resultMarkdown,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'query': query,
    'resultMarkdown': resultMarkdown,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AiQueryRecord.fromJson(Map<String, dynamic> json) => AiQueryRecord(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? '',
    query: json['query'] as String? ?? '',
    resultMarkdown: json['resultMarkdown'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}
