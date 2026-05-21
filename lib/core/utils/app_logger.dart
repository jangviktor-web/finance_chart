import 'dart:collection';
import 'package:flutter/services.dart';

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() {
    final ts = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final buf = StringBuffer('[$ts] [$level] $tag: $message');
    if (stackTrace != null) {
      buf.write('\n$stackTrace');
    }
    return buf.toString();
  }
}

class AppLog {
  static const _maxSize = 500;
  static final AppLog instance = AppLog._();
  AppLog._();

  final Queue<LogEntry> _buffer = Queue<LogEntry>();

  void info(String tag, String message) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      level: 'I',
      tag: tag,
      message: message,
    ));
  }

  void warn(String tag, String message) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      level: 'W',
      tag: tag,
      message: message,
    ));
  }

  void error(String tag, String message, [String? stackTrace]) {
    _add(LogEntry(
      timestamp: DateTime.now(),
      level: 'E',
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    ));
  }

  void _add(LogEntry entry) {
    _buffer.addLast(entry);
    while (_buffer.length > _maxSize) {
      _buffer.removeFirst();
    }
  }

  String getAll() {
    return _buffer.map((e) => e.toString()).join('\n');
  }

  /// 按 tag 过滤日志
  String getByTag(String tag) {
    return _buffer
        .where((e) => e.tag == tag)
        .map((e) => e.toString())
        .join('\n');
  }

  /// 按多个 tag 过滤日志
  String getByTags(List<String> tags) {
    return _buffer
        .where((e) => tags.contains(e.tag))
        .map((e) => e.toString())
        .join('\n');
  }

  /// 获取所有不重复的 tag 列表
  List<String> getAllTags() {
    return _buffer.map((e) => e.tag).toSet().toList();
  }

  /// 按 tag 导出到剪贴板
  Future<void> toClipboardByTag(String tag) async {
    final text = getByTag(tag);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// 按多个 tag 导出到剪贴板
  Future<void> toClipboardByTags(List<String> tags) async {
    final text = getByTags(tags);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  int get length => _buffer.length;

  void clear() {
    _buffer.clear();
  }

  Future<void> toClipboard() async {
    final text = getAll();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }
}
