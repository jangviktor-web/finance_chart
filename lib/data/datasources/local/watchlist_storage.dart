import 'package:shared_preferences/shared_preferences.dart';
import '../../models/watchlist_group.dart';

/// 自选股本地存储
class WatchlistStorage {
  static const _key = 'watchlist_groups';

  Future<List<WatchlistGroup>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) {
      return WatchlistGroup.defaultGroups();
    }
    try {
      return WatchlistGroup.listFromJson(jsonStr);
    } catch (_) {
      return WatchlistGroup.defaultGroups();
    }
  }

  Future<void> saveGroups(List<WatchlistGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, WatchlistGroup.listToJson(groups));
  }
}
