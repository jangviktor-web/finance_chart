# 更新日志

所有版本的详细变更记录。

---

## v1.7.0 (2026-05-21)

**搜索联想 + 回测时间选择 + 内嵌浏览器 + 宏观数据扩展 + API Key 脱敏**

### 新增功能

**同业对比搜索联想**
- 输入中文关键词实时联想上市公司（如"中国"→ 中国银行、中国人寿等）
- 输入数字自动匹配 6 位股票代码前缀（如"05"→ 05 开头的代码）
- 500ms 防抖，下拉最多 5 条，点击自动填充并触发分析
- 数据源：东方财富搜索 API（`searchapi.eastmoney.com`）

**回测自定义时间区间**
- 快捷按钮：近1月/近3月/近6月/近1年/近2年
- 自定义 DatePicker 选择任意起止日期
- K 线按日期范围过滤后传入回测引擎
- 回测结果（收益率、回撤、夏普等）限定在选定时间段内计算

**新闻内嵌 WebView**
- 新闻搜索结果点击后在 APP 内用 WebView 加载，不再跳转外部浏览器
- 页面顶部保留返回按钮，可切回新闻列表
- 自动获取网页标题显示在 AppBar
- 新增 `webview_flutter` 依赖

**宏观数据扩展（+8 项）**
- 高频跟踪：高炉开工率、30城商品房成交面积、动力电池装机量、工业机器人产量增速
- 政策利率：社会融资规模、MLF 操作利率
- 资产联动：美元/人民币汇率、10年期国债收益率
- 分 4 组展示：基础指标 / 高频跟踪 / 政策利率 / 资产联动
- 每组带竖线标题分隔

**API Key 脱敏显示**
- 设置页 API Key 默认显示脱敏格式（前6位 + `***` + 后6位）
- 新增眼睛图标切换完整明文/脱敏显示
- 输入框和保存功能不受影响

### 新增文件
- `lib/presentation/screens/webview_screen.dart` — APP 内 WebView 页面

### 修改文件
- `lib/presentation/screens/comparable_company_screen.dart` — 搜索联想 + 防抖
- `lib/presentation/screens/strategy_screen.dart` — 时间区间选择 + 日期过滤
- `lib/presentation/screens/news_screen.dart` — WebView 替代外部浏览器
- `lib/data/datasources/macro_api.dart` — 新增 8 个宏观数据 API 方法
- `lib/presentation/screens/macro_screen.dart` — 分组展示 + 新指标卡片
- `lib/presentation/screens/settings_screen.dart` — API Key 脱敏 + 显示切换
- `pubspec.yaml` — 新增 webview_flutter 依赖

---

## v1.6.0 (2026-05-21)

**AI 功能扩展 + 全局限流 + 功能开关**

### 新增功能

**AI 热点发现**
- 新增市场热点发现页面：输入查询（如"今日热点"/"A股热点"），返回 Markdown 表格报告
- 调用东方财富 `hotspot-discovery` assistant API
- 支持保存历史记录，可回溯查看
- 入口：发现页「市场热点」功能卡片

**AI 同业对比**
- 新增可比公司分析页面：输入公司名（如"贵州茅台"），自动分析同业公司
- 双 Tab 展示经营指标 + 估值指标，横向可滚动 DataTable
- 自动格式化大数字（亿/万），含最大值/中位数/Z-Score 统计行
- 调用东方财富 `comparable-company-analysis` assistant API
- 入口：发现页「同业对比」功能卡片

**AI 深度分析**
- 技术分析页新增"深度分析"按钮，调用 `stock-analysis` assistant API
- 返回 Markdown 格式的综合诊断报告
- 自动保存到历史记录
- Markdown 渲染：表格、标题、粗体、列表等完整支持

**全局限流系统**
- 新增 `RateLimiter` 全局单例：每域名独立限流，指数退避
- 连续失败 5 次自动封锁 60 秒，之后逐步恢复
- 集成到 MarketApi、FundFlowApi、SentimentApi、Scanner
- 新增 `CacheManager` 内存 TTL 缓存（行情 5s/K线 60s/资金流 30s）

**功能开关系统**
- 设置页新增 3 个独立功能开关：市场热点、同业对比、深度分析
- 每个功能可独立启用/禁用，关闭后发现页入口自动隐藏
- 与现有 AI 功能总开关分离，精细控制

