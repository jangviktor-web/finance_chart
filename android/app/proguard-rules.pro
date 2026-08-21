# =========================================================
# 策盈 QuantWin - R8/ProGuard 规则（P0-1）
# Dart 代码混淆由 `flutter build apk --obfuscate` 处理，
# 本文件针对 Java/Kotlin 插件层与反射点，避免 R8 误删运行时依赖。
# 各 Flutter 插件的 consumer 规则已由 Gradle 自动合并。
# =========================================================

# ---- 反射/序列化敏感的枚举保留 ----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- WebView（webview_flutter / in_app_webview）桥接类保留 ----
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ---- Flutter 插件公共包保留 ----
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# ---- 可选依赖缺失时抑制警告（不影响运行）----
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn com.squareup.okhttp.**
-dontwarn okhttp3.**
-dontwarn okio.**
