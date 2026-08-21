import 'package:flutter/material.dart';
import '../../../data/models/indicator_data.dart';
import 'chart_viewport.dart';
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

/// 副图指标 Painter 工厂类型：统一构造签名（P1-6 + P1-5）
typedef IndicatorPainterBuilder = CustomPainter Function(
  IndicatorData indicators,
  ChartViewport viewport,
);

/// 指标 Painter 注册表（P1-6）
/// 新增指标时只需在此登记一项，无需再改动图表组件。
final Map<String, IndicatorPainterBuilder> indicatorPainterRegistry = {
  'MACD': (i, v) => MacdPainter(indicators: i, viewport: v),
  'KDJ': (i, v) => KdjPainter(indicators: i, viewport: v),
  'RSI': (i, v) => RsiPainter(indicators: i, viewport: v),
  'CCI': (i, v) => CciPainter(indicators: i, viewport: v),
  'WR': (i, v) => WrPainter(indicators: i, viewport: v),
  'DMI': (i, v) => DmiPainter(indicators: i, viewport: v),
  'BIAS': (i, v) => BiasPainter(indicators: i, viewport: v),
  'ATR': (i, v) => AtrPainter(indicators: i, viewport: v),
  'OBV': (i, v) => ObvPainter(indicators: i, viewport: v),
  'TRIX': (i, v) => TrixPainter(indicators: i, viewport: v),
  'EMV': (i, v) => EmvPainter(indicators: i, viewport: v),
  'MFI': (i, v) => MfiPainter(indicators: i, viewport: v),
  'VR': (i, v) => VrPainter(indicators: i, viewport: v),
  'ROC': (i, v) => RocPainter(indicators: i, viewport: v),
  'PSY': (i, v) => PsyPainter(indicators: i, viewport: v),
  'CR': (i, v) => CrPainter(indicators: i, viewport: v),
  'DPO': (i, v) => DpoPainter(indicators: i, viewport: v),
  'BRAR': (i, v) => BrarPainter(indicators: i, viewport: v),
  'MASS': (i, v) => MassPainter(indicators: i, viewport: v),
  'ASI': (i, v) => AsiPainter(indicators: i, viewport: v),
  'DFMA': (i, v) => DfmaPainter(indicators: i, viewport: v),
};
