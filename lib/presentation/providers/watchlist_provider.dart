import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local/watchlist_storage.dart';
import '../../data/models/watchlist_group.dart';

const _uuid = Uuid();

/// 自选股状态管理
final watchlistProvider = StateNotifierProvider<WatchlistNotifier, List<WatchlistGroup>>(
  (ref) => WatchlistNotifier()..load(),
);

class WatchlistNotifier extends StateNotifier<List<WatchlistGroup>> {
  final _storage = WatchlistStorage();

  WatchlistNotifier() : super(const []);

  Future<void> load() async {
    state = await _storage.loadGroups();
  }

  Future<void> addGroup(String name) async {
    final group = WatchlistGroup(
      id: _uuid.v4(),
      name: name,
      codes: const [],
      sortOrder: state.length,
    );
    state = [...state, group];
    await _storage.saveGroups(state);
  }

  Future<void> removeGroup(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _storage.saveGroups(state);
  }

  Future<void> renameGroup(String id, String newName) async {
    state = state.map((g) => g.id == id ? g.copyWith(name: newName) : g).toList();
    await _storage.saveGroups(state);
  }

  Future<void> addStock(String groupId, String code) async {
    state = state.map((g) {
      if (g.id != groupId) return g;
      if (g.codes.contains(code)) return g;
      return g.copyWith(codes: [...g.codes, code]);
    }).toList();
    await _storage.saveGroups(state);
  }

  Future<void> removeStock(String groupId, String code) async {
    state = state.map((g) {
      if (g.id != groupId) return g;
      return g.copyWith(codes: g.codes.where((c) => c != code).toList());
    }).toList();
    await _storage.saveGroups(state);
  }

  Future<void> moveStock(String fromGroupId, String toGroupId, String code) async {
    state = state.map((g) {
      if (g.id == fromGroupId) {
        return g.copyWith(codes: g.codes.where((c) => c != code).toList());
      }
      if (g.id == toGroupId && !g.codes.contains(code)) {
        return g.copyWith(codes: [...g.codes, code]);
      }
      return g;
    }).toList();
    await _storage.saveGroups(state);
  }

  /// 检查股票是否在任何分组中被收藏
  bool isStockWatched(String code) {
    return state.any((g) => g.codes.contains(code));
  }

  /// 获取包含该股票的所有分组
  List<WatchlistGroup> groupsContaining(String code) {
    return state.where((g) => g.codes.contains(code)).toList();
  }
}
