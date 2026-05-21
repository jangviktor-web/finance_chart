import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/settings_storage.dart';
import '../../data/models/data_source_config.dart';

final settingsStorageProvider = Provider<SettingsStorage>((_) => SettingsStorage());

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref)..load();
});

/// 应用设置状态
class AppSettings {
  final bool isDarkMode;
  final String colorStyle;   // 'cn'=红涨绿跌, 'us'=绿涨红跌
  final int refreshInterval; // 秒
  final String defaultIndicator;
  final bool showMA;
  final bool autoRefresh;
  final String backendUrl;
  final bool enableSentiment;
  final bool enableMacro;
  final bool enableNews;
  final bool enableScan;
  final bool enableAi;
  final bool enableHotspot;
  final bool enablePeerCompare;
  final bool enableDeepAnalysis;
  final String emApiKey;
  final DataSourceType realtimeSource;
  final DataSourceType klineSource;
  final DataSourceType newsSource;
  final DataSourceType fundFlowSource;

  const AppSettings({
    this.isDarkMode = true,
    this.colorStyle = 'cn',
    this.refreshInterval = 5,
    this.defaultIndicator = 'MACD',
    this.showMA = true,
    this.autoRefresh = true,
    this.backendUrl = 'http://10.0.2.2:8000',
    this.enableSentiment = true,
    this.enableMacro = true,
    this.enableNews = true,
    this.enableScan = true,
    this.enableAi = true,
    this.enableHotspot = true,
    this.enablePeerCompare = true,
    this.enableDeepAnalysis = true,
    this.emApiKey = 'em_IjcEMTprwBcjOdyC7dqv1ZNJ1HlV3mIH',
    this.realtimeSource = DataSourceType.auto,
    this.klineSource = DataSourceType.auto,
    this.newsSource = DataSourceType.auto,
    this.fundFlowSource = DataSourceType.auto,
  });

