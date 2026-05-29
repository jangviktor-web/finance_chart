<div align="center">

<img src="https://github.com/user-attachments/assets/d4d103cd-270d-471a-8204-db92953ec87d" alt="策盈 QuantWin Logo" width="160">




# 策盈 QuantWin

### 📈 A股量化分析 Android APP · 股票技术分析 · AI 智能选股

[![GitHub release](https://img.shields.io/github/v/release/jangviktor-web/finance_chart?style=flat-square&color=E53935&label=Latest&logo=github)](https://github.com/jangviktor-web/finance_chart/releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/jangviktor-web/finance_chart/total?style=flat-square&color=FF6D00&label=Downloads&logo=github)](https://github.com/jangviktor-web/finance_chart/releases)
[![License](https://img.shields.io/badge/License-MIT-4CAF50?style=flat-square&logo=mit)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0+-3DDC84?style=flat-square&logo=android)](https://developer.android.com)

开源免费的 **A 股量化分析 Android APP**，基于 Flutter 构建，无需后端服务。集成 **25+ 技术指标**、**AI 智能选股与诊断**、**资金流向分析**、**北向资金追踪**、**龙虎榜解读**、**宏观经济数据**、**策略回测引擎**，数据全部来自东方财富、腾讯、百度等公开免费 API。

![skillicons](https://skillicons.dev/icons?i=flutter,dart,android)

</div>

---

## 📸 应用截图

<p align="center">
<img width="4000" height="2160" alt="微信图片_20260525100307_31_134" src="https://github.com/user-attachments/assets/15cd2a67-d54d-4280-accf-25fcae67e8b5" />

<img width="4000" height="2160" alt="微信图片_20260525100308_32_134" src="https://github.com/user-attachments/assets/c8b65bb0-c019-487e-b15c-ffc9e022bfbc" />

---

## ⬇️ 下载

<div align="center">

[![Latest APK](https://img.shields.io/badge/下载_v1.7.3-APK-E53935?style=for-the-badge&logo=android)](https://github.com/jangviktor-web/finance_chart/releases/download/v1.7.3/app-release.apk)

</div>

| 版本 | 日期 | 更新内容 |
|:---:|:---:|---|
| **v1.7.3** | 2026-05-22 | 发现页内嵌热点列表 · API Key XOR 加密存储 · 脱敏显示 |
| **v1.7.1** | 2026-05-22 | 全 API 频率限制 · 每日调用上限 · 宏观数据缓存 |
| **v1.7.0** | 2026-05-21 | 搜索联想 · 回测时间区间 · WebView · 宏观扩展 |
| **v1.6.0** | 2026-05-21 | AI 热点 · AI 同业对比 · AI 深度分析 · 全局限流 |
| **v1.4.0** | 2026-05-20 | 资金流向 · 北向深度 · 龙虎榜扩展 |

> 完整版本列表见 [Releases](https://github.com/jangviktor-web/finance_chart/releases) · 变更详情见 [CHANGELOG](CHANGELOG.md)

---

## ✨ 功能特性

### 📊 股票行情数据

- **多源实时行情** — 腾讯 / 东方财富 / 百度，自动降级切换
- **多源 K 线** — 腾讯 / 新浪 / 百度，并行竞速取最优
- **分时 & K 线图** — 日 / 周 / 月 / 1·5·15·30·60 分钟
- **主题切换** — 暗色 / 亮色 · 中国红涨绿跌 / 美国绿涨红跌

### 📐 技术分析（25+ 指标）

| 分类 | 指标 |
|---|---|
| 基础 | MA · MACD · KDJ · RSI · BOLL · VOL |
| 扩展 | OBV · CCI · WR · DMI · TRIX · PSY · ROC · MFI · VR · EMV · MASS · CR · BRAR · ASI · ATR · BIAS · DPO · DFMA |
| 形态 | 锤子线 · 十字星 · 吞没 · 启明星 |
| 自定义 | 所有指标参数可调 |

### 🤖 AI 智能选股与诊断（东方财富妙想）

- **AI 诊断** — 技术面 + 基本面综合诊断，风险等级 + 操作建议
- **AI 深度分析** — Markdown 综合报告，自动保存历史
- **AI 选股** — 自然语言描述条件，AI 匹配推荐
- **AI 对话** — 聊天气泡界面，快捷操作芯片
- **热点发现** — 市场热点列表，支持自定义查询，点击查看详情
- **同业对比** — 中文名 / 代码搜索联想，经营 + 估值双表对比

### 💰 资金流向

- **个股资金流** — 主力 / 超大单 / 大单 / 中单 / 小单 净流入
- **大盘资金流** — 上证 + 深证 实时快照
- **全市场排行** — 今日 / 3日 / 5日 / 10日 主力净流入排序

### 🌏 北向资金

- **实时分时** — 沪股通 + 深股通 分钟级净买入
- **历史趋势** — 近 30 天每日净买入柱状图
- **板块排名** — 按持股市值排序
- **个股持仓** — 北向持仓历史 + 机构明细

### 🐉 龙虎榜

- **每日详情** — 上榜个股 + 买卖营业部
- **上榜统计** — 近 1/3/6/12 月次数排名
- **机构追踪** — 机构席位每日买卖统计
- **营业部排行** — 按资金实力 / 收益率

### 🔍 选股扫描

- **全市场扫描** — 覆盖沪深京 A 股
- **5 大策略** — MA 交叉 · KDJ 金叉 · RSI 超卖反弹 · MACD 金叉 · 放量突破
- **智能过滤** — ST / 科创板 / 创业板 可选
- **批量操作** — 一键加自选 · CSV 导出

### 📈 宏观数据

| 分类 | 指标 |
|---|---|
| 基础 | CPI · PPI · GDP · PMI · M2 · LPR |
| 高频跟踪 | 高炉开工率 · 30城商品房成交 · 动力电池装机 · 机器人产量增速 |
| 政策利率 | 社会融资规模 · MLF 操作利率 |
| 资产联动 | 美元/人民币汇率 · 10年期国债收益率 |

### 🛡️ 安全与体验

- **API Key 加密存储** — XOR + Base64 加密，SharedPreferences 不存明文
- **界面脱敏** — 始终显示首2+****+末2格式，无明文切换
- **全局限流** — 16 个域名独立限流 + 每日调用上限 + 指数退避
- **功能开关** — 每个功能独立启用 / 禁用
- **新闻资讯** — 东财 7x24 · 财联社 · 新浪，APP 内 WebView 加载
- **自选分组** — 多分组管理，跨组移动
- **策略回测** — 自定义时间区间，收益率 / 回撤 / 夏普比率

---

## 🛠️ 技术栈

<div align="center">

![skillicons](https://skillicons.dev/icons?i=flutter,dart,firebase)

</div>

| 层级 | 技术 | 说明 |
|---|---|---|
| 框架 | Flutter 3.x + Dart | 跨平台 UI |
| 状态管理 | Riverpod | `StateNotifierProvider` |
| 网络 | Dio + `dart:io` HttpClient | 多源竞速 + 降级 |
| 图表 | `CustomPainter` 自绘 | K 线 / 指标 / 资金流 |
| 存储 | SharedPreferences | 设置 + 加密 Key |
| Markdown | `flutter_markdown` | AI 报告渲染 |
| WebView | `webview_flutter` | 新闻详情内嵌 |
| 编码 | `fast_gbk` | 腾讯 GBK 解码 |

---

## 🏗️ 架构

```
lib/
├── core/                    # 基础工具
│   ├── constants/           # API 端点定义
│   └── utils/               # 频率限制 · 加密 · 日志 · 股票代码
├── data/                    # 数据层
│   ├── datasources/         # 10+ API 数据源 (含降级)
│   │   ├── local/           # 本地存储 (设置 · 历史 · 缓存)
│   │   ├── market_api.dart  # 行情 (腾讯/新浪/百度竞速)
│   │   ├── sentiment_api.dart # 情绪 (龙虎榜/北向/融资/涨停)
│   │   └── ...
│   └── models/              # 数据模型
├── presentation/            # UI 层
│   ├── screens/             # 页面 (行情/分析/回测/发现/设置)
│   ├── widgets/             # 组件 (K线图/指标图/Markdown)
│   └── providers/           # Riverpod 状态
└── app/                     # 主题 · 路由
```

**核心设计模式：**
- **多源降级** — 每个 API 有主备数据源，故障自动切换
- **全局频率限制** — 按域名限流 + 每日上限 + 指数退避
- **加密存储** — API Key XOR 加密后持久化

---

## 🚀 快速开始

### 环境要求

- Flutter 3.x
- Dart 3.x
- Android SDK 8.0+ (API 26)

### 构建

```bash
git clone https://github.com/jangviktor-web/finance_chart.git
cd finance_chart
flutter pub get
flutter build apk --release
```

输出：`build/app/outputs/flutter-apk/app-release.apk`

---

## 📊 数据源

| 数据源 | 用途 | 限流 |
|---|---|---|
| 东方财富 Push2 | 实时行情 · 板块资金流 | 500ms / 1000次/日 |
| 东方财富 DataCenter | 龙虎榜 · 北向 · 宏观 | 600ms / 200次/日 |
| 东方财富 AI | 诊断 / 选股 / 热点 / 同业 | 1000ms / 50次/日 |
| 腾讯行情 | 实时行情 (GBK) | 250ms / 2000次/日 |
| 新浪财经 | K 线数据 | 300ms / 200次/日 |
| 百度财经 | 实时行情 · 概念板块 | 500ms / 200次/日 |
| 财联社 | 新闻快讯 | 300ms / 200次/日 |
| 东财搜索 | 股票搜索联想 | 300ms / 300次/日 |

> 所有数据源支持自动降级，单一故障不影响使用

---

## 📜 版本历史

| 版本 | 日期 | 更新 |
|---|---|---|
| v1.7.3 | 2026-05-22 | 发现页内嵌热点 · API Key 加密 · 脱敏显示 |
| v1.7.1 | 2026-05-22 | 全 API 频率限制 · 每日调用上限 · 宏观缓存 |
| v1.7.0 | 2026-05-21 | 搜索联想 · 回测时间 · WebView · 宏观扩展 |
| v1.6.0 | 2026-05-21 | AI 热点 · AI 同业 · AI 深度 · 全局限流 |
| v1.5.0 | 2026-05-21 | 多股对比 · 资金流向页 · K 线优化 |
| v1.4.0 | 2026-05-20 | 个股资金流 · 北向深度 · 龙虎榜扩展 |
| v1.3.0 | 2026-05-19 | 首个正式版 — 行情 · 分析 · 情绪 · 选股 · 新闻 · 宏观 · 回测 |

> 完整变更见 [CHANGELOG.md](CHANGELOG.md)

---

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=jangviktor-web/finance_chart&type=Timeline)](https://star-history.com/#jangviktor-web/finance_chart&Timeline)

---

## 📄 免责声明

本应用仅供学习交流，数据来自公开 API，不构成投资建议。股市有风险，投资需谨慎。

---

<div align="center">

**如果觉得有用，请点个 ⭐ Star 支持一下！**

[Scroll to top](#策盈-quantwin)

</div>
