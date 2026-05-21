import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_data.dart';
import '../models/ai_report.dart';
import '../../core/utils/app_logger.dart';

/// 东方财富妙想 API 客户端（直连模式）
/// 参考 Aeolus 项目实现
class EmAiApi {
  static const _searchDataUrl = 'https://ai-saas.eastmoney.com/proxy/b/mcp/tool/searchData';
  static const _stockPickUrl = 'https://mkapi2.dfcfs.com/finskillshub/api/claw/stock-screen';
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
  Future<List<AiStockPick>> selectStocks(String query, {int pageSize = 20}) async {
    if (_apiKey.isEmpty) return [];

    try {
      final response = await _dio.post(
        _stockPickUrl,
        data: {
          'keyword': query,
          'pageNo': 1,
          'pageSize': pageSize,
        },
        options: Options(headers: {'apikey': _apiKey}),
      );

      final data = response.data is String ? json.decode(response.data) : response.data;
      return _parseStockScreenResult(data);
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

  /// 解析选股结果
  List<AiStockPick> _parseStockScreenResult(Map<String, dynamic> data) {
    final status = data['status'];
    if (status != null && status != 0) return [];

    final innerData = data['data'] as Map<String, dynamic>? ?? {};
    final dataInner = innerData['data'] as Map<String, dynamic>? ?? {};
    final result = dataInner['result'] as Map<String, dynamic>? ?? {};
    final dataList = result['dataList'] as List? ?? [];

    return dataList.map((item) {
      final code = item['SECURITY_CODE']?.toString() ?? '';
      final name = item['SECURITY_SHORT_NAME']?.toString() ?? '';
      final price = _toDouble(item['NEWEST_PRICE']);
      final change = _toDouble(item['CHG']);

      return AiStockPick(
        code: code,
        name: name,
        reason: '符合筛选条件',
        score: 0,
        price: price,
        changePercent: change,
      );
    }).toList();
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
