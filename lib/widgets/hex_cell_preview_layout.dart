import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared pointy-top hex geometry for strategic-map cells and outline painting
/// (56 px radius at 150 px reference extent).
class HexCellPreviewLayout {
  HexCellPreviewLayout._();

  static const double referenceExtent = 150.0;
  static const double outerRadiusRef = 56.0;

  static double scale(Size size) =>
      math.min(size.width, size.height) / referenceExtent;

  static double outerRadius(Size size) => outerRadiusRef * scale(size);

  static Offset center(Size size) => Offset(size.width * 0.5, size.height * 0.5);

  /// Pointy-top hex vertices (matches [A1HexCellPaint] / map projection).
  static List<Offset> pointyTopVerts(Offset c, double r) {
    final double hh = r * 0.8660254037844386;
    return <Offset>[
      c + Offset(r, 0),
      c + Offset(r * 0.5, hh),
      c + Offset(-r * 0.5, hh),
      c + Offset(-r, 0),
      c + Offset(-r * 0.5, -hh),
      c + Offset(r * 0.5, -hh),
    ];
  }

  static Path pathFromVerts(List<Offset> v) {
    final Path p = Path()..moveTo(v[0].dx, v[0].dy);
    for (int i = 1; i < 6; i++) {
      p.lineTo(v[i].dx, v[i].dy);
    }
    p.close();
    return p;
  }

  /// Same outer rim as strategic-map default hexes: black ~72% opacity, width scales with perspective.
  static const double unifiedOutlineBlackAlpha = 0.72;

  static double unifiedOutlineStrokeWidth(double strokeScale) =>
      math.max(0.9, 2.0 * strokeScale);

  static void paintUnifiedHexOutline(
    Canvas canvas,
    Path outerPath,
    double strokeScale,
  ) {
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = Colors.black.withValues(alpha: unifiedOutlineBlackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unifiedOutlineStrokeWidth(strokeScale),
    );
  }
}
