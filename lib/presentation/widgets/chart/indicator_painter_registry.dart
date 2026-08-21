import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import 'asi_painter.dart';
import 'atr_painter.dart';
import 'bias_painter.dart';
import 'brar_painter.dart';
import 'cci_painter.dart';
import 'cr_painter.dart';
import 'dfma_painter.dart';
import 'dmi_painter.dart';
import 'dpo_painter.dart';
import 'emv_painter.dart';
import 'kdj_painter.dart';
import 'macd_painter.dart';
import 'mass_painter.dart';
import 'mfi_painter.dart';
import 'obv_painter.dart';
import 'psy_painter.dart';
import 'roc_painter.dart';
import 'rsi_painter.dart';
import 'trix_painter.dart';
import 'vr_painter.dart';
import 'wr_painter.dart';

/// 副图指标 Painter 工厂类型：统一构造签名
typedef IndicatorPainterBuilder = CustomPainter Function(
  IndicatorData indicators,
  int visibleStart,
  int visibleEnd,
  double candleWidth,
);

/// 指标 Painter 注册表（P1-6）
/// 新增指标时只需在此登记一项，无需再改动图表组件。
final Map<String, IndicatorPainterBuilder> indicatorPainterRegistry = {
  'MACD': (i, s, e, w) => MacdPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'KDJ': (i, s, e, w) => KdjPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'RSI': (i, s, e, w) => RsiPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'CCI': (i, s, e, w) => CciPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'WR': (i, s, e, w) => WrPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'DMI': (i, s, e, w) => DmiPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'BIAS': (i, s, e, w) => BiasPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'ATR': (i, s, e, w) => AtrPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'OBV': (i, s, e, w) => ObvPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'TRIX': (i, s, e, w) => TrixPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'EMV': (i, s, e, w) => EmvPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'MFI': (i, s, e, w) => MfiPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'VR': (i, s, e, w) => VrPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'ROC': (i, s, e, w) => RocPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'PSY': (i, s, e, w) => PsyPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'CR': (i, s, e, w) => CrPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'DPO': (i, s, e, w) => DpoPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'BRAR': (i, s, e, w) => BrarPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'MASS': (i, s, e, w) => MassPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'ASI': (i, s, e, w) => AsiPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
  'DFMA': (i, s, e, w) => DfmaPainter(indicators: i, visibleStart: s, visibleEnd: e, candleWidth: w),
};
