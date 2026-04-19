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

  /// Map / perspective: triangle size tracks **screen-space** outer radius only (preview: `scale ≈ r/56`).
  /// Vertices are already perspective-correct in pixels; do not multiply by [strokeScale] or use a
  /// high floor — that kept distant triangles disproportionately large.
  static double cornerTriangleUnitForMap(double outerRadius) =>
      (outerRadius / 56.0).clamp(0.04, 12.0);

  /// Six triangles at the vertices of the inner hex ([innerHexVertices]).
  ///
  /// Inward direction at each vertex is the **interior angle bisector** of the inner hex (from the
  /// two meeting edges). This matches the preview (regular hex) and stays correct on the
  /// perspective map — using `projectedCenter - vertex` is wrong when the tile center is not the
  /// visual centroid in screen space.
  static void paintInnerCornerTriangles(
    Canvas canvas,
    List<Offset> innerHexVertices,
    double unit,
    Color fillColor,
  ) {
    assert(innerHexVertices.length == 6);
    final Offset centroid = _hexCentroid(innerHexVertices);
    for (int i = 0; i < 6; i++) {
      final Offset? n = _innerHexInwardUnit(innerHexVertices, i, centroid);
      if (n == null) {
        continue;
      }
      _cornerTriangleWithInward(canvas, innerHexVertices[i], n, unit, fillColor);
    }
  }

  static Offset _hexCentroid(List<Offset> v) {
    double sx = 0, sy = 0;
    for (final Offset p in v) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / v.length, sy / v.length);
  }

  /// Unit vector from inner vertex [i] toward hex interior (bisector of edges to i−1 and i+1).
  static Offset? _innerHexInwardUnit(
    List<Offset> v,
    int i,
    Offset centroid,
  ) {
    final Offset p = v[i];
    final Offset pIm = v[(i + 5) % 6];
    final Offset pIp = v[(i + 1) % 6];
    final Offset u1 = pIm - p;
    final Offset u2 = pIp - p;
    final double d1 = u1.distance;
    final double d2 = u2.distance;
    if (d1 < 1e-10 || d2 < 1e-10) {
      return null;
    }
    final Offset e1 = u1 / d1;
    final Offset e2 = u2 / d2;
    Offset bis = Offset(e1.dx + e2.dx, e1.dy + e2.dy);
    final double bl = bis.distance;
    if (bl < 1e-10) {
      return null;
    }
    bis = bis / bl;
    final Offset towardC = centroid - p;
    if (towardC.distance > 1e-10 &&
        bis.dx * towardC.dx + bis.dy * towardC.dy < 0) {
      bis = Offset(-bis.dx, -bis.dy);
    }
    return bis;
  }

  /// One filled triangle; [inwardUnit] points from [p] toward the cell interior.
  static void _cornerTriangleWithInward(
    Canvas canvas,
    Offset p,
    Offset inwardUnit,
    double unit,
    Color fillColor,
  ) {
    if (inwardUnit.distance < 1e-6) {
      return;
    }
    final Offset n = inwardUnit;
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

    final double unit = cornerTriangleUnitForMap(outerRadius);
    paintInnerCornerTriangles(canvas, iv, unit, palette.highlight);

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

    paintInnerCornerTriangles(canvas, holeVerts, scale, palette.highlight);

    canvas.restore();
  }
}