**功能日志导出**
- 设置页新增「功能日志导出」区域
- 6 个独立导出按钮：热点发现/同业对比/深度分析/AI接口/行情数据/扫描选股
- 按 tag 过滤日志，只导出指定功能的运行记录
- `AppLog` 增强：新增 `getByTag`/`getByTags`/`toClipboardByTag`/`toClipboardByTags`

### 新增文件
- `lib/presentation/widgets/markdown_card.dart` — Markdown 渲染组件（深色主题）
- `lib/data/models/ai_report.dart` — AI 报告数据模型（HotspotItem/ComparableCompanyData/AiQueryRecord）
- `lib/data/datasources/local/ai_history_storage.dart` — AI 查询历史存储（最多 30 条）
- `lib/presentation/screens/hotspot_screen.dart` — 热点发现页面
- `lib/presentation/screens/comparable_company_screen.dart` — 可比公司分析页面
- `lib/core/utils/rate_limiter.dart` — 全局限流器
- `lib/data/datasources/local/cache_manager.dart` — 内存 TTL 缓存管理器

### 修改文件
- `lib/data/datasources/em_ai_api.dart` — 新增 3 个 assistant API 方法 + 操作日志
- `lib/presentation/screens/analysis_screen.dart` — 深度分析 + MarkdownCard 渲染
- `lib/presentation/screens/discover_screen.dart` — 新增热点/同业入口，使用独立开关
- `lib/presentation/screens/settings_screen.dart` — 功能开关 + 功能日志导出 UI
- `lib/presentation/providers/settings_provider.dart` — 新增 enableHotspot/enablePeerCompare/enableDeepAnalysis
- `lib/data/datasources/local/settings_storage.dart` — 新增 3 个开关持久化 key
- `lib/core/utils/app_logger.dart` — 增强 tag 过滤和导出能力
- `lib/data/datasources/market_api.dart` — 集成限流 + 缓存
- `lib/data/datasources/fund_flow_api.dart` — 集成限流
- `lib/data/datasources/sentiment_api.dart` — 集成限流
- `lib/domain/services/market_scanner.dart` — 集成限流，批处理优化
- `pubspec.yaml` — 新增 flutter_markdown 依赖

---

## v1.5.0 (2026-05-21)

**多股对比 + 资金流向 + K线数据源优化**

### 新增功能

**多股对比**
- 新增多股对比页面：支持最多 5 只股票同时对比
- 5 维评分引擎：估值/动量/波动/趋势/量能，每维 0-100 分
- 雷达图可视化：`RadarChartPainter` 自绘五边形网格 + 填充多边形
- 评分排名表：按总分排序，各维度分数 + 条形图
- 股票搜索添加，长按删除，点击跳转K线图
- 入口：发现页「多股对比」功能卡片

**资金流向**
- 新增独立资金流向页面：3 Tab 布局
- 主力资金：大盘实时快照 + 全市场排行（今日/3日/5日/10日切换）
- 板块资金：行业板块资金流向排行
- 北向资金：实时快照 + 近 20 日净买入柱状图 + 板块持仓排名
- 入口：发现页「资金流向」功能卡片

**K 线数据源优化**
- 新增东方财富 K 线数据源：`push2his.eastmoney.com/api/qt/stock/kline/get`
- 支持日/周/月/分钟线，同一端点不同 `klt` 参数
- auto 模式优先级：东方财富 → 腾讯 → 新浪
- 腾讯日/周/月线改用 `fqkline/get` 接口（原 `mkline` 已失效）
- 百度 K 线接口已失效，静默跳过不再抛异常

### 新增文件
- `lib/data/models/stock_score.dart` — 多维评分模型
- `lib/domain/services/scoring_engine.dart` — 5 维评分引擎（纯 Dart 计算）
- `lib/presentation/screens/compare_screen.dart` — 多股对比页面
- `lib/presentation/widgets/chart/radar_chart_painter.dart` — 雷达图 Painter
- `lib/presentation/screens/fund_flow_screen.dart` — 资金流向页面

### 修改文件
- `lib/core/constants/api_endpoints.dart` — 新增东方财富 K 线/分时端点
- `lib/data/datasources/market_api.dart` — 集成东方财富 K 线 + 修复腾讯 K 线
- `lib/data/datasources/baidu_api.dart` — 百度 K 线静默跳过
- `lib/presentation/screens/discover_screen.dart` — 新增多股对比/资金流向入口

