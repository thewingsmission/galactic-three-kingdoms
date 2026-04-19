import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cell_core_palette.dart';
import '../models/core_color_theme.dart';
import '../models/hex_cell_preview_style.dart';
import '../models/soldier_design_palette.dart';
import 'a1_hex_cell_paint.dart';
import 'hex_cell_preview_layout.dart';

/// Preview + map paints for default, **L1**, **L2**–**L4**, **A1**, **A2** (L1 default mesh on map).
class HexCellStylesPaint {
  HexCellStylesPaint._();

  static Path _path(List<Offset> v) => HexCellPreviewLayout.pathFromVerts(v);

  static const double _innerT = A1HexCellPaint.innerScale;
  /// Three bands inside the outer hex; first ring uses [_a2FirstRingDeltaT], then [_a2RingDeltaT].
  static const int _a2RingCount = 3;

  /// Δt for ring 1 only (outer → first inner boundary).
  static const double _a2FirstRingDeltaT = 0.110817;

  /// Δt for rings 2…3 (uniform).
  static const double _a2RingDeltaT = 0.063979;

  static const Color _a2BlackRing = Color(0xFF000000);

  /// Inner hex boundaries between A2 bands (not the unified outer rim).
  static const double _a2InnerLineWidthPreview = 0.2;

  /// A2: swap fill pattern `[#1,#3,#1]` ↔ `[#3,#1,#3]` on this cadence (seconds).
  static const double a2ThemeSwapPeriodSec = 0.45;

  static bool _a2SwapThemeAt(double effectTimeSec) =>
      (effectTimeSec / a2ThemeSwapPeriodSec).floor() % 2 == 1;

  /// **L2**–**L4** inner-band / parallelogram accent: fixed per faction.
  static const Color _l2AccentRed = Color(0xFF84185B);
  static const Color _l2AccentYellow = Color(0xFFAC4D00);
  static const Color _l2AccentBlue = Color(0xFF2D2995);

  /// **L4** inner-hole corner triangles: fixed per faction (not palette highlight).
  static const Color _l4TriangleRed = Color(0xFFFFAAC6);
  static const Color _l4TriangleYellow = Color(0xFFFFFF84);
  static const Color _l4TriangleBlue = Color(0xFFB299FF);

  /// Radial thickness (Δt) of the **second** L2 ring (accent band), in normalized scale from center
  /// to vertex: inner boundary at t=[_innerT], outer at t=[_innerT]−this.
  static const double _l2SecondRingDeltaT = 0.124968;

  /// Public alias for L2–L4 second-ring thickness (same as [_l2SecondRingDeltaT]).
  static const double l2SecondRingDeltaT = _l2SecondRingDeltaT;

  static Color l2AccentForCoreTheme(CoreColorTheme t) => switch (t) {
        CoreColorTheme.red => _l2AccentRed,
        CoreColorTheme.yellow => _l2AccentYellow,
        CoreColorTheme.blue => _l2AccentBlue,
      };

  static Color l2AccentForSoldierPalette(SoldierDesignPalette p) => switch (p) {
        SoldierDesignPalette.red => _l2AccentRed,
        SoldierDesignPalette.yellow => _l2AccentYellow,
        SoldierDesignPalette.blue => _l2AccentBlue,
      };

  static Color l4TriangleForCoreTheme(CoreColorTheme t) => switch (t) {
        CoreColorTheme.red => _l4TriangleRed,
        CoreColorTheme.yellow => _l4TriangleYellow,
        CoreColorTheme.blue => _l4TriangleBlue,
      };

  static Color l4TriangleForSoldierPalette(SoldierDesignPalette p) => switch (p) {
        SoldierDesignPalette.red => _l4TriangleRed,
        SoldierDesignPalette.yellow => _l4TriangleYellow,
        SoldierDesignPalette.blue => _l4TriangleBlue,
      };

  static const int _l2RingCount = 2;

