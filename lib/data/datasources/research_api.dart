import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';
import '../../core/utils/stock_code_utils.dart';
import '../models/research_data.dart';

/// 个股研报 API（东财 reportapi，A2）
/// 源：https://reportapi.eastmoney.com/report/list2（a-stock-data-quant §9.1）
class ResearchApi {
  static const _url = 'https://reportapi.eastmoney.com/report/list2';

  /// 获取个股研究报告
  Future<List<ResearchReport>> getReports(String code, {int days = 30, int pageSize = 10}) async {
    final pureCode = StockCodeUtils.pureCode(code);
    await RateLimiter.instance.wait('reportapi.eastmoney.com');

    final client = HttpClient();
    try {
      final end = DateTime.now();
      final begin = end.subtract(Duration(days: days));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final request = await client.postUrl(Uri.parse(_url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0');
      request.headers.set('Host', 'reportapi.eastmoney.com');
      request.headers.set('Origin', 'https://data.eastmoney.com');
      request.headers.set('Referer', 'https://data.eastmoney.com/report/stock.jshtml');
      request.headers.set('Content-Type', 'application/json');
      request.write(json.encode({
        'code': pureCode,
        'industryCode': '*',
        'beginTime': fmt(begin),
        'endTime': fmt(end),
        'pageNo': 1,
        'pageSize': pageSize,
        'p': 1,
        'pageNum': 1,
        'pageNumber': 1,
      }));

      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.fold<List<int>>(<int>[], (buf, chunk) => buf..addAll(chunk));
      final data = json.decode(utf8.decode(body, allowMalformed: true));

      if (data is! Map<String, dynamic>) return [];
      final hits = data['data'];
      if (hits is! List) return [];

      final results = <ResearchReport>[];
      for (final item in hits) {
        if (item is! Map<String, dynamic>) continue;
        final title = (item['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final dateStr = (item['publishDate'] ?? '').toString();
        results.add(ResearchReport(
          title: title,
          org: (item['orgSName'] ?? '').toString(),
          date: DateTime.tryParse(dateStr) ?? DateTime.now(),
          rating: (item['ratingName'] ?? '').toString(),
          author: (item['researcher'] ?? '').toString(),
          industry: (item['industryName'] ?? '').toString(),
        ));
      }
      return results;
    } on Exception catch (e) {
      AppLog.instance.info('ResearchApi', '获取研报失败($code): $e');
      return [];
    } finally {
      client.close();
    }
  }
}
