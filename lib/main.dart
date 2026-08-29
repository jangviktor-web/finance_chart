import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'core/utils/app_logger.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLog.instance.error(
      'FlutterError',
      details.exceptionAsString(),
      details.stack?.toString(),
    );
  };

  runZonedGuarded(() {
    // 启动阶段先按默认（深色）下发一次，真实值会在首帧后按用户设置覆盖。
    _applyStatusBarStyle(true);

    runApp(const ProviderScope(child: FinanceApp()));
  }, (error, stack) {
    AppLog.instance.error(
      'Uncaught',
      error.toString(),
      stack.toString(),
    );
  });
}

/// 最近一次已下发到状态栏的图标亮度，用于去重，避免每次 build 都走平台通道。
Brightness? _lastStatusBarIconBrightness;

/// 状态栏图标亮度跟随主题：深色背景用浅色图标，浅色背景用深色图标。
///
/// 注意 iOS 的 `statusBarBrightness` 语义与 Android 的
/// `statusBarIconBrightness` 相反 —— 它描述的是「状态栏背景亮度」，
/// 所以浅色模式下要传 [Brightness.light] 才能得到深色图标。
void _applyStatusBarStyle(bool isDarkMode) {
  final iconBrightness = isDarkMode ? Brightness.light : Brightness.dark;
  if (_lastStatusBarIconBrightness == iconBrightness) {
    return;
  }
  _lastStatusBarIconBrightness = iconBrightness;

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
  ));
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // 颜色系统的唯一同步入口：先更新静态标志位，再让整棵树重建。
    // 顺序至关重要 —— 必须在 MaterialApp 及其子树 build 之前完成。
    AppColors.applyTheme(
      isDarkMode: settings.isDarkMode,
      colorStyle: settings.colorStyle,
    );

    // 状态栏图标亮度改为跟随主题（原来硬编码为 Brightness.light，
    // 导致浅色模式下浅色图标配浅色背景几乎看不见）。
    // 放到帧后执行，避免在 build 阶段产生平台通道副作用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyStatusBarStyle(settings.isDarkMode);
    });

    return MaterialApp(
      // 关键修复：AppColors.* 是静态 getter，使用它的 Widget 不依赖 Theme，
      // 切主题时不会被标脏重建 —— 这正是「背景变、字体不变」的根因。
      // 这里用与主题签名绑定的 ValueKey 强制 MaterialApp 连同整棵子树重建，
      // 使所有显式取色的 Widget 在重建时重新读取 AppColors.*。
      // 当前 Tab 由 navIndexProvider 保存，重建后不会退回首页。
      // 关键修复：AppColors.* 是静态 getter，使用它的 Widget 不依赖 Theme，
      // 切主题时不会被标脏重建 —— 这正是「背景变、字体不变」的根因。
      // 用与主题签名绑定的 ValueKey 强制 MaterialApp 连同整棵子树重建。
      // 经真实 App 集成测试对照验证：移除本 Key 后浅色模式字体不再翻转
      // （稳定复现用户报的 Bug），故本 Key 必需，不可省略。
      key: ValueKey('finance_app_${AppColors.themeSignature}'),
      title: '策盈',
      debugShowCheckedModeBanner: false,
      theme: settings.isDarkMode ? darkTheme : lightTheme,
      home: const MainScaffold(),
    );
  }
}