---

## v1.4.0 (2026-05-20)

**资金流向 + 北向深度 + 龙虎榜扩展**

### 新增功能

**资金流向系统**
- 新增个股资金流向历史：主力/超大单/大单/中单/小单 净流入日线数据
- 新增大盘实时资金流快照：上证 + 深证合并展示
- 新增全市场资金流排行榜：支持按今日/3日/5日/10日主力净流入排序
- 数据来源：`push2his.eastmoney.com`（新数据源，不与现有 push2 冲突）

**北向资金深度数据**
- 新增板块北向资金排名：按持股市值排序，展示持股占比和净买入
- 新增个股北向持仓历史：单只股票外资持股数量/市值/占比变化趋势
- 数据报告：`RPT_MUTUAL_BOARD_HOLDRANK_WEB`、`RPT_MUTUAL_HOLDSTOCKNDATE_STA`

**龙虎榜扩展**
- 新增上榜统计：个股近 1/3/6/12 月上榜次数和累计净买入排名
- 新增机构买卖每日统计：机构席位买入/卖出/净额明细
- 新增营业部排行：按资金实力排序的活跃营业部列表
- 数据报告：`RPT_BILLBOARD_TRADEALL`、`RPT_ORGANIZATION_TRADE_DETAILS`、`RPT_RATEDEPT_RETURNT_RANKING`

**技术分析页集成**
- 技术分析页新增"资金流向"卡片
- 展示最近一天汇总（6 项指标）+ 近 5 日主力净流入柱状图
- 自动加载，无需手动操作

### 新增文件
- `lib/data/datasources/fund_flow_api.dart` — 资金流向 API 客户端（3 个方法）
- `lib/data/models/sentiment_data.dart` — 新增 7 个数据模型

### 修改文件
- `lib/core/constants/api_endpoints.dart` — 新增 push2his + 资金流端点常量
- `lib/data/datasources/sentiment_api.dart` — 新增 5 个 API 方法
- `lib/presentation/screens/analysis_screen.dart` — 集成资金流向卡片

### 数据模型新增
- `FundFlowDetail` — 个股单日资金流（9 个字段）
- `MarketFundFlow` — 大盘资金流快照（6 个字段）
- `FundFlowRankItem` — 资金流排行条目（10 个字段）
- `NorthboundBoardRank` — 北向板块排名（6 个字段）
- `NorthboundStockHold` — 个股北向持仓（5 个字段）
- `DragonTigerOrgItem` — 龙虎榜机构/营业部（6 个字段）
- `DragonTigerStatItem` — 龙虎榜上榜统计（6 个字段）

---

## v1.3.4 (2026-05-19)

**多数据源备份系统 + 扫描增强**

### 新增功能

**多数据源设置**
- 新增设置页"数据源设置"区域，4 个独立选择器
- 实时行情数据源：腾讯 / 东方财富 / 百度 / 自动
- K 线数据源：腾讯 / 新浪 / 百度 / 自动
- 新闻数据源 / 资金流数据源：预留配置
- 设置持久化保存，重启后自动恢复

**百度财经数据源**
- 新增百度财经 API 接入：`finance.pae.baidu.com`
- 实时行情：支持沪深 A 股实时价格/涨跌幅/成交量
- K 线数据：支持日 K 线历史数据
- 概念板块：百度概念板块涨跌幅排行
- 作为自动模式下的兜底数据源

**MarketApi 多源架构重构**
- 实时行情：腾讯 → 东方财富 → 百度 三级降级
- K 线数据：腾讯 + 新浪 + 百度 并行竞速（返回最快结果）
- 单一数据源故障时自动切换，用户无感知

**扫描选股增强**
- 新增"一键加自选"按钮：批量添加扫描结果到指定自选分组
- 弹出分组选择底部弹窗，显示新增/重复数量统计
- 自动跳过已存在的股票，完成后显示添加统计
- 新增"导出数据"按钮：扫描结果导出为 CSV 文件
- 文件保存到 Download 目录（文件名含日期时间）
- 同时复制到剪贴板作为备份

