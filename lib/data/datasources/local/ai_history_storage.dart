import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai_report.dart';

/// AI 查询历史存储
class AiHistoryStorage {
  static const _key = 'ai_query_history';
  static const _maxRecords = 30;

  /// 保存一条查询记录
  Future<void> saveRecord(AiQueryRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, record);
    if (history.length > _maxRecords) {
      history.removeRange(_maxRecords, history.length);
    }
    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  /// 加载历史记录（可按类型筛选）
  Future<List<AiQueryRecord>> loadHistory({String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final list = json.decode(jsonStr) as List;
      final records = list
          .map((e) => AiQueryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (type != null) {
        return records.where((r) => r.type == type).toList();
      }
      return records;
    } catch (_) {
      return [];
    }
  }

  /// 删除一条记录
  Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.removeWhere((r) => r.id == id);
    final jsonList = history.map((r) => r.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  /// 清空历史
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
