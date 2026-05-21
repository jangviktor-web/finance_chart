class IndicatorData {
  final List<List<double>> maLines;  // [[ma5], [ma10], [ma20], [ma60]]
  final List<int> maPeriods;

  // MACD
  final List<double> dif;
  final List<double> dea;
  final List<double> macdHist;

  // KDJ
  final List<double> k;
  final List<double> d;
  final List<double> j;

  // RSI
  final List<double> rsi;

  // BOLL
  final List<double> bollMid;
  final List<double> bollUpper;
  final List<double> bollLower;

  // ── 新增 24 个指标 ──

  // CCI 顺势指标
  final List<double>? cci;

  // WR 威廉指标
  final List<double>? wr;

  // ATR 真实波幅
  final List<double>? atr;

  // BIAS 乖离率 (多周期)
  final List<List<double>>? biasLines;
  final List<int>? biasPeriods;

  // OBV 能量潮
  final List<double>? obv;

  // DMI 趋向指标 (PDI/MDI/ADX/ADXR)
  final Map<String, List<double>>? dmi;

  // TRIX 三重指数平滑平均线
  final List<double>? trix;
  final List<double>? trixSignal;

  // VR 成交量比率
  final List<double>? vr;

  // EMV 简易波动指标
  final List<double>? emv;

  // BBI 多空指标
  final List<double>? bbi;

  // MFI 资金流量指标
  final List<double>? mfi;

  // ASI 振动升降指标
  final List<double>? asi;

  // PSY 心理线
  final List<double>? psy;

  // CR 带状能量线
  final List<double>? cr;

  // DPO 去趋势价格震荡器
  final List<double>? dpo;

  // BRAR 情绪指标
  final List<double>? br;
  final List<double>? ar;

  // DFMA 平行线差指标
  final List<double>? dfmaDif;
  final List<double>? dfmaDifma;

  // MTM 动量指标
  final List<double>? mtm;
  final List<double>? mtmSignal;

  // MASS 梅斯线
  final List<double>? mass;

  // ROC 变动速率
  final List<double>? roc;

  // EXPMA 指数平均数
  final List<double>? expmaShort;
  final List<double>? expmaLong;

  // KTN 肯特纳通道 (upper/lower/middle)
  final Map<String, List<double>>? ktn;

  // XSII 薛斯通道II (a/b/c/d)
  final Map<String, List<double>>? xsii;

  // 已计算的指标集合（惰性计算追踪）
  final Set<String> activeIndicators;

  IndicatorData({
    required this.maLines,
    required this.maPeriods,
    required this.dif,
    required this.dea,
    required this.macdHist,
    required this.k,
    required this.d,
    required this.j,
    required this.rsi,
    required this.bollMid,
    required this.bollUpper,
    required this.bollLower,
    this.cci,
    this.wr,
    this.atr,
    this.biasLines,
    this.biasPeriods,
    this.obv,
    this.dmi,
    this.trix,
    this.trixSignal,
    this.vr,
    this.emv,
    this.bbi,
    this.mfi,
    this.asi,
    this.psy,
    this.cr,
    this.dpo,
    this.br,
    this.ar,
    this.dfmaDif,
    this.dfmaDifma,
    this.mtm,
    this.mtmSignal,
    this.mass,
    this.roc,
    this.expmaShort,
    this.expmaLong,
    this.ktn,
    this.xsii,
    this.activeIndicators = const {},
  });

  factory IndicatorData.empty() => IndicatorData(
    maLines: [[], [], [], []],
    maPeriods: [5, 10, 20, 60],
    dif: [],
    dea: [],
    macdHist: [],
    k: [],
    d: [],
    j: [],
    rsi: [],
    bollMid: [],
    bollUpper: [],
    bollLower: [],
  );

  /// 合并新计算的指标到现有数据
  IndicatorData merge({
    List<double>? cci,
    List<double>? wr,
    List<double>? atr,
    List<List<double>>? biasLines,
    List<int>? biasPeriods,
    List<double>? obv,
    Map<String, List<double>>? dmi,
    List<double>? trix,
    List<double>? trixSignal,
    List<double>? vr,
    List<double>? emv,
    List<double>? bbi,
    List<double>? mfi,
    List<double>? asi,
    List<double>? psy,
    List<double>? cr,
    List<double>? dpo,
    List<double>? br,
    List<double>? ar,
    List<double>? dfmaDif,
    List<double>? dfmaDifma,
    List<double>? mtm,
    List<double>? mtmSignal,
    List<double>? mass,
    List<double>? roc,
    List<double>? expmaShort,
    List<double>? expmaLong,
    Map<String, List<double>>? ktn,
    Map<String, List<double>>? xsii,
    Set<String>? newActiveIndicators,
  }) {
    return IndicatorData(
      maLines: maLines,
      maPeriods: maPeriods,
      dif: dif,
      dea: dea,
      macdHist: macdHist,
      k: k,
      d: d,
      j: j,
      rsi: rsi,
      bollMid: bollMid,
      bollUpper: bollUpper,
      bollLower: bollLower,
      cci: cci ?? this.cci,
      wr: wr ?? this.wr,
      atr: atr ?? this.atr,
      biasLines: biasLines ?? this.biasLines,
      biasPeriods: biasPeriods ?? this.biasPeriods,
      obv: obv ?? this.obv,
      dmi: dmi ?? this.dmi,
      trix: trix ?? this.trix,
      trixSignal: trixSignal ?? this.trixSignal,
      vr: vr ?? this.vr,
      emv: emv ?? this.emv,
      bbi: bbi ?? this.bbi,
      mfi: mfi ?? this.mfi,
      asi: asi ?? this.asi,
      psy: psy ?? this.psy,
      cr: cr ?? this.cr,
      dpo: dpo ?? this.dpo,
      br: br ?? this.br,
      ar: ar ?? this.ar,
      dfmaDif: dfmaDif ?? this.dfmaDif,
      dfmaDifma: dfmaDifma ?? this.dfmaDifma,
      mtm: mtm ?? this.mtm,
      mtmSignal: mtmSignal ?? this.mtmSignal,
      mass: mass ?? this.mass,
      roc: roc ?? this.roc,
      expmaShort: expmaShort ?? this.expmaShort,
      expmaLong: expmaLong ?? this.expmaLong,
      ktn: ktn ?? this.ktn,
      xsii: xsii ?? this.xsii,
      activeIndicators: {...activeIndicators, ...?newActiveIndicators},
    );
  }
}
