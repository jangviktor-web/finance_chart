import 'package:shared_preferences/shared_preferences.dart';

/// ETF 轮动的本地状态：
/// - 上次 Top N 快照（用于「上榜 / 出榜」调仓提示；只存代码列表，顺序有意义）
/// - 池子是否被用户自定义过（用于代码里的默认池换代时安全迁移）
class EtfRotationSnapshotStorage {
  static const _key = 'etf_rotation_last_top';
  static const _customizedKey = 'etf_rotation_pool_customized';

  /// 读取上次快照；无记录时返回空列表（调用方据此判定「首次运行」）。
  Future<List<String>> loadLastTop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  /// 保存本次 Top N 作为下次对比基准。
  Future<void> saveLastTop(List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, codes);
  }

  /// 用户是否增删过轮动池。一旦为 true，默认池换代不再覆盖用户的选择。
  Future<bool> isPoolCustomized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_customizedKey) ?? false;
  }

  /// 标记「用户已自定义过池子」（添加 / 移除时调用）。
  Future<void> markPoolCustomized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customizedKey, true);
  }
}