### 新增文件
- `lib/data/datasources/baidu_api.dart` — 百度财经 API 客户端
- `lib/data/models/data_source_config.dart` — 数据源配置模型

### 修改文件
- `lib/data/datasources/market_api.dart` — 集成百度数据源 + 多源切换
- `lib/presentation/providers/market_provider.dart` — 响应数据源设置变更
- `lib/presentation/providers/settings_provider.dart` — 新增 4 个数据源配置字段
- `lib/data/datasources/local/settings_storage.dart` — 新增 4 个数据源持久化 key
- `lib/presentation/screens/settings_screen.dart` — 新增数据源选择器 UI
- `lib/presentation/screens/scan_screen.dart` — 批量加自选 + CSV 导出

---

## v1.3.3 (2026-05-19)

**修复 AI 诊断 API 连接**

### 问题修复
- **[关键修复]** 修复 AI 诊断返回"密钥不存在或已失效"的问题
- 根因：使用了错误的 API 端点 `mkapi2.dfcfs.com` 和错误的请求头 `apikey`
- 修正为正确的端点：`ai-saas.eastmoney.com/proxy/b/mcp/tool/searchData`
- 修正请求头为：`em_api_key`
- 修正请求体格式：包含 `toolContext.callId` 和 `userInfo.userId`

### 技术细节
- 参考 `D:\Aeolus-master` 项目的 `get_data.py` 脚本确认正确格式
- `searchData` 接口使用 `em_api_key` 头部认证
- `stock-screen` 接口使用 `apikey` 头部认证（两者不同）
- 使用 Python `requests.post()` 验证 API 响应正常（curl 被 rtk hook 干扰）

### 修改文件
- `lib/data/datasources/em_ai_api.dart` — 重写 API 客户端，修正端点和认证方式

---

## v1.3.2 (2026-05-19)

**API Key 配置**

### 新增功能
- 新增设置页"AI 配置"区域
- 支持修改东方财富妙想 API Key
- 默认 Key：`em_IjcEMTprwBcjOdyC7dqv1ZNJ1HlV3mIH`
- 输入框支持显示/隐藏密码
- 修改后即时生效，AI 诊断和选股使用新 Key
- 设置持久化保存

### 修改文件
- `lib/presentation/providers/settings_provider.dart` — 新增 `emApiKey` 字段
- `lib/data/datasources/local/settings_storage.dart` — 新增 API Key 持久化
- `lib/presentation/screens/settings_screen.dart` — 新增 API Key 输入框
- `lib/presentation/screens/ai_chat_screen.dart` — 使用动态 API Key
- `lib/presentation/screens/analysis_screen.dart` — 使用动态 API Key

---

## v1.3.1 (2026-05-19)

**AI 智能能力**

### 新增功能

**AI 诊断**
- 技术分析页新增"AI 诊断"卡片
- 一键获取个股综合诊断：风险等级（低/中/高）+ 操作建议 + 信号列表
- 诊断结果带颜色标签和结构化展示
- 底部"AI 对话"按钮跳转到 AI 聊天页

**AI 对话**
- 新增独立 AI 对话页面：`AiChatScreen`
- 聊天气泡界面，支持用户/AI 消息区分
- 快捷操作芯片：诊断当前股票、推荐潜力股、分析大盘
- 支持传入股票代码，从分析页跳转时预填
- 加载状态：typing indicator（三点动画）
- 空态引导：首次进入显示功能说明

**AI 选股**
- 东方财富妙想 `stock-screen` 接口接入
- 自然语言描述选股条件，AI 返回匹配股票列表

**发现页入口**
- 发现页新增"AI 助手"入口卡片
- 设置页新增"AI 功能"开关（默认开启）
- 关闭后发现页 AI 入口自动隐藏

### 新增文件
- `lib/data/models/ai_data.dart` — AI 数据模型（AiDiagnosisResult、AiStockPick、AiChatMessage）
- `lib/data/datasources/em_ai_api.dart` — 东方财富妙想 API 客户端
- `lib/presentation/screens/ai_chat_screen.dart` — AI 对话页面

### 修改文件
- `lib/presentation/screens/analysis_screen.dart` — 集成 AI 诊断卡片
- `lib/presentation/screens/discover_screen.dart` — 新增 AI 助手入口
- `lib/presentation/screens/settings_screen.dart` — 新增 AI 功能开关
- `lib/presentation/providers/settings_provider.dart` — 新增 `enableAi` 字段
- `lib/data/datasources/local/settings_storage.dart` — 新增 AI 开关持久化