  AppSettings copyWith({
    bool? isDarkMode,
    String? colorStyle,
    int? refreshInterval,
    String? defaultIndicator,
    bool? showMA,
    bool? autoRefresh,
    String? backendUrl,
    bool? enableSentiment,
    bool? enableMacro,
    bool? enableNews,
    bool? enableScan,
    bool? enableAi,
    bool? enableHotspot,
    bool? enablePeerCompare,
    bool? enableDeepAnalysis,
    String? emApiKey,
    DataSourceType? realtimeSource,
    DataSourceType? klineSource,
    DataSourceType? newsSource,
    DataSourceType? fundFlowSource,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      colorStyle: colorStyle ?? this.colorStyle,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      defaultIndicator: defaultIndicator ?? this.defaultIndicator,
      showMA: showMA ?? this.showMA,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      backendUrl: backendUrl ?? this.backendUrl,
      enableSentiment: enableSentiment ?? this.enableSentiment,
      enableMacro: enableMacro ?? this.enableMacro,
      enableNews: enableNews ?? this.enableNews,
      enableScan: enableScan ?? this.enableScan,
      enableAi: enableAi ?? this.enableAi,
      enableHotspot: enableHotspot ?? this.enableHotspot,
      enablePeerCompare: enablePeerCompare ?? this.enablePeerCompare,
      enableDeepAnalysis: enableDeepAnalysis ?? this.enableDeepAnalysis,
      emApiKey: emApiKey ?? this.emApiKey,
      realtimeSource: realtimeSource ?? this.realtimeSource,
      klineSource: klineSource ?? this.klineSource,
      newsSource: newsSource ?? this.newsSource,
      fundFlowSource: fundFlowSource ?? this.fundFlowSource,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AppSettings());

  Future<void> load() async {
    final storage = _ref.read(settingsStorageProvider);
    final results = await Future.wait([
      storage.loadDarkMode(),
      storage.loadColorStyle(),
      storage.loadRefreshInterval(),
      storage.loadDefaultIndicator(),
      storage.loadShowMA(),
      storage.loadAutoRefresh(),
      storage.loadBackendUrl(),
      storage.loadEnableSentiment(),
      storage.loadEnableMacro(),
      storage.loadEnableNews(),
      storage.loadEnableScan(),
      storage.loadEnableAi(),
      storage.loadEnableHotspot(),
      storage.loadEnablePeerCompare(),
      storage.loadEnableDeepAnalysis(),
      storage.loadEmApiKey(),
      storage.loadRealtimeSource(),
      storage.loadKlineSource(),
      storage.loadNewsSource(),
      storage.loadFundFlowSource(),
    ]);
    state = AppSettings(
      isDarkMode: results[0] as bool,
      colorStyle: results[1] as String,
      refreshInterval: results[2] as int,
      defaultIndicator: results[3] as String,
      showMA: results[4] as bool,
      autoRefresh: results[5] as bool,
      backendUrl: results[6] as String,
      enableSentiment: results[7] as bool,
      enableMacro: results[8] as bool,
      enableNews: results[9] as bool,
      enableScan: results[10] as bool,
      enableAi: results[11] as bool,
      enableHotspot: results[12] as bool,
      enablePeerCompare: results[13] as bool,
      enableDeepAnalysis: results[14] as bool,
      emApiKey: results[15] as String,
      realtimeSource: DataSourceConfig.fromString(results[16] as String),
      klineSource: DataSourceConfig.fromString(results[17] as String),
      newsSource: DataSourceConfig.fromString(results[18] as String),
      fundFlowSource: DataSourceConfig.fromString(results[19] as String),
    );
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    await _ref.read(settingsStorageProvider).saveDarkMode(value);
  }

  Future<void> setColorStyle(String value) async {
    state = state.copyWith(colorStyle: value);
    await _ref.read(settingsStorageProvider).saveColorStyle(value);
  }

  Future<void> setRefreshInterval(int value) async {
    state = state.copyWith(refreshInterval: value);
    await _ref.read(settingsStorageProvider).saveRefreshInterval(value);
  }

  Future<void> setDefaultIndicator(String value) async {
    state = state.copyWith(defaultIndicator: value);
    await _ref.read(settingsStorageProvider).saveDefaultIndicator(value);
  }

  Future<void> setShowMA(bool value) async {
    state = state.copyWith(showMA: value);
    await _ref.read(settingsStorageProvider).saveShowMA(value);
  }

  Future<void> setAutoRefresh(bool value) async {
    state = state.copyWith(autoRefresh: value);
    await _ref.read(settingsStorageProvider).saveAutoRefresh(value);
  }

  Future<void> setBackendUrl(String value) async {
    state = state.copyWith(backendUrl: value);
    await _ref.read(settingsStorageProvider).saveBackendUrl(value);
  }

  Future<void> setEnableSentiment(bool value) async {
    state = state.copyWith(enableSentiment: value);
    await _ref.read(settingsStorageProvider).saveEnableSentiment(value);
  }

  Future<void> setEnableMacro(bool value) async {
    state = state.copyWith(enableMacro: value);
    await _ref.read(settingsStorageProvider).saveEnableMacro(value);
  }

  Future<void> setEnableNews(bool value) async {
    state = state.copyWith(enableNews: value);
    await _ref.read(settingsStorageProvider).saveEnableNews(value);
  }

  Future<void> setEnableScan(bool value) async {
    state = state.copyWith(enableScan: value);
    await _ref.read(settingsStorageProvider).saveEnableScan(value);
  }

  Future<void> setEnableAi(bool value) async {
    state = state.copyWith(enableAi: value);
    await _ref.read(settingsStorageProvider).saveEnableAi(value);
  }

  Future<void> setEnableHotspot(bool value) async {
    state = state.copyWith(enableHotspot: value);
    await _ref.read(settingsStorageProvider).saveEnableHotspot(value);
  }

  Future<void> setEnablePeerCompare(bool value) async {
    state = state.copyWith(enablePeerCompare: value);
    await _ref.read(settingsStorageProvider).saveEnablePeerCompare(value);
  }

  Future<void> setEnableDeepAnalysis(bool value) async {
    state = state.copyWith(enableDeepAnalysis: value);
    await _ref.read(settingsStorageProvider).saveEnableDeepAnalysis(value);
  }

  Future<void> setEmApiKey(String value) async {
    state = state.copyWith(emApiKey: value);
    await _ref.read(settingsStorageProvider).saveEmApiKey(value);
  }

  Future<void> setRealtimeSource(DataSourceType value) async {
    state = state.copyWith(realtimeSource: value);
    await _ref.read(settingsStorageProvider).saveRealtimeSource(DataSourceConfig.toString2(value));
  }

  Future<void> setKlineSource(DataSourceType value) async {
    state = state.copyWith(klineSource: value);
    await _ref.read(settingsStorageProvider).saveKlineSource(DataSourceConfig.toString2(value));
  }

  Future<void> setNewsSource(DataSourceType value) async {
    state = state.copyWith(newsSource: value);
    await _ref.read(settingsStorageProvider).saveNewsSource(DataSourceConfig.toString2(value));
  }

  Future<void> setFundFlowSource(DataSourceType value) async {
    state = state.copyWith(fundFlowSource: value);
    await _ref.read(settingsStorageProvider).saveFundFlowSource(DataSourceConfig.toString2(value));
  }
}
