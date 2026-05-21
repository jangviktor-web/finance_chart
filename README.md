# 策盈 QuantWin — A股量化分析 | 股票技术分析 | AI 智能选股

[![Flutter 量化分析工具](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart A股量化](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![A股量化分析最新版本](https://img.shields.io/github/v/release/jangviktor-web/finance_chart?label=Latest)](https://github.com/jangviktor-web/finance_chart/releases)
[![开源量化工具MIT协议](https://img.shields.io/badge/License-MIT-green)](LICENSE)

> 策盈 QuantWin 是一款开源免费的 **A 股量化分析工具箱**，基于 Flutter 构建，无需后端服务。集成 **25+ 技术指标**、**AI 智能选股与诊断**、**资金流向分析**、**北向资金追踪**、**龙虎榜解读**、**宏观经济数据**、**策略回测引擎**，数据全部来自东方财富、腾讯、百度等公开免费 API。

**关键词**：A股量化分析 · 股票技术分析 · AI选股 · MACD · KDJ · RSI · 资金流向 · 北向资金 · 龙虎榜 · 策略回测 · Flutter量化工具

---

## 下载

| 版本 | 日期 | 更新内容 | APK |
|:---:|:---:|---|:---:|
| **v1.7.0** | 2026-05-21 | 搜索联想 · 回测时间区间 · WebView · 宏观扩展 · API Key 脱敏 | [下载](https://github.com/jangviktor-web/finance_chart/releases/download/v1.7.0/app-release.apk) |
| **v1.6.0** | 2026-05-21 | AI 热点 · AI 同业对比 · AI 深度分析 · 全局限流 · 功能开关 | [下载](https://github.com/jangviktor-web/finance_chart/releases/tag/v1.6.0) |
| **v1.4.0** | 2026-05-20 | 资金流向 · 北向深度 · 龙虎榜扩展 | [下载](https://github.com/jangviktor-web/finance_chart/releases/tag/v1.4.0) |

> 完整版本列表见 [Releases](https://github.com/jangviktor-web/finance_chart/releases) · 变更详情见 [CHANGELOG](CHANGELOG.md)

---

## 功能特性

### 股票行情数据

| 功能 | 说明 |
|---|---|
| 多源实时行情 | 腾讯 / 东方财富 / 百度，自动降级 |
| 多源 K 线 | 腾讯 / 新浪 / 百度，并行竞速 |
| 分时 & K 线图 | 日 / 周 / 月 / 1·5·15·30·60 分钟 |
| 主题切换 | 暗色 / 亮色 · 中国红涨绿跌 / 美国绿涨红跌 |

### 技术分析（25+ 指标）

| 分类 | 指标 |
|---|---|
| 基础 | MA · MACD · KDJ · RSI · BOLL · VOL |
| 扩展 | OBV · CCI · WR · DMI · TRIX · PSY · ROC · MFI · VR · EMV · MASS · CR · BRAR · ASI · ATR · BIAS · DPO · DFMA |
| 形态 | 锤子线 · 十字星 · 吞没 · 启明星 |
| 自定义 | 所有指标参数可调 |

### AI 智能选股与诊断（东方财富妙想）

| 功能 | 说明 |
|---|---|
| AI 诊断 | 技术面 + 基本面综合诊断，风险等级 + 操作建议 |
| AI 深度分析 | Markdown 综合报告，自动保存历史 |
| AI 选股 | 自然语言描述条件，AI 匹配推荐 |
| AI 对话 | 聊天气泡界面，快捷操作芯片 |
| 热点发现 | 市场热点 Markdown 报告，支持自定义查询 |
| 同业对比 | 中文名 / 代码搜索联想，经营 + 估值双表对比 |

### 资金流向

| 功能 | 说明 |
|---|---|
| 个股资金流 | 主力 / 超大单 / 大单 / 中单 / 小单 净流入 |
| 大盘资金流 | 上证 + 深证 实时快照 |
| 全市场排行 | 今日 / 3日 / 5日 / 10日 主力净流入排序 |

### 北向资金

| 功能 | 说明 |
|---|---|
| 实时分时 | 沪股通 + 深股通 分钟级净买入 |
| 历史趋势 | 近 30 天每日净买入柱状图 |
| 板块排名 | 按持股市值排序 |
| 个股持仓 | 北向持仓历史 + 机构明细 |

### 龙虎榜

| 功能 | 说明 |
|---|---|
| 每日详情 | 上榜个股 + 买卖营业部 |
| 上榜统计 | 近 1/3/6/12 月次数排名 |
| 机构追踪 | 机构席位每日买卖统计 |
| 营业部排行 | 按资金实力 / 收益率 |

### 选股扫描

| 功能 | 说明 |
|---|---|
| 全市场扫描 | 覆盖沪深京 A 股 |
| 5 大策略 | MA 交叉 · KDJ 金叉 · RSI 超卖反弹 · MACD 金叉 · 放量突破 |
| 过滤 | ST / 科创板 / 创业板 可选 |
| 批量操作 | 一键加自选 · CSV 导出 |

### 宏观数据

| 分类 | 指标 |
|---|---|
| 基础 | CPI · PPI · GDP · PMI · M2 · LPR |
| 高频跟踪 | 高炉开工率 · 30城商品房成交 · 动力电池装机 · 机器人产量增速 |
| 政策利率 | 社会融资规模 · MLF 操作利率 |
| 资产联动 | 美元/人民币汇率 · 10年期国债收益率 |

### 其他

| 功能 | 说明 |
|---|---|
| 功能开关 | 每个功能独立启用 / 禁用 |
| 功能日志 | 按 tag 导出运行日志 |
| API Key 脱敏 | 默认脱敏显示，点击切换明文 |
| 全局限流 | 每域名独立限流 + 指数退避 |
| 自选分组 | 多分组管理，跨组移动 |
| 新闻资讯 | 东财 7x24 · 财联社 · 新浪，WebView 内嵌 |
| 板块资金流 | 行业板块资金排行 |
| 涨停 / 跌停池 | 实时涨跌停列表 |
| 融资融券 | 两融余额趋势 |
| 股东人数 | 最新股东变化 |
| 大宗交易 | 每日明细 |
| 限售解禁 | 近期解禁日历 |
| 策略回测 | 自定义时间区间（近1/3/6/12月），收益率 / 回撤 / 夏普 |

---

## 技术栈

| 层级 | 技术 |
|---|---|
| 框架 | Flutter 3.x + Dart |
| 状态管理 | Riverpod (`StateNotifierProvider`) |
| 网络 | Dio + `dart:io` HttpClient |
| 图表 | `CustomPainter` 自绘 |
| 存储 | SharedPreferences |
| Markdown | `flutter_markdown` |
| WebView | `webview_flutter` |
| 编码 | `fast_gbk`（腾讯 GBK 解码） |
| UUID | `uuid` |

---

## 数据源

| 数据源 | 域名 | 用途 |
|---|---|---|
| 东方财富 Push2 | `push2.eastmoney.com` | 实时行情 · 板块资金流 |
| 东方财富 Push2His | `push2his.eastmoney.com` | 个股资金流历史 |
| 东方财富 DataCenter | `datacenter-web.eastmoney.com` | 龙虎榜 · 北向 · 融资融券 · 宏观 |
| 东方财富 AI | `ai-saas.eastmoney.com` | AI 诊断 / 选股 / 热点 / 同业 / 深度 |
| 腾讯行情 | `qt.gtimg.cn` | 实时行情 (GBK) |
| 腾讯 K 线 | `ifzq.gtimg.cn` | K 线数据 |
| 新浪财经 | `money.finance.sina.com.cn` | K 线数据 |
| 百度财经 | `finance.pae.baidu.com` | 实时行情 · K 线 · 概念板块 |
| 财联社 | `cls.cn` | 新闻 |
| 东财新闻 | `np-listapi.eastmoney.com` | 7x24 快讯 |
| 东财搜索 | `searchapi.eastmoney.com` | 股票搜索联想 |

> 所有数据源支持自动降级，单一故障不影响使用

---

## 构建

```bash
flutter build apk --release
```

输出：`build/app/outputs/flutter-apk/app-release.apk`

---

## 版本历史

| 版本 | 日期 | 更新 |
|---|---|---|
| v1.7.0 | 2026-05-21 | 搜索联想 · 回测时间 · WebView · 宏观扩展 · API Key 脱敏 |
| v1.6.0 | 2026-05-21 | AI 热点 · AI 同业 · AI 深度分析 · 全局限流 · 功能开关 |
| v1.5.0 | 2026-05-21 | 多股对比 · 资金流向页 · K 线数据源优化 |
| v1.4.0 | 2026-05-20 | 个股资金流 · 北向深度 · 龙虎榜扩展 |
| v1.3.4 | 2026-05-19 | 多数据源备份 · 百度财经 · 扫描增强 |
| v1.3.3 | 2026-05-19 | 修复 AI 诊断 API 连接 |
| v1.3.2 | 2026-05-19 | API Key 配置 |
| v1.3.1 | 2026-05-19 | AI 诊断 · AI 对话 · AI 选股 |
| v1.3.0 | 2026-05-19 | 首个正式版 — 行情 · 技术分析 · 情绪 · 选股 · 新闻 · 宏观 · 回测 |

> 完整变更见 [CHANGELOG.md](CHANGELOG.md)

---

## 免责声明

本应用仅供学习交流，数据来自公开 API，不构成投资建议。股市有风险，投资需谨慎。