  /// Outer band matches **L1** thick ring (1.0 → [_innerT]); inner band width is [secondRingDeltaT].
  static double _l2TAtBoundary(int b, double secondRingDeltaT) {
    assert(b >= 0 && b <= _l2RingCount);
    return switch (b) {
      0 => 1.0,
      1 => _innerT,
      2 => _innerT - secondRingDeltaT,
      _ => throw StateError('l2 boundary'),
    };
  }

  /// One corner of **L2** (vertex [i] in pointy-top winding).
  ///
  /// Parallelogram with:
  /// - **A** = outer ring corner `v1[i]`, **C** = inner ring corner `v2[i]` (same index on scaled hex).
  /// - One pair of sides parallel to **V[i−1]→V[i]** (incoming outer edge).
  /// - One pair parallel to **V[i]→V[i+1]** (outgoing outer edge).
  ///
  /// So at the left vertex, sides match the bottom-left and top-left ring edges; at the right
  /// vertex, they match bottom-right and top-right — and analogously for all six corners.
  /// Preview and map share this; perspective uses the same math on projected `v1`/`v2`.
  static Path? _l2CornerParallelogramPathForCorner(
    List<Offset> v1,
    List<Offset> v2,
    int i,
  ) {
    final int im = (i + 5) % 6;
    final int ip = (i + 1) % 6;
    final Offset u = v1[i] - v1[im];
    final Offset w = v1[ip] - v1[i];
    final double uLen = u.distance;
    final double wLen = w.distance;
    if (uLen < 1e-10 || wLen < 1e-10) {
      return null;
    }
    final Offset uh = Offset(u.dx / uLen, u.dy / uLen);
    final Offset wh = Offset(w.dx / wLen, w.dy / wLen);
    // V = t*wh - s*uh  with A=v1[i], B=A+t*wh, D=A-s*uh, C=A+V=v2[i].
    final Offset V = v2[i] - v1[i];
    // Solve V = t*wh - s*uh (unit vectors): t = cross(V,uh)/cross(wh,uh), s = -cross(wh,V)/cross(wh,uh).
    final double detM = wh.dx * uh.dy - wh.dy * uh.dx;
    if (detM.abs() < 1e-14) {
      return null;
    }
    final double t = (V.dx * uh.dy - V.dy * uh.dx) / detM;
    final double s = -(wh.dx * V.dy - wh.dy * V.dx) / detM;
    if (t < 0 || s < 0) {
      return null;
    }
    final Offset a = v1[i];
    final Offset b = Offset(a.dx + wh.dx * t, a.dy + wh.dy * t);
    final Offset d = Offset(a.dx - uh.dx * s, a.dy - uh.dy * s);
    final Offset c = v2[i];
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  }

  static void _paintL2CornerParallelograms(
    Canvas canvas,
    Offset center,
    List<Offset> outerVertices,
    Color fillColor,
    double secondRingDeltaT,
  ) {
    final List<Offset> v1 = _scaledVerts(center, outerVertices, 1.0);
    final double t2 = _l2TAtBoundary(_l2RingCount, secondRingDeltaT);
    final List<Offset> v2 = _scaledVerts(center, outerVertices, t2);
    final Paint paint = Paint()..color = fillColor;

    for (int i = 0; i < 6; i++) {
      final Path? para = _l2CornerParallelogramPathForCorner(
        v1,
        v2,
        i,
      );
      if (para != null) {
        canvas.drawPath(para, paint);
      }
    }
  }

  /// Same pixels as **L1** for this outer hex (thick **#1** + default inner hole).
  static void _paintL1FromOuterVerts(
    Canvas canvas,
    Offset center,
    List<Offset> outerVertices,
    CellCorePalette palette,
  ) {
    final Path outer = _path(outerVertices);
    final Path inner = _innerPath(outer, center);
    final Path fillPath =
        Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(fillPath, Paint()..color = palette.componentIndex1);
    canvas.drawPath(inner, Paint()..color = palette.innerHexHolePaint);
  }

