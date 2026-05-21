import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scan_result.dart';

/// 扫描历史记录存储
class ScanHistoryStorage {
  static const _key = 'scan_history';
  static const _maxRecords = 20; // 最多保留20次扫描记录

  /// 加载扫描历史
  Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final list = json.decode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// 保存一次扫描结果
  Future<void> saveScan(List<ScanResult> results, ScanConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();

    final record = {
      'scanTime': DateTime.now().toIso8601String(),
      'strategy': config.strategy,
      'resultCount': results.length,
      'results': results.map((r) => r.toJson()).toList(),
    };

    history.insert(0, record);
    if (history.length > _maxRecords) {
      history.removeRange(_maxRecords, history.length);
    }

    await prefs.setString(_key, json.encode(history));
  }

  /// 清空历史
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
