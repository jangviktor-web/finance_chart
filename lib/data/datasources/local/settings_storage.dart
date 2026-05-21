import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置本地持久化
class SettingsStorage {
  static const _keyDarkMode = 'setting_dark_mode';
  static const _keyColorStyle = 'setting_color_style'; // 'cn' or 'us'
  static const _keyRefreshInterval = 'setting_refresh_interval';
  static const _keyDefaultIndicator = 'setting_default_indicator';
  static const _keyShowMA = 'setting_show_ma';
  static const _keyAutoRefresh = 'setting_auto_refresh';
  static const _keyBackendUrl = 'setting_backend_url';
  static const _keyEnableSentiment = 'setting_enable_sentiment';
  static const _keyEnableMacro = 'setting_enable_macro';
  static const _keyEnableNews = 'setting_enable_news';
  static const _keyEnableScan = 'setting_enable_scan';
  static const _keyEnableAi = 'setting_enable_ai';
  static const _keyEnableHotspot = 'setting_enable_hotspot';
  static const _keyEnablePeerCompare = 'setting_enable_peer_compare';
  static const _keyEnableDeepAnalysis = 'setting_enable_deep_analysis';
  static const _keyEmApiKey = 'setting_em_api_key';
  static const _keyRealtimeSource = 'setting_realtime_source';
  static const _keyKlineSource = 'setting_kline_source';
  static const _keyNewsSource = 'setting_news_source';
  static const _keyFundFlowSource = 'setting_fund_flow_source';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── 读取 ──

  Future<bool> loadDarkMode() async =>
      (await _prefs).getBool(_keyDarkMode) ?? true;

  Future<String> loadColorStyle() async =>
      (await _prefs).getString(_keyColorStyle) ?? 'cn';

  Future<int> loadRefreshInterval() async =>
      (await _prefs).getInt(_keyRefreshInterval) ?? 5;

  Future<String> loadDefaultIndicator() async =>
      (await _prefs).getString(_keyDefaultIndicator) ?? 'MACD';

  Future<bool> loadShowMA() async =>
      (await _prefs).getBool(_keyShowMA) ?? true;

  Future<bool> loadAutoRefresh() async =>
      (await _prefs).getBool(_keyAutoRefresh) ?? true;

  Future<String> loadBackendUrl() async =>
      (await _prefs).getString(_keyBackendUrl) ?? 'http://10.0.2.2:8000';

  Future<bool> loadEnableSentiment() async =>
      (await _prefs).getBool(_keyEnableSentiment) ?? true;

  Future<bool> loadEnableMacro() async =>
      (await _prefs).getBool(_keyEnableMacro) ?? true;

  Future<bool> loadEnableNews() async =>
      (await _prefs).getBool(_keyEnableNews) ?? true;

  Future<bool> loadEnableScan() async =>
      (await _prefs).getBool(_keyEnableScan) ?? true;

  Future<bool> loadEnableAi() async =>
      (await _prefs).getBool(_keyEnableAi) ?? true;

  Future<bool> loadEnableHotspot() async =>
      (await _prefs).getBool(_keyEnableHotspot) ?? true;

  Future<bool> loadEnablePeerCompare() async =>
      (await _prefs).getBool(_keyEnablePeerCompare) ?? true;

  Future<bool> loadEnableDeepAnalysis() async =>
      (await _prefs).getBool(_keyEnableDeepAnalysis) ?? true;

  Future<String> loadEmApiKey() async =>
      (await _prefs).getString(_keyEmApiKey) ?? 'em_IjcEMTprwBcjOdyC7dqv1ZNJ1HlV3mIH';

  Future<String> loadRealtimeSource() async =>
      (await _prefs).getString(_keyRealtimeSource) ?? 'auto';

  Future<String> loadKlineSource() async =>
      (await _prefs).getString(_keyKlineSource) ?? 'auto';

  Future<String> loadNewsSource() async =>
      (await _prefs).getString(_keyNewsSource) ?? 'auto';

  Future<String> loadFundFlowSource() async =>
      (await _prefs).getString(_keyFundFlowSource) ?? 'auto';

  // ── 写入 ──

  Future<void> saveDarkMode(bool value) async =>
      (await _prefs).setBool(_keyDarkMode, value);

  Future<void> saveColorStyle(String value) async =>
      (await _prefs).setString(_keyColorStyle, value);

  Future<void> saveRefreshInterval(int value) async =>
      (await _prefs).setInt(_keyRefreshInterval, value);

  Future<void> saveDefaultIndicator(String value) async =>
      (await _prefs).setString(_keyDefaultIndicator, value);

  Future<void> saveShowMA(bool value) async =>
      (await _prefs).setBool(_keyShowMA, value);

  Future<void> saveAutoRefresh(bool value) async =>
      (await _prefs).setBool(_keyAutoRefresh, value);

  Future<void> saveBackendUrl(String value) async =>
      (await _prefs).setString(_keyBackendUrl, value);

  Future<void> saveEnableSentiment(bool value) async =>
      (await _prefs).setBool(_keyEnableSentiment, value);

  Future<void> saveEnableMacro(bool value) async =>
      (await _prefs).setBool(_keyEnableMacro, value);

  Future<void> saveEnableNews(bool value) async =>
      (await _prefs).setBool(_keyEnableNews, value);

  Future<void> saveEnableScan(bool value) async =>
      (await _prefs).setBool(_keyEnableScan, value);

  Future<void> saveEnableAi(bool value) async =>
      (await _prefs).setBool(_keyEnableAi, value);

  Future<void> saveEnableHotspot(bool value) async =>
      (await _prefs).setBool(_keyEnableHotspot, value);

  Future<void> saveEnablePeerCompare(bool value) async =>
      (await _prefs).setBool(_keyEnablePeerCompare, value);

  Future<void> saveEnableDeepAnalysis(bool value) async =>
      (await _prefs).setBool(_keyEnableDeepAnalysis, value);

  Future<void> saveEmApiKey(String value) async =>
      (await _prefs).setString(_keyEmApiKey, value);

  Future<void> saveRealtimeSource(String value) async =>
      (await _prefs).setString(_keyRealtimeSource, value);

  Future<void> saveKlineSource(String value) async =>
      (await _prefs).setString(_keyKlineSource, value);

  Future<void> saveNewsSource(String value) async =>
      (await _prefs).setString(_keyNewsSource, value);

  Future<void> saveFundFlowSource(String value) async =>
      (await _prefs).setString(_keyFundFlowSource, value);
}