  /// L2–L4: outer **#1** fixed; inner band [l2AccentColor].
  /// [paintCornerParallelograms]: **L3**/**L4**; off for **L2**.
  /// [innerCornerTriangleUnit]: **L4** only — **A1**-style triangles on inner-hole vertices.
  /// [l4TriangleFill]: **L4** triangle fill when [innerCornerTriangleUnit] is set; default [palette.highlight].
  static void _paintL2HexRings(
    Canvas canvas,
    Offset center,
    List<Offset> outerVertices,
    CellCorePalette palette, {
    required Color l2AccentColor,
    double l2SecondRingDeltaT = _l2SecondRingDeltaT,
    bool paintCornerParallelograms = true,
    double? innerCornerTriangleUnit,
    Color? l4TriangleFill,
  }) {
    final Path clip = _path(outerVertices);
    canvas.save();
    canvas.clipPath(clip);

    final Color c1 = palette.componentIndex1;
    final List<Color> ringFills = <Color>[c1, l2AccentColor];

    for (int i = 0; i < _l2RingCount; i++) {
      final double tHi = _l2TAtBoundary(i, l2SecondRingDeltaT);
      final double tLo = _l2TAtBoundary(i + 1, l2SecondRingDeltaT);
      final Path outer = _path(_scaledVerts(center, outerVertices, tHi));
      final Path inner = _path(_scaledVerts(center, outerVertices, tLo));
      final Path band = Path.combine(PathOperation.difference, outer, inner);
      canvas.drawPath(band, Paint()..color = ringFills[i]);
    }

    canvas.drawPath(
      _path(
        _scaledVerts(
          center,
          outerVertices,
          _l2TAtBoundary(_l2RingCount, l2SecondRingDeltaT),
        ),
      ),
      Paint()..color = palette.innerHexHolePaintFrom(l2AccentColor),
    );

    if (paintCornerParallelograms) {
      _paintL2CornerParallelograms(
        canvas,
        center,
        outerVertices,
        l2AccentColor,
        l2SecondRingDeltaT,
      );
    }

    if (innerCornerTriangleUnit != null) {
      final List<Offset> innerHoleVerts = _scaledVerts(
        center,
        outerVertices,
        _l2TAtBoundary(_l2RingCount, l2SecondRingDeltaT),
      );
      A1HexCellPaint.paintInnerCornerTriangles(
        canvas,
        innerHoleVerts,
        innerCornerTriangleUnit,
        l4TriangleFill ?? palette.highlight,
      );
    }

    // L2–L4: no black strokes on ring boundaries (inner band has no outline).
    canvas.restore();
  }

  static Path _innerPath(Path outer, Offset c) {
    final Matrix4 m = Matrix4.identity()
      ..translate(c.dx, c.dy)
      ..scale(_innerT, _innerT)
      ..translate(-c.dx, -c.dy);
    return outer.transform(m.storage);
  }

  static List<Offset> _scaledVerts(
    Offset center,
    List<Offset> outerVertices,
    double t,
  ) =>
      <Offset>[for (final Offset v in outerVertices) center + (v - center) * t];

  /// Scale at boundary [b]: ring 1 width [_a2FirstRingDeltaT], then [_a2RingDeltaT] per step.
  static double _a2TAtBoundary(int b) {
    assert(b >= 0 && b <= _a2RingCount);
    if (b == 0) {
      return 1.0;
    }
    if (b == 1) {
      return 1.0 - _a2FirstRingDeltaT;
    }
    return _a2TAtBoundary(1) - (b - 1) * _a2RingDeltaT;
  }

