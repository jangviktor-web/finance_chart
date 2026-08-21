import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';
import '../../core/utils/stock_code_utils.dart';
import '../models/hudong_data.dart';

/// 互动易问答 API（巨潮 irm.cninfo.com.cn，A3）
/// 源：https://irm.cninfo.com.cn/newircs/index/search（a-stock-data-quant §9.3）
class HudongApi {
  static const _url = 'https://irm.cninfo.com.cn/newircs/index/search';

  /// 按股票代码/关键词查询互动易问答
  Future<List<InteractiveQA>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    await RateLimiter.instance.wait('irm.cninfo.com.cn');

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_url?_t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
      final request = await client.postUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0');
      request.headers.set('Host', 'irm.cninfo.com.cn');
      request.headers.set('Origin', 'https://irm.cninfo.com.cn');
      request.headers.set('Referer', 'https://irm.cninfo.com.cn/views/interactiveAnswer');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.write(Uri(queryParameters: {
        'pageNo': '$page',
        'pageSize': '$pageSize',
        'searchTypes': '11',
        'highLight': 'true',
        'keyWord': keyword,
      }).query);

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.fold<List<int>>(<int>[], (buf, chunk) => buf..addAll(chunk));
      final data = json.decode(utf8.decode(body, allowMalformed: true));

      if (data is! Map<String, dynamic>) return [];
      final rows = data['results'];
      if (rows is! List) return [];

      final results = <InteractiveQA>[];
      for (final item in rows) {
        if (item is! Map<String, dynamic>) continue;
        final question = (item['mainContent'] ?? '').toString().trim();
        final answer = (item['attachedContent'] ?? '').toString().trim();
        if (question.isEmpty) continue;
        results.add(InteractiveQA(
          question: question,
          answer: answer,
          company: (item['companyShortName'] ?? '').toString(),
          date: DateTime.tryParse((item['pubDate'] ?? '').toString()) ?? DateTime.now(),
          answerDate: DateTime.tryParse((item['attachedPubDate'] ?? '').toString()),
        ));
      }
      return results;
    } on Exception catch (e) {
      AppLog.instance.info('HudongApi', '获取互动易失败($keyword): $e');
      return [];
    } finally {
      client.close();
    }
  }

  /// 按股票代码查询
  Future<List<InteractiveQA>> searchByCode(String code) {
    return search(StockCodeUtils.pureCode(code));
  }
}
