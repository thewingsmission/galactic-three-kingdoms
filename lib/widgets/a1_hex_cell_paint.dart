import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cell_core_palette.dart';
import 'hex_cell_preview_layout.dart';

/// **A1** hex art: rim, outer echoes, inner corner triangles ([CellCorePalette]).
///
/// Tuned for performance: **no** stacked “glow” passes — each shape is drawn at
/// most once (or twice where a stroke is needed for clarity). Solid colors only;
/// no [ImageFilter]/[MaskFilter], no particles.
class A1HexCellPaint {
  A1HexCellPaint._();

  static const double innerScale = 0.847;

  /// Number of outer echo hexes (stroke-only). Kept small for map FPS.
  static const int _thinRingCount = 2;

  static Path _pathFromVerts(List<Offset> v) {
    final Path p = Path()..moveTo(v[0].dx, v[0].dy);
    for (int i = 1; i < 6; i++) {
      p.lineTo(v[i].dx, v[i].dy);
    }
    p.close();
    return p;
  }

  static Paint _thinStrokePaint(double width, Color color) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
  }

  /// One filled triangle + optional hairline stroke (single pass each).
  static void _cornerTriangle(
    Canvas canvas,
    Offset c,
    Offset p,
    double unit,
    Color fillColor,
  ) {
    final Offset inward = c - p;
    final double id = inward.distance;
    if (id < 1e-6) {
      return;
    }
    final Offset n = inward / id;
    final Offset perp = Offset(-n.dy, n.dx);
    final double tipIn = 11.0 * unit;
    final double halfBase = 5.2 * unit;
    final double midIn = 3.8 * unit;
    final Offset tip = p + n * tipIn;
    final Offset mid = p + n * midIn;
    final Offset b1 = mid + perp * halfBase;
    final Offset b2 = mid - perp * halfBase;
    final Path t = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..close();
    canvas.drawPath(t, Paint()..color = fillColor);
  }

  static void paintProjectedCell(
    Canvas canvas, {
    required Offset center,
    required List<Offset> outerVertices,
    required double outerRadius,
    required double strokeScale,
    required CellCorePalette palette,
  }) {
    assert(outerVertices.length == 6);
    final List<Offset> iv = <Offset>[
      for (int i = 0; i < 6; i++)
        center + (outerVertices[i] - center) * innerScale
    ];
    final Path outerPath = _pathFromVerts(outerVertices);
    final Path innerPath = _pathFromVerts(iv);
    final Path thickRing =
        Path.combine(PathOperation.difference, outerPath, innerPath);

    canvas.save();
    canvas.clipPath(outerPath);

    canvas.drawPath(innerPath, Paint()..color = palette.innerHexHolePaint);

    canvas.drawPath(thickRing, Paint()..color = palette.ring);

    final double radialFrac = (outerRadius * (1.0 - innerScale) * 0.1 / outerRadius)
        .clamp(0.014, 0.065);
    final double minT = innerScale + 0.018;
    final double w = math.max(1.0, 1.15 * strokeScale);
    for (int k = 0; k < _thinRingCount; k++) {
      final double t = (1.0 - radialFrac * (k + 1)).clamp(minT, 1.0);
      final List<Offset> inset = <Offset>[
        for (int i = 0; i < 6; i++)
          center + (outerVertices[i] - center) * t
      ];
      canvas.drawPath(
        _pathFromVerts(inset),
        _thinStrokePaint(w, palette.highlight),
      );
    }

    final double unit =
        (outerRadius / 56.0 * math.max(0.75, strokeScale)).clamp(0.45, 2.2);
    for (final Offset p in iv) {
      _cornerTriangle(canvas, center, p, unit, palette.highlight);
    }

    canvas.restore();
  }

  static void paintCenteredReference(
    Canvas canvas,
    Size size, {
    required CellCorePalette palette,
  }) {
    final Offset c = HexCellPreviewLayout.center(size);
    final double scale = HexCellPreviewLayout.scale(size);
    final double rThickOuter = HexCellPreviewLayout.outerRadius(size);
    final double rHole = rThickOuter * (42.0 / 56.0);
    final double hh = rThickOuter * 0.8660254;
    final List<Offset> thickOuterVerts = <Offset>[
      c + Offset(rThickOuter, 0),
      c + Offset(rThickOuter * 0.5, hh),
      c + Offset(-rThickOuter * 0.5, hh),
      c + Offset(-rThickOuter, 0),
      c + Offset(-rThickOuter * 0.5, -hh),
      c + Offset(rThickOuter * 0.5, -hh),
    ];
    final List<Offset> holeVerts = <Offset>[
      c + Offset(rHole, 0),
      c + Offset(rHole * 0.5, rHole * 0.8660254),
      c + Offset(-rHole * 0.5, rHole * 0.8660254),
      c + Offset(-rHole, 0),
      c + Offset(-rHole * 0.5, -rHole * 0.8660254),
      c + Offset(rHole * 0.5, -rHole * 0.8660254),
    ];
    final Path thickOuterPath = _pathFromVerts(thickOuterVerts);
    final Path holePath = _pathFromVerts(holeVerts);
    final Path thickRing =
        Path.combine(PathOperation.difference, thickOuterPath, holePath);

    canvas.save();
    canvas.clipPath(thickOuterPath);

    canvas.drawPath(holePath, Paint()..color = palette.innerHexHolePaint);

    canvas.drawPath(thickRing, Paint()..color = palette.ring);

    final double step = 5.5 * scale;
    final double minR = rHole + 6.0 * scale;
    final double strokeW = math.max(1.0, 1.15 * scale);
    for (int k = 0; k < _thinRingCount; k++) {
      final double r = (rThickOuter - step * (k + 1)).clamp(minR, rThickOuter);
      final double h = r * 0.8660254;
      final Path thin = _pathFromVerts(<Offset>[
        c + Offset(r, 0),
        c + Offset(r * 0.5, h),
        c + Offset(-r * 0.5, h),
        c + Offset(-r, 0),
        c + Offset(-r * 0.5, -h),
        c + Offset(r * 0.5, -h),
      ]);
      canvas.drawPath(
        thin,
        _thinStrokePaint(strokeW, palette.highlight),
      );
    }

    for (final Offset p in holeVerts) {
      _cornerTriangle(canvas, c, p, scale, palette.highlight);
    }

    canvas.restore();
  }
}
