import 'dart:convert';
import 'dart:typed_data';

/// 轻量 API Key 加密/解密工具
/// 使用 XOR + Base64 混淆，防止 SharedPreferences 明文存储
class KeyCipher {
  KeyCipher._();

  // 混淆密钥（应用级，非安全用途）
  static const _obfuscateKey = 'QuantWin2026!@#\$%^&*()_+AbcDef';

  /// 加密明文 Key → Base64 字符串
  static String encrypt(String plain) {
    if (plain.isEmpty) return '';
    final keyBytes = utf8.encode(_obfuscateKey);
    final plainBytes = utf8.encode(plain);
    final encrypted = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      encrypted[i] = plainBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64Encode(encrypted);
  }

  /// 解密 Base64 字符串 → 明文 Key
  static String decrypt(String encoded) {
    if (encoded.isEmpty) return '';
    try {
      final encrypted = base64Decode(encoded);
      final keyBytes = utf8.encode(_obfuscateKey);
      final decrypted = Uint8List(encrypted.length);
      for (var i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ keyBytes[i % keyBytes.length];
      }
      return utf8.decode(decrypted);
    } catch (_) {
      // 解密失败说明是旧版明文，原样返回
      return encoded;
    }
  }

  /// 判断字符串是否为已加密格式（Base64）
  static bool isEncrypted(String value) {
    if (value.isEmpty) return false;
    try {
      final decoded = base64Decode(value);
      // 加密后的数据应为有效 UTF-8 且包含原始 Key 的特征
      final plain = utf8.decode(decoded, allowMalformed: false);
      return plain.startsWith('em_') || plain.length > 10;
    } catch (_) {
      return false;
    }
  }

  /// 脱敏显示：首2位 + **** + 末2位
  static String mask(String key) {
    if (key.isEmpty) return '未配置';
    if (key.length <= 4) return '****';
    return '${key.substring(0, 2)}****${key.substring(key.length - 2)}';
  }
}
