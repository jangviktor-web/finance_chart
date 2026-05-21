/// 指标参数配置 — 用户可自定义
class IndicatorParams {
  // MA 周期列表
  final List<int> maPeriods;

  // MACD 参数
  final int macdShort;
  final int macdLong;
  final int macdSignal;

  // RSI 参数
  final int rsiPeriod;

  // KDJ 参数
  final int kdjPeriod;

  // BOLL 参数
  final int bollPeriod;
  final double bollMultiplier;

  // CCI 参数
  final int cciPeriod;

  // WR 参数
  final int wrPeriod;

  // ATR 参数
  final int atrPeriod;

  // BIAS 参数
  final List<int> biasPeriods;

  // DMI 参数
  final int dmiPeriod;

  // TRIX 参数
  final int trixPeriod;
  final int trixSignal;

  // VR 参数
  final int vrPeriod;

  // MFI 参数
  final int mfiPeriod;

  // ROC 参数
  final int rocPeriod;

  // EXPMA 参数
  final int expmaShort;
  final int expmaLong;

  // PSY 参数
  final int psyPeriod;

  // CR 参数
  final int crPeriod;

  // DPO 参数
  final int dpoPeriod;

  // MTM 参数
  final int mtmPeriod;
  final int mtmSignal;

  // MASS 参数
  final int massPeriod1;
  final int massPeriod2;

  // KTN 参数
  final int ktnPeriod;
  final double ktnMultiplier;

  const IndicatorParams({
    this.maPeriods = const [5, 10, 20, 60],
    this.macdShort = 12,
    this.macdLong = 26,
    this.macdSignal = 9,
    this.rsiPeriod = 14,
    this.kdjPeriod = 9,
    this.bollPeriod = 20,
    this.bollMultiplier = 2.0,
    this.cciPeriod = 14,
    this.wrPeriod = 14,
    this.atrPeriod = 14,
    this.biasPeriods = const [6, 12, 24],
    this.dmiPeriod = 14,
    this.trixPeriod = 12,
    this.trixSignal = 9,
    this.vrPeriod = 26,
    this.mfiPeriod = 14,
    this.rocPeriod = 12,
    this.expmaShort = 12,
    this.expmaLong = 50,
    this.psyPeriod = 12,
    this.crPeriod = 26,
    this.dpoPeriod = 20,
    this.mtmPeriod = 12,
    this.mtmSignal = 6,
    this.massPeriod1 = 9,
    this.massPeriod2 = 25,
    this.ktnPeriod = 20,
    this.ktnMultiplier = 2.0,
  });

  IndicatorParams copyWith({
    List<int>? maPeriods,
    int? macdShort,
    int? macdLong,
    int? macdSignal,
    int? rsiPeriod,
    int? kdjPeriod,
    int? bollPeriod,
    double? bollMultiplier,
    int? cciPeriod,
    int? wrPeriod,
    int? atrPeriod,
    List<int>? biasPeriods,
    int? dmiPeriod,
    int? trixPeriod,
    int? trixSignal,
    int? vrPeriod,
    int? mfiPeriod,
    int? rocPeriod,
    int? expmaShort,
    int? expmaLong,
    int? psyPeriod,
    int? crPeriod,
    int? dpoPeriod,
    int? mtmPeriod,
    int? mtmSignal,
    int? massPeriod1,
    int? massPeriod2,
    int? ktnPeriod,
    double? ktnMultiplier,
  }) {
    return IndicatorParams(
      maPeriods: maPeriods ?? this.maPeriods,
      macdShort: macdShort ?? this.macdShort,
      macdLong: macdLong ?? this.macdLong,
      macdSignal: macdSignal ?? this.macdSignal,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      kdjPeriod: kdjPeriod ?? this.kdjPeriod,
      bollPeriod: bollPeriod ?? this.bollPeriod,
      bollMultiplier: bollMultiplier ?? this.bollMultiplier,
      cciPeriod: cciPeriod ?? this.cciPeriod,
      wrPeriod: wrPeriod ?? this.wrPeriod,
      atrPeriod: atrPeriod ?? this.atrPeriod,
      biasPeriods: biasPeriods ?? this.biasPeriods,
      dmiPeriod: dmiPeriod ?? this.dmiPeriod,
      trixPeriod: trixPeriod ?? this.trixPeriod,
      trixSignal: trixSignal ?? this.trixSignal,
      vrPeriod: vrPeriod ?? this.vrPeriod,
      mfiPeriod: mfiPeriod ?? this.mfiPeriod,
      rocPeriod: rocPeriod ?? this.rocPeriod,
      expmaShort: expmaShort ?? this.expmaShort,
      expmaLong: expmaLong ?? this.expmaLong,
      psyPeriod: psyPeriod ?? this.psyPeriod,
      crPeriod: crPeriod ?? this.crPeriod,
      dpoPeriod: dpoPeriod ?? this.dpoPeriod,
      mtmPeriod: mtmPeriod ?? this.mtmPeriod,
      mtmSignal: mtmSignal ?? this.mtmSignal,
      massPeriod1: massPeriod1 ?? this.massPeriod1,
      massPeriod2: massPeriod2 ?? this.massPeriod2,
      ktnPeriod: ktnPeriod ?? this.ktnPeriod,
      ktnMultiplier: ktnMultiplier ?? this.ktnMultiplier,
    );
  }

  /// 显示当前参数的标签
  String get macdLabel => 'MACD($macdShort,$macdLong,$macdSignal)';
  String get rsiLabel => 'RSI($rsiPeriod)';
  String get kdjLabel => 'KDJ($kdjPeriod)';
  String get bollLabel => 'BOLL($bollPeriod,$bollMultiplier)';
  String get maLabel => 'MA(${maPeriods.join(",")})';
  String get cciLabel => 'CCI($cciPeriod)';
  String get wrLabel => 'WR($wrPeriod)';
  String get atrLabel => 'ATR($atrPeriod)';
  String get biasLabel => 'BIAS(${biasPeriods.join(",")})';
  String get dmiLabel => 'DMI($dmiPeriod)';
  String get trixLabel => 'TRIX($trixPeriod,$trixSignal)';
  String get vrLabel => 'VR($vrPeriod)';
  String get mfiLabel => 'MFI($mfiPeriod)';
  String get rocLabel => 'ROC($rocPeriod)';
  String get expmaLabel => 'EXPMA($expmaShort,$expmaLong)';
  String get psyLabel => 'PSY($psyPeriod)';
  String get crLabel => 'CR($crPeriod)';
  String get dpoLabel => 'DPO($dpoPeriod)';
  String get mtmLabel => 'MTM($mtmPeriod,$mtmSignal)';
  String get massLabel => 'MASS($massPeriod1,$massPeriod2)';
  String get ktnLabel => 'KTN($ktnPeriod,$ktnMultiplier)';
}
