import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/news_data.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';

/// 新闻资讯 API — 多源降级
class NewsApi {
  final Dio _dio;

  NewsApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://finance.eastmoney.com/',
          },
        ));

  /// 东方财富 7x24 快讯（主数据源）
  Future<List<LiveNewsItem>> get7x24News({int page = 1, int pageSize = 20}) async {
    await RateLimiter.instance.wait('np-listapi.eastmoney.com');
    try {
      final params = {
        'client': 'web',
        'biz': 'web_724',
        'column': '724',
        'page': '$page',
        'pageSize': '$pageSize',
        'req_trace': '${DateTime.now().millisecondsSinceEpoch}',
      };

      final response = await _dio.get(ApiEndpoints.news7x24, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      // 兼容多种响应结构
      List list = [];
      if (data['data'] is Map) {
        list = data['data']['list'] ?? data['data']['data'] ?? [];
      } else if (data['data'] is List) {
        list = data['data'];
      }

      if (list.isNotEmpty) {
        return list.map((item) {
          final content = item['summary']?.toString() ?? item['digest']?.toString() ?? item['title']?.toString() ?? '';
          final stockCode = item['stock_list'] is List && (item['stock_list'] as List).isNotEmpty
              ? (item['stock_list'] as List).first['code']?.toString()
              : null;
          final stockName = item['stock_list'] is List && (item['stock_list'] as List).isNotEmpty
              ? (item['stock_list'] as List).first['name']?.toString()
              : null;

          // 时间字段: showTime (大写T) 或 showtime 或 time
          final timeStr = item['showTime']?.toString() ?? item['showtime']?.toString() ?? item['time']?.toString() ?? '';

          return LiveNewsItem(
            content: _stripHtml(content),
            time: DateTime.tryParse(timeStr) ?? DateTime.now(),
            stockCode: stockCode,
            stockName: stockName,
          );
        }).toList();
      }
    } catch (_) {}

    // 降级：尝试新浪 7x24
    return _fetchSinaLiveNews(page: page, pageSize: pageSize);
  }

  /// 新浪 7x24 快讯（备用数据源）
  Future<List<LiveNewsItem>> _fetchSinaLiveNews({int page = 1, int pageSize = 20}) async {
    await RateLimiter.instance.wait('zhibo.sina.com.cn');
    try {
      final url = 'https://zhibo.sina.com.cn/api/zhibo/feedlist';
      final params = {
        'page': '$page',
        'page_size': '$pageSize',
        'zhibo_id': '152',
        'tag_id': '0',
        'type': '0',
      };
      final response = await _dio.get(url, queryParameters: params);
      final data = response.data is String ? json.decode(response.data) : response.data;

      final List list = data['result']?['data']?['feed']?['list'] ?? [];
      return list.map((item) {
        final content = item['rich_text']?.toString() ?? item['text_tag']?.toString() ?? '';
        return LiveNewsItem(
          content: _stripHtml(content),
          time: DateTime.tryParse(item['create_time']?.toString() ?? '') ?? DateTime.now(),
          stockCode: null,
          stockName: null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 财联社快讯（多版本降级）
  Future<List<LiveNewsItem>> getCLSNews({int page = 1, int pageSize = 20}) async {
    await RateLimiter.instance.wait('cls.cn');
    // 尝试多个版本的 CLS API
    final versions = ['8.4.6', '8.0.0', '7.7.5', '7.5.0'];

    for (final sv in versions) {
      try {
        final params = {
          'app': 'CailianpressWeb',
          'os': 'web',
          'sv': sv,
          'rn': '$pageSize',
          'page': '$page',
        };

        final response = await _dio.get(ApiEndpoints.clsNews, queryParameters: params);
        final data = response.data is String ? json.decode(response.data) : response.data;

        // 兼容多种响应路径
        List list = [];
        if (data['data'] is Map) {
          list = data['data']['roll_data'] ?? data['data']['list'] ?? data['data']['data'] ?? [];
        } else if (data['data'] is List) {
          list = data['data'];
        }

        if (list.isNotEmpty) {
          return list.map((item) {
            final content = item['content']?.toString() ?? item['title']?.toString() ?? '';
            return LiveNewsItem(
              content: _stripHtml(content),
              time: DateTime.fromMillisecondsSinceEpoch(
                  (_toInt(item['ctime']) > 0 ? _toInt(item['ctime']) : _toInt(item['mtime'])) * 1000),
              stockCode: item['stock_list'] is List && (item['stock_list'] as List).isNotEmpty
                  ? (item['stock_list'] as List).first['stock_code']?.toString()
                  : null,
              stockName: item['stock_list'] is List && (item['stock_list'] as List).isNotEmpty
                  ? (item['stock_list'] as List).first['stock_name']?.toString()
                  : null,
            );
          }).toList();
        }
      } catch (_) {
        continue;
      }
    }

    // CLS 全部失败，降级到 7x24
    AppLog.instance.warn('NewsApi', 'CLS 所有版本均失败，降级到 7x24');
    return get7x24News(page: page, pageSize: pageSize);
  }

  /// 东方财富新闻搜索（JSONP + 降级）
  Future<List<NewsItem>> searchNews(String keyword, {int page = 1, int pageSize = 20}) async {
    await RateLimiter.instance.wait('search-api-web.eastmoney.com');
    // 尝试 JSONP 格式
    try {
      final result = await _searchNewsJsonp(keyword, page: page, pageSize: pageSize);
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // 降级：尝试直接 JSON 格式（不带 cb 参数）
    try {
      final result = await _searchNewsJson(keyword, page: page, pageSize: pageSize);
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // 降级：尝试东方财富资讯搜索 v2
    return _searchNewsV2(keyword, page: page, pageSize: pageSize);
  }

  Future<List<NewsItem>> _searchNewsJsonp(String keyword, {int page = 1, int pageSize = 20}) async {
    final cb = 'jQuery_${DateTime.now().millisecondsSinceEpoch}';
    final params = {
      'cb': cb,
      'param': json.encode({
        'uid': '',
        'keyword': keyword,
        'type': ['cmsArticleWebOld'],
        'client': 'web',
        'clientType': 'web',
        'clientVersion': 'curr',
        'param': {
          'cmsArticleWebOld': {
            'searchScope': 'default',
            'sort': 'default',
            'pageIndex': page,
            'pageSize': pageSize,
            'preTag': '',
            'postTag': '',
          }
        }
      }),
    };

    final response = await _dio.get(ApiEndpoints.newsSearch, queryParameters: params);
    var body = response.data is String ? response.data as String : json.encode(response.data);

    // 去掉 JSONP 包裹
    final jsonStart = body.indexOf('(');
    final jsonEnd = body.lastIndexOf(')');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      body = body.substring(jsonStart + 1, jsonEnd);
    }

    return _parseSearchResults(body);
  }

  Future<List<NewsItem>> _searchNewsJson(String keyword, {int page = 1, int pageSize = 20}) async {
    final params = {
      'param': json.encode({
        'uid': '',
        'keyword': keyword,
        'type': ['cmsArticleWebOld'],
        'client': 'web',
        'clientType': 'web',
        'clientVersion': 'curr',
        'param': {
          'cmsArticleWebOld': {
            'searchScope': 'default',
            'sort': 'default',
            'pageIndex': page,
            'pageSize': pageSize,
            'preTag': '',
            'postTag': '',
          }
        }
      }),
    };

    final response = await _dio.get(ApiEndpoints.newsSearch, queryParameters: params);
    final body = response.data is String ? response.data as String : json.encode(response.data);
    return _parseSearchResults(body);
  }

  /// 东方财富资讯搜索 v2（备用端点）
  Future<List<NewsItem>> _searchNewsV2(String keyword, {int page = 1, int pageSize = 20}) async {
    try {
      final url = 'https://search-api-web.eastmoney.com/search/jsonp';
      final cb = 'jQuery_${DateTime.now().millisecondsSinceEpoch}';
      final params = {
        'cb': cb,
        'param': json.encode({
          'uid': '',
          'keyword': keyword,
          'type': ['cmsArticleWebOld'],
          'client': 'web',
          'clientType': 'web',
          'clientVersion': 'curr',
          'param': {
            'cmsArticleWebOld': {
              'searchScope': 'default',
              'sort': 'default',
              'pageIndex': page,
              'pageSize': pageSize,
            }
          }
        }),
      };

      final response = await _dio.get(url, queryParameters: params);
      var body = response.data is String ? response.data as String : json.encode(response.data);

      final jsonStart = body.indexOf('(');
      final jsonEnd = body.lastIndexOf(')');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        body = body.substring(jsonStart + 1, jsonEnd);
      }

      return _parseSearchResults(body);
    } catch (_) {
      return [];
    }
  }

  /// 东方财富个股新闻搜索（按名称搜索，效果优于代码）
  /// PanWatch 模式：用股票名称搜索，支持行业/主题关键词
  Future<List<NewsItem>> searchNewsByName(String keyword, {int page = 1, int pageSize = 15}) async {
    await RateLimiter.instance.wait('search-api-web.eastmoney.com');
    try {
      final cb = 'jQuery_${DateTime.now().millisecondsSinceEpoch}';
      final params = {
        'cb': cb,
        'param': json.encode({
          'uid': '',
          'keyword': keyword,
          'type': ['cmsArticleWebOld'],
          'client': 'web',
          'clientType': 'web',
          'clientVersion': 'curr',
          'param': {
            'cmsArticleWebOld': {
              'searchScope': 'default',
              'sort': 'default',
              'pageIndex': page,
              'pageSize': pageSize,
              'preTag': '',
              'postTag': '',
            }
          }
        }),
      };

      final response = await _dio.get(ApiEndpoints.newsSearch, queryParameters: params);
      var body = response.data is String ? response.data as String : json.encode(response.data);

      // 去掉 JSONP 包裹
      final jsonStart = body.indexOf('(');
      final jsonEnd = body.lastIndexOf(')');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        body = body.substring(jsonStart + 1, jsonEnd);
      }

      return _parseSearchResults(body);
    } catch (e) {
      AppLog.instance.warn('NewsApi', 'searchNewsByName($keyword) 失败: $e');
      return [];
    }
  }

  /// 按关键词搜索新闻（行业/主题词，如"新能源汽车""半导体"）
  Future<List<NewsItem>> searchNewsByTheme(String theme, {int page = 1, int pageSize = 15}) async {
    return searchNewsByName(theme, page: page, pageSize: pageSize);
  }

  /// 个股公告查询（批量）
  Future<List<Map<String, dynamic>>> getStockAnnouncements(List<String> codes, {int limit = 20}) async {
    if (codes.isEmpty) return [];
    final aShareCodes = codes.where((c) => c.length == 6 && int.tryParse(c) != null).toList();
    if (aShareCodes.isEmpty) return [];

    await RateLimiter.instance.wait('np-anotice-stock.eastmoney.com');
    try {
      final params = {
        'sr': '-1',
        'page_size': '$limit',
        'page_index': '1',
        'ann_type': 'A',
        'stock_list': aShareCodes.join(','),
        'f_node': '0',
        's_node': '0',
      };

      final response = await _dio.get(
        'https://np-anotice-stock.eastmoney.com/api/security/ann',
        queryParameters: params,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }),
      );
      final data = response.data is String ? json.decode(response.data) : response.data;

      if (data['success'] != true) return [];
      final items = data['data']?['list'] as List? ?? [];

      return items.map((item) {
        return {
          'artCode': item['art_code']?.toString() ?? '',
          'title': item['title']?.toString() ?? '',
          'time': item['notice_date']?.toString() ?? '',
          'codes': (item['codes'] as List? ?? []).map((c) => c['stock_code']?.toString() ?? '').where((s) => s.isNotEmpty).toList(),
          'url': 'https://data.eastmoney.com/notices/detail/${aShareCodes.isNotEmpty ? aShareCodes.first : ''}/${item['art_code']}.html',
        };
      }).toList();
    } catch (e) {
      AppLog.instance.warn('NewsApi', 'getStockAnnouncements 失败: $e');
      return [];
    }
  }

  List<NewsItem> _parseSearchResults(String body) {
    try {
      final data = json.decode(body);
      final List list = data['result']?['cmsArticleWebOld'] ?? [];

      return list.map((item) => NewsItem(
        title: _stripHtml(item['title']?.toString() ?? ''),
        digest: _stripHtml(item['content']?.toString() ?? item['digest']?.toString() ?? ''),
        source: item['mediaName']?.toString() ?? '',
        time: DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now(),
        url: item['url']?.toString() ?? '',
        imageUrl: item['image']?.toString(),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
