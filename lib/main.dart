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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    runApp(const ProviderScope(child: FinanceApp()));
  }, (error, stack) {
    AppLog.instance.error(
      'Uncaught',
      error.toString(),
      stack.toString(),
    );
  });
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // 根据设置应用主题和涨跌色
    AppColors.setDarkMode(settings.isDarkMode);
    AppColors.setColorStyle(settings.colorStyle);

    return MaterialApp(
      title: '策盈',
      debugShowCheckedModeBanner: false,
      theme: settings.isDarkMode ? darkTheme : lightTheme,
      home: const MainScaffold(),
    );
  }
}