  /// Fills: rings **1** & **3** share one index, ring **2** the other — `[#1,#3,#1]` ↔ `[#3,#1,#3]` when [swapThemeRings].
  /// [innerBoundaryStrokeWidth] — black strokes on inner hex boundaries (preview: 0.2).
  static void _paintA2HexRings(
    Canvas canvas,
    Offset center,
    List<Offset> outerVertices,
    CellCorePalette palette, {
    required double innerBoundaryStrokeWidth,
    bool swapThemeRings = false,
  }) {
    final Path clip = _path(outerVertices);
    canvas.save();
    canvas.clipPath(clip);

    final Color c1 = palette.componentIndex1;
    final Color c3 = palette.componentIndex3;
    final List<Color> ringFills = swapThemeRings
        ? <Color>[c3, c1, c3]
        : <Color>[c1, c3, c1];
    for (int i = 0; i < _a2RingCount; i++) {
      final double tHi = _a2TAtBoundary(i);
      final double tLo = _a2TAtBoundary(i + 1);
      final Path outer = _path(_scaledVerts(center, outerVertices, tHi));
      final Path inner = _path(_scaledVerts(center, outerVertices, tLo));
      final Path band = Path.combine(PathOperation.difference, outer, inner);
      canvas.drawPath(band, Paint()..color = ringFills[i]);
    }

    canvas.drawPath(
      _path(
        _scaledVerts(center, outerVertices, _a2TAtBoundary(_a2RingCount)),
      ),
      Paint()..color = palette.innerHexHolePaintFrom(ringFills[2]),
    );

    final Paint innerLine = Paint()
      ..color = _a2BlackRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerBoundaryStrokeWidth;
    for (int k = 1; k <= _a2RingCount; k++) {
      final double t = _a2TAtBoundary(k);
      canvas.drawPath(
        _path(_scaledVerts(center, outerVertices, t)),
        innerLine,
      );
    }
    canvas.restore();
  }

  /// Preview cell art only (unified black + green outline drawn by [HexCellPreviewPainter]).
  static void paintPreviewContent(
    Canvas canvas,
    Size size,
    HexCellPreviewStyle style, {
    required CoreColorTheme coreTheme,
    bool a2SwapThemeRings = false,
  }) {
    final CellCorePalette pal = coreTheme.cellPalette;
    switch (style) {
      case HexCellPreviewStyle.defaultStyle:
        _paintDefaultPreview(canvas, size, pal);
        return;
      case HexCellPreviewStyle.l1:
        _paintL1Preview(canvas, size, pal);
        return;
      case HexCellPreviewStyle.l2:
        final Offset lc = HexCellPreviewLayout.center(size);
        final double lr = HexCellPreviewLayout.outerRadius(size);
        _paintL2HexRings(
          canvas,
          lc,
          HexCellPreviewLayout.pointyTopVerts(lc, lr),
          pal,
          l2AccentColor: l2AccentForCoreTheme(coreTheme),
          paintCornerParallelograms: false,
        );
        return;
      case HexCellPreviewStyle.l3:
        final Offset l3c = HexCellPreviewLayout.center(size);
        final double l3r = HexCellPreviewLayout.outerRadius(size);
        _paintL2HexRings(
          canvas,
          l3c,
          HexCellPreviewLayout.pointyTopVerts(l3c, l3r),
          pal,
          l2AccentColor: l2AccentForCoreTheme(coreTheme),
        );
        return;
      case HexCellPreviewStyle.l4:
        final Offset l4c = HexCellPreviewLayout.center(size);
        final double l4r = HexCellPreviewLayout.outerRadius(size);
        _paintL2HexRings(
          canvas,
          l4c,
          HexCellPreviewLayout.pointyTopVerts(l4c, l4r),
          pal,
          l2AccentColor: l2AccentForCoreTheme(coreTheme),
          innerCornerTriangleUnit: HexCellPreviewLayout.scale(size),
          l4TriangleFill: l4TriangleForCoreTheme(coreTheme),
        );
        return;
      case HexCellPreviewStyle.a1:
        A1HexCellPaint.paintCenteredReference(canvas, size, palette: pal);
        return;
      case HexCellPreviewStyle.a2:
        final Offset c = HexCellPreviewLayout.center(size);
        final double r = HexCellPreviewLayout.outerRadius(size);
        _paintA2HexRings(
          canvas,
          c,
          HexCellPreviewLayout.pointyTopVerts(c, r),
          pal,
          innerBoundaryStrokeWidth: _a2InnerLineWidthPreview,
          swapThemeRings: a2SwapThemeRings,
        );
        return;
    }
  }