---

## v1.3.0 (2026-05-19)

**首个正式版本 — 完整功能上线**

### 核心功能

**行情系统**
- 实时行情：腾讯 + 东方财富双数据源，自动降级
- K 线图表：CustomPainter 自绘，支持日/周/月/分钟线
- 股票搜索：东财搜索 API，实时联想
- 自选分组：多分组管理，支持增删改 + 跨组移动

**技术分析（25+ 指标）**
- 基础指标：MA(5/10/20/60)、MACD、KDJ、RSI、BOLL、VOL
- 扩展指标：OBV、CCI、WR、DMI、TRIX、PSY、ROC、MFI、VR、EMV、MASS、CR、BRAR、ASI、ATR、BIAS、DPO、DFMA
- 副图指标切换 + 叠加指标选择
- 指标参数全部可自定义
- K 线形态识别：锤子线、十字星、吞没、启明星等

**市场情绪**
- 涨停池 / 跌停池：实时涨跌停股票列表
- 龙虎榜：每日上榜个股 + 买卖营业部
- 北向资金：实时分时 + 历史趋势
- 融资融券：两融余额趋势
- 板块资金流：行业板块资金流向排行

**选股扫描**
- 全市场 A 股扫描：覆盖沪深京三市
- 5 大策略：MA 均线交叉、KDJ 金叉、RSI 超卖反弹、MACD 金叉、放量突破
- 过滤条件：ST、科创板、创业板可选过滤
- 扫描历史：保存最近 20 次扫描记录
- 配置管理：保存最近 3 套扫描配置

**新闻资讯**
- 东财 7x24 实时快讯
- 财联社电报
- 新浪财经直播
- 股票相关新闻搜索

**宏观数据**
- CPI、PPI、GDP、PMI、M2、LPR 六大宏观指标
- 历史趋势图表展示

**个股深度**
- 股东人数变化
- 大宗交易明细
- 限售解禁日历
- 估值指标（PE/PB/PS/总市值/流通市值）

**策略回测**
- 简单策略回测引擎
- 支持自定义买入/卖出条件
- 回测结果：收益率、最大回撤、夏普比率

**设置系统**
- 暗色/亮色主题切换
- 涨跌色风格：中国（红涨绿跌）/ 美国（绿涨红跌）
- 自动刷新间隔配置
- 数据管理：自选导出、日志导出

### 架构设计
- **分层架构**：data → domain → presentation 三层分离
- **状态管理**：Riverpod StateNotifierProvider
- **数据源降级**：多源自动切换，单一故障不影响使用
- **图表引擎**：CustomPainter 自绘，支持手势交互（缩放/拖拽/十字光标）
- **离线支持**：SharedPreferences 持久化设置和缓存

### 技术指标实现
- MA：简单移动平均（5/10/20/60/120/250 日）
- MACD：DIF/DEA/柱状图，参数可调（12/26/9）
- KDJ：K/D/J 三线，参数可调（9/3/3）
- RSI：相对强弱指标，参数可调（14 日）
- BOLL：布林带（上轨/中轨/下轨），参数可调（20/2.0）
- OBV：能量潮指标
- CCI：商品通道指标
- WR：威廉指标
- DMI：趋向指标（+DI/-DI/ADX/ADXR）
- TRIX：三重指数平滑移动平均
- PSY：心理线指标
- ROC：变动率指标
- MFI：资金流量指标
- VR：成交量比率
- EMV：简易波动指标
- MASS：梅斯线
- CR：带状能量线
- BRAR：情绪指标
- ASI：振动升降指标
- ATR：真实波幅
- BIAS：乖离率
- DPO：去趋势价格震荡指标
- DFMA：平行线差指标
- VOL：成交量（红绿柱）

### 初始提交
- 218 个文件
- 23,166 行代码
- 15 个页面、10 个 API 客户端、20+ 数据模型

---

## 版本命名规则

- **主版本号**：重大架构变更或全新功能模块
- **次版本号**：新功能添加或显著改进
- **修订号**：Bug 修复和小改动

格式：`v{主}.{次}.{修}` — 例如 `v1.4.0`
