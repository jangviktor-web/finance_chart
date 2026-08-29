import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 底部导航当前选中的 Tab 索引。
///
/// 从 `MainScaffold` 的局部 State 提升为全局 Provider 的原因：
/// 切换深色/浅色模式时，`MaterialApp` 会带上新的 [ValueKey] 强制整棵
/// Element 树重建（这是让静态 `AppColors.*` 重新取色的唯一可靠手段），
/// 局部 State 会随之丢失并被重置为首页。
/// 提升到 Provider 后索引跨重建保持，用户切主题后仍停留在原来的 Tab。
final navIndexProvider = StateProvider<int>((ref) => 0);
