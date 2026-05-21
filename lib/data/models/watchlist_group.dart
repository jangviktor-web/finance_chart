import 'dart:convert';

/// 自选股分组
class WatchlistGroup {
  final String id;
  final String name;
  final List<String> codes;
  final int sortOrder;

  const WatchlistGroup({
    required this.id,
    required this.name,
    required this.codes,
    this.sortOrder = 0,
  });

  /// 默认分组列表
  static List<WatchlistGroup> defaultGroups() => [
    const WatchlistGroup(
      id: 'default',
      name: '自选',
      codes: [
        'sh600519', 'sh601318', 'sz000858', 'sh600036',
        'sz000333', 'sh601166', 'sz002415', 'sh600276',
      ],
      sortOrder: 0,
    ),
  ];

  WatchlistGroup copyWith({
    String? id,
    String? name,
    List<String>? codes,
    int? sortOrder,
  }) {
    return WatchlistGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      codes: codes ?? this.codes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'codes': codes,
    'sortOrder': sortOrder,
  };

  factory WatchlistGroup.fromJson(Map<String, dynamic> json) {
    return WatchlistGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      codes: (json['codes'] as List).cast<String>(),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  static List<WatchlistGroup> listFromJson(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return list.map((e) => WatchlistGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<WatchlistGroup> groups) {
    return json.encode(groups.map((g) => g.toJson()).toList());
  }
}
