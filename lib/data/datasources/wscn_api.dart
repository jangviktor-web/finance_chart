import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/news_data.dart';
import '../models/calendar_data.dart';

/// 华尔街见闻 API（B1 快讯 + A4 财经日历）
/// 源：https://api-one-wscn.awtmt.com/apiv1（a-stock-data-quant §8.5/§8.6）
class WscnApi {
  static const _base = 'https://api-one-wscn.awtmt.com/apiv1';

  Map<String, String> get _headers => {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
        'Referer': 'https://wallstreetcn.com/',
        'Accept': 'application/json',
        'x-client-type': 'pc',
        'x-ivanka-app': 'wscn|web|0.40.40|0.0|0',
      };

  /// 获取快讯（B1）
  Future<List<LiveNewsItem>> getLives({
    String channel = 'global-channel',
    int limit = 20,
  }) async {
    final url = '$_base/content/lives?channel=$channel&client=pc&limit=$limit&first_page=true&accept=live,vip-live';
    await RateLimiter.instance.waitByUrl(url);

    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      _headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.fold<List<int>>(
        <int>[],
        (buf, chunk) => buf..addAll(chunk),
      );
      final data = json.decode(utf8.decode(body, allowMalformed: true));

      if (data is! Map<String, dynamic> || data['code'] != 20000) return [];
      final items = (data['data'] as Map<String, dynamic>?)?['items'];
      if (items is! List) return [];

      final results = <LiveNewsItem>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        var content = (item['content_text'] ?? '').toString().trim();
        if (content.isEmpty) {
          content = (item['content'] ?? '').toString().replaceAll(RegExp(r'<[^>]+>'), '').trim();
        }
        if (content.isEmpty) continue;
        final ts = item['display_time'];
        final time = ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000) : DateTime.now();
        results.add(LiveNewsItem(
          content: content,
          time: time,
          stockName: (item['author'] as Map<String, dynamic>?)?['display_name']?.toString(),
        ));
      }
      return results;
    } on Exception catch (e) {
      AppLog.instance.info('WscnApi', '获取华尔街见闻快讯失败: $e');
      return [];
    } finally {
      client.close();
    }
  }

  /// 获取财经日历（A4）
  Future<List<CalendarEvent>> getCalendar({
    String channel = 'global-channel',
    int limit = 20,
  }) async {
    final url = '$_base/calendar?channel=$channel&client=pc&limit=$limit';
    await RateLimiter.instance.waitByUrl(url);

    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      _headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.fold<List<int>>(
        <int>[],
        (buf, chunk) => buf..addAll(chunk),
      );
      final data = json.decode(utf8.decode(body, allowMalformed: true));

      if (data is! Map<String, dynamic> || data['code'] != 20000) return [];
      final items = (data['data'] as Map<String, dynamic>?)?['items'];
      if (items is! List) return [];

      final results = <CalendarEvent>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final title = (item['title'] ?? item['event'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final ts = item['public_date'];
        final time = ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000) : DateTime.now();
        results.add(CalendarEvent(
          title: title,
          country: (item['country'] ?? '').toString(),
          time: time,
          importance: (item['importance'] as num?)?.toInt() ?? 0,
          actual: (item['actual'] ?? '').toString(),
          forecast: (item['forecast'] ?? '').toString(),
          previous: (item['previous'] ?? '').toString(),
          period: (item['period'] ?? '').toString(),
        ));
      }
      return results;
    } on Exception catch (e) {
      AppLog.instance.info('WscnApi', '获取财经日历失败: $e');
      return [];
    } finally {
      client.close();
    }
  }
}