  /// Strategic map: variant styles; default uses fill path in [Pseudo3DBoardPainter].
  static void paintProjectedCell(
    Canvas canvas, {
    required HexCellPreviewStyle style,
    required CellCorePalette palette,
    required Offset center,
    required List<Offset> outerVertices,
    required double outerRadius,
    required double strokeScale,
    double boardEffectTimeSec = 0,
    SoldierDesignPalette boardFaction = SoldierDesignPalette.red,
  }) {
    assert(outerVertices.length == 6);
    switch (style) {
      case HexCellPreviewStyle.defaultStyle:
        return;
      case HexCellPreviewStyle.l1:
        return;
      case HexCellPreviewStyle.l2:
        _paintL2HexRings(
          canvas,
          center,
          outerVertices,
          palette,
          l2AccentColor: l2AccentForSoldierPalette(boardFaction),
          paintCornerParallelograms: false,
        );
        return;
      case HexCellPreviewStyle.l3:
        _paintL2HexRings(
          canvas,
          center,
          outerVertices,
          palette,
          l2AccentColor: l2AccentForSoldierPalette(boardFaction),
        );
        return;
      case HexCellPreviewStyle.l4:
        _paintL2HexRings(
          canvas,
          center,
          outerVertices,
          palette,
          l2AccentColor: l2AccentForSoldierPalette(boardFaction),
          innerCornerTriangleUnit: A1HexCellPaint.cornerTriangleUnitForMap(outerRadius),
          l4TriangleFill: l4TriangleForSoldierPalette(boardFaction),
        );
        return;
      case HexCellPreviewStyle.a1:
        A1HexCellPaint.paintProjectedCell(
          canvas,
          center: center,
          outerVertices: outerVertices,
          outerRadius: outerRadius,
          strokeScale: strokeScale,
          palette: palette,
        );
        return;
      case HexCellPreviewStyle.a2:
        _paintA2HexRings(
          canvas,
          center,
          outerVertices,
          palette,
          innerBoundaryStrokeWidth: math.max(0.1625, 0.2 * strokeScale),
          swapThemeRings: _a2SwapThemeAt(boardEffectTimeSec),
        );
        return;
    }
  }

  static void _paintDefaultPreview(
    Canvas canvas,
    Size size,
    CellCorePalette pal,
  ) {
    final Offset c = HexCellPreviewLayout.center(size);
    final double r = HexCellPreviewLayout.outerRadius(size);
    final List<Offset> verts = HexCellPreviewLayout.pointyTopVerts(c, r);
    final Path outer = _path(verts);
    final Path inner = _innerPath(outer, c);
    final Path fillPath =
        Path.combine(PathOperation.difference, outer, inner);

    canvas.drawPath(fillPath, Paint()..color = pal.ring);
    canvas.drawPath(inner, Paint()..color = pal.innerHexHolePaint);
  }

  /// Default layout; thick ring + inner use faction ramp index **1** ([CellCorePalette.componentIndex1]).
  static void _paintL1Preview(
    Canvas canvas,
    Size size,
    CellCorePalette pal,
  ) {
    final Offset c = HexCellPreviewLayout.center(size);
    final double r = HexCellPreviewLayout.outerRadius(size);
    _paintL1FromOuterVerts(
      canvas,
      c,
      HexCellPreviewLayout.pointyTopVerts(c, r),
      pal,
    );
  }
}
