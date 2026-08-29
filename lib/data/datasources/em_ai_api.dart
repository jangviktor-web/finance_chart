import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_data.dart';
import '../models/ai_report.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/rate_limiter.dart';

/// 东方财富妙想 API 客户端（直连模式）
/// 参考 Aeolus 项目实现
class EmAiApi {
  static const _searchDataUrl = 'https://ai-saas.eastmoney.com/proxy/b/mcp/tool/searchData';
  // 妙想选股正确端点：ai-saas selectSecurity（独立 selectType 字段 + em_api_key 头）
  static const _stockPickUrl = 'https://ai-saas.eastmoney.com/proxy/b/mcp/tool/selectSecurity';
  static const _assistantBaseUrl = 'https://ai-saas.eastmoney.com/proxy/app-robo-advisor-api/assistant';

  final Dio _dio;
  String _apiKey;

  EmAiApi({String? apiKey, Dio? dio})
      : _apiKey = apiKey ?? '',
        _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        ));

  /// 更新 API Key
  void updateApiKey(String key) {
    _apiKey = key;
  }

  /// 构建 searchData 请求体
  Map<String, dynamic> _buildSearchBody(String query) {
    return {
      'query': query,
      'toolContext': {
        'callId': const Uuid().v4(),
        'userInfo': {
          'userId': _apiKey,
        },
      },
    };
  }

  /// 通用 searchData 查询
  Future<Map<String, dynamic>> _searchData(String query) async {
    if (_apiKey.isEmpty) {
      return {'error': 'API Key 未配置'};
    }

    await RateLimiter.instance.wait('ai-saas.eastmoney.com');
    try {
      final response = await _dio.post(
        _searchDataUrl,
        data: _buildSearchBody(query),
        options: Options(headers: {'em_api_key': _apiKey}),
      );

      final data = response.data is String ? json.decode(response.data) : response.data;
      return data as Map<String, dynamic>;
    } catch (e) {
      AppLog.instance.error('EmAiApi', 'searchData 失败: $e');
      return {'error': e.toString()};
    }
  }

  /// AI 诊断 — 查询股票关键指标
  Future<AiDiagnosisResult> diagnose(String code, {String? question}) async {
    if (_apiKey.isEmpty) {
      return AiDiagnosisResult(
        code: code,
        name: '',
        summary: '请先在设置中配置 API Key',
        suggestion: '前往 设置 → AI 配置 → 填入妙想 API Key',
        riskLevel: '未知',
      );
    }

    final query = question ?? '$code股票最新价、涨跌幅、成交量、市盈率、换手率、总市值';
    final data = await _searchData(query);

    if (data.containsKey('error')) {
      return AiDiagnosisResult(
        code: code,
        name: '',
        summary: data['error'].toString(),
        suggestion: '请检查 API Key 是否正确',
        riskLevel: '未知',
      );
    }

    return _parseDiagnosisResult(data, code);
  }

  /// AI 选股 — 自然语言筛选股票
  /// [selectType] 市场类型（A股/港股/美股/基金/ETF/可转债/板块），作为独立字段传入
  /// 端点：ai-saas selectSecurity，body={query, selectType}，header=em_api_key
  Future<List<AiStockPick>> selectStocks(String query, {int pageSize = 20, String? selectType}) async {
    if (_apiKey.isEmpty) return [];

    await RateLimiter.instance.wait('ai-saas.eastmoney.com');
    try {
      final response = await _dio.post(
        _stockPickUrl,
        data: {
          'query': query,
          'selectType': selectType ?? 'A股',
        },
        options: Options(headers: {'em_api_key': _apiKey}),
      );

      final data = response.data is String ? json.decode(response.data) : response.data;
      if (data is! Map<String, dynamic>) return [];
      // selectSecurity 返回 {securityCount, partialResults(markdown 表格)}
      final count = data['securityCount'];
      if (count is int && count <= 0) return [];
      return _parseSelectSecurityResult(data);
    } catch (e) {
      AppLog.instance.error('EmAiApi', 'selectStocks 失败: $e');
      return [];
    }
  }

  /// AI 对话 — 自然语言查询金融数据
  Future<String> chat(String message, {String? code}) async {
    if (_apiKey.isEmpty) return '请先在设置中配置 API Key（设置 → AI 配置）';

    final query = code != null ? '$code $message' : message;
    final data = await _searchData(query);

    if (data.containsKey('error')) {
      return '查询失败: ${data['error']}';
    }

    return _parseChatResponse(data);
  }

  /// 解析诊断结果
  AiDiagnosisResult _parseDiagnosisResult(Map<String, dynamic> data, String code) {
    // 检查业务状态
    final code2 = data['code'];
    final status = data['status'];
    if (code2 != null && code2 != 0 && code2 != 200) {
      return AiDiagnosisResult(
        code: code,
        name: '',
        summary: data['message']?.toString() ?? '查询失败',
        suggestion: '请检查股票代码是否正确',
        riskLevel: '未知',
      );
    }

    // 提取数据表
    final tables = _extractDataTableList(data);
    if (tables.isEmpty) {
      return AiDiagnosisResult(
        code: code,
        name: '',
        summary: '未找到相关数据',
        suggestion: '请确认股票代码正确',
        riskLevel: '未知',
      );
    }

    // 提取股票名称和指标
    String name = '';
    final indicators = <String, String>{};

    for (final table in tables) {
      final entityName = table['entityName']?.toString() ?? '';
      if (entityName.isNotEmpty && name.isEmpty) {
        name = entityName.split('(').first.trim();
      }

      final rawTable = table['rawTable'] as Map<String, dynamic>? ?? {};
      final nameMap = table['nameMap'] as Map<String, dynamic>? ?? {};

      for (final entry in rawTable.entries) {
        final key = entry.key;
        final values = entry.value;
        final label = nameMap[key]?.toString() ?? key;
        if (values is List && values.isNotEmpty) {
          final lastValue = values.last;
          if (lastValue != null) {
            indicators[label] = lastValue.toString();
          }
        }
      }
    }

    // 生成诊断摘要
    final summaryParts = <String>[];
    for (final entry in indicators.entries) {
      summaryParts.add('${entry.key}: ${entry.value}');
    }

    final summary = summaryParts.isNotEmpty
        ? summaryParts.take(8).join('\n')
        : '暂无数据';

    // 生成建议
    String suggestion = '建议结合技术面和基本面综合判断';
    String riskLevel = '中';

    final changeStr = indicators['涨跌幅'] ?? indicators['涨跌幅(%)'] ?? '0';
    final change = double.tryParse(changeStr.replaceAll('%', '')) ?? 0;
    if (change > 5) {
      suggestion = '短期涨幅较大，注意追高风险';
      riskLevel = '高';
    } else if (change < -5) {
      suggestion = '跌幅较大，关注支撑位';
      riskLevel = '中';
    }

    // 提取信号
    final signals = <String>[];
    if (change > 3) signals.add('涨幅较大');
    if (change < -3) signals.add('跌幅较大');

    final turnoverStr = indicators['换手率'] ?? indicators['换手率(%)'] ?? '0';
    final turnover = double.tryParse(turnoverStr.replaceAll('%', '')) ?? 0;
    if (turnover > 10) signals.add('换手活跃');

    return AiDiagnosisResult(
      code: code,
      name: name,
      summary: summary,
      suggestion: suggestion,
      riskLevel: riskLevel,
      signals: signals,
    );
  }

  /// 从响应中提取 dataTableDTOList
  List<Map<String, dynamic>> _extractDataTableList(Map<String, dynamic> data) {
    // 直接在顶层
    var dtoList = data['dataTableDTOList'];
    if (dtoList is List) {
      return dtoList.whereType<Map<String, dynamic>>().toList();
    }

    // 在 data 节点下
    final dataNode = data['data'];
    if (dataNode is Map<String, dynamic>) {
      // 新结构: data.searchDataResultDTO.dataTableDTOList
      final searchResult = dataNode['searchDataResultDTO'];
      if (searchResult is Map<String, dynamic>) {
        dtoList = searchResult['dataTableDTOList'];
        if (dtoList is List) {
          return dtoList.whereType<Map<String, dynamic>>().toList();
        }
      }

      // 旧结构: data.dataTableDTOList
      dtoList = dataNode['dataTableDTOList'];
      if (dtoList is List) {
        return dtoList.whereType<Map<String, dynamic>>().toList();
      }
    }

    return [];
  }

  /// 解析 selectSecurity 结果：partialResults 为 Markdown 表格
  /// 列通常为：序号 | 代码 | 名称 | 最新价 | 涨跌幅 | ...（表头/分隔行需跳过）
  List<AiStockPick> _parseSelectSecurityResult(Map<String, dynamic> data) {
    final partial = data['partialResults'];
    if (partial is! String || partial.isEmpty) {
      AppLog.instance.warn('EmAiApi', 'selectSecurity 无 partialResults');
      return [];
    }

    final picks = <AiStockPick>[];
    for (final raw in partial.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('|')) continue;
      if (line.contains('---')) continue; // 分隔行
      if (line.contains('代码') && line.contains('名称')) continue; // 表头

      final cells = line
          .split('|')
          .where((c) => c.trim().isNotEmpty)
          .map((c) => c.trim())
          .toList();
      if (cells.length < 4) continue;

      String? code;
      String? name;
      for (final c in cells) {
        if (code == null && RegExp(r'^\d{6}(\.\w{2})?$').hasMatch(c)) {
          code = c;
        } else if (name == null && RegExp(r'[\u4e00-\u9fa5]').hasMatch(c)) {
          name = c;
        }
      }
      if (code == null || name == null) continue;

      // 价格/涨跌幅取行内数值单元格（最后一个为涨跌幅，倒数第二个为最新价）
      final nums = cells
          .where((c) => RegExp(r'^-?\d+(\.\d+)?%?$').hasMatch(c))
          .map((c) => c.replaceAll('%', ''))
          .toList();
      double price = 0;
      double change = 0;
      if (nums.length >= 2) {
        price = _toDouble(nums[nums.length - 2]);
        change = _toDouble(nums.last);
      } else if (nums.length == 1) {
        change = _toDouble(nums.first);
      }

      picks.add(AiStockPick(
        code: code,
        name: name,
        reason: '符合筛选条件',
        score: 0,
        price: price,
        changePercent: change,
      ));
    }
    return picks;
  }

  /// 解析对话响应
  String _parseChatResponse(Map<String, dynamic> data) {
    // 检查业务状态
    final code = data['code'];
    final status = data['status'];
    if (code != null && code != 0 && code != 200) {
      return data['message']?.toString() ?? '查询失败';
    }

    final tables = _extractDataTableList(data);
    if (tables.isEmpty) {
      return '未找到相关数据';
    }

    // 将表格数据格式化为文本
    final parts = <String>[];
    for (final table in tables) {
      final title = table['title']?.toString() ?? '';
      final entityName = table['entityName']?.toString() ?? '';
      final displayName = title.isNotEmpty ? title : entityName;
      if (displayName.isNotEmpty) parts.add('【$displayName】');

      final rawTable = table['rawTable'] as Map<String, dynamic>? ?? {};
      final nameMap = table['nameMap'] as Map<String, dynamic>? ?? {};

      for (final entry in rawTable.entries) {
        final key = entry.key;
        final values = entry.value;
        final label = nameMap[key]?.toString() ?? key;
        if (values is List && values.isNotEmpty) {
          final lastValue = values.last;
          if (lastValue != null) {
            parts.add('$label: $lastValue');
          }
        }
      }
    }

    return parts.isNotEmpty ? parts.join('\n') : '暂无数据';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v == '-' || v == '' || v == '--' || v == 'N/A') return 0;
      return double.tryParse(v) ?? 0;
    }
    return 0;
  }

  // ──────────── Assistant API（热点/可比公司/深度分析）────────────

  /// 通用 assistant API 调用
  Future<Map<String, dynamic>> _callAssistant(String endpoint, String question) async {
    if (_apiKey.isEmpty) return {'error': 'API Key 未配置'};

    try {
      final response = await _dio.post(
        '$_assistantBaseUrl/$endpoint',
        data: {'question': question},
        options: Options(headers: {'em_api_key': _apiKey}),
      );
      final data = response.data is String ? json.decode(response.data) : response.data;
      return data as Map<String, dynamic>;
    } catch (e) {
      AppLog.instance.error('EmAiApi', '$endpoint 失败: $e');
      return {'error': e.toString()};
    }
  }

  /// 市场热点发现 — 返回 Markdown 报告
  Future<String> getHotspot({String question = '今日热点'}) async {
    AppLog.instance.info('EmAiApi', 'getHotspot: $question');
    final data = await _callAssistant('hotspot-discovery', question);
    if (data.containsKey('error')) {
      AppLog.instance.error('EmAiApi', 'getHotspot 失败: ${data['error']}');
      return '查询失败: ${data['error']}';
    }

    final innerData = data['data'];
    if (innerData is Map<String, dynamic> && innerData.containsKey('displayData')) {
      final md = innerData['displayData'] as String;
      AppLog.instance.info('EmAiApi', 'getHotspot 成功, 长度=${md.length}');
      return md;
    }
    AppLog.instance.warn('EmAiApi', 'getHotspot 无 displayData');
    return '暂无热点数据';
  }

  /// 可比公司分析 — 返回结构化数据
  Future<ComparableCompanyData> getComparableCompany(String companyName) async {
    AppLog.instance.info('EmAiApi', 'getComparableCompany: $companyName');
    final data = await _callAssistant('comparable-company-analysis', companyName);
    if (data.containsKey('error')) {
      AppLog.instance.error('EmAiApi', 'getComparableCompany 失败: ${data['error']}');

      return ComparableCompanyData(
        targetCompany: companyName,
        companies: [],
        financeHeaders: [],
        financeData: [],
        valuationHeaders: [],
        valuationData: [],
      );
    }

    final dataList = data['data'] as List? ?? [];
    if (dataList.length < 3) {
      return ComparableCompanyData(
        targetCompany: companyName,
        companies: [],
        financeHeaders: [],
        financeData: [],
        valuationHeaders: [],
        valuationData: [],
      );
    }

    // data[1] = 经营指标表, data[2] = 估值指标表
    final financeTable = dataList[1]['table'] as Map<String, dynamic>? ?? {};
    final valuationTable = dataList[2]['table'] as Map<String, dynamic>? ?? {};

    // 提取公司名列表（排除统计行）
    final statKeys = {'最大值', '中位数', '最小值', 'VS中位数(%,目标公司)', 'Z-Score(目标公司)'};
    final financeCompanies = financeTable.keys
        .where((k) => k != 'headName' && !statKeys.contains(k))
        .toList();

    // 提取经营指标
    final financeHeaders = (financeTable['headName'] as List?)?.cast<String>() ?? [];
    final financeData = financeCompanies.map((company) {
      return (financeTable[company] as List?)?.cast<String>() ?? <String>[];
    }).toList();

    // 提取估值指标
    final valuationHeaders = (valuationTable['headName'] as List?)?.cast<String>() ?? [];
    final valuationData = financeCompanies.map((company) {
      return (valuationTable[company] as List?)?.cast<String>() ?? <String>[];
    }).toList();

    AppLog.instance.info('EmAiApi', 'getComparableCompany 成功: ${financeCompanies.length}家公司');
    return ComparableCompanyData(
      targetCompany: companyName,
      companies: financeCompanies,
      financeHeaders: financeHeaders,
      financeData: financeData,
      valuationHeaders: valuationHeaders,
      valuationData: valuationData,
    );
  }

  /// 股票深度分析 — 返回 Markdown 报告
  Future<String> getStockAnalysis(String question) async {
    AppLog.instance.info('EmAiApi', 'getStockAnalysis: $question');
    final data = await _callAssistant('stock-analysis', question);
    if (data.containsKey('error')) {
      AppLog.instance.error('EmAiApi', 'getStockAnalysis 失败: ${data['error']}');
      return '查询失败: ${data['error']}';
    }

    final innerData = data['data'];
    if (innerData is Map<String, dynamic> && innerData.containsKey('displayData')) {
      final md = innerData['displayData'] as String;
      AppLog.instance.info('EmAiApi', 'getStockAnalysis 成功, 长度=${md.length}');
      return md;
    }
    AppLog.instance.warn('EmAiApi', 'getStockAnalysis 无 displayData');
    return '暂无分析数据';
  }
}
