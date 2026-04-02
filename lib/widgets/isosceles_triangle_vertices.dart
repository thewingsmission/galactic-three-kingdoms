import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Default short-base / long-leg ratio (leg 1 → base 0.8).
const double kIsoscelesBaseToLegRatio = 0.8;

/// Short side (base) length for the isosceles triangle with long sides [legLength].
double isoscelesShortSideLength(
  double legLength, {
  double baseToLegRatio = kIsoscelesBaseToLegRatio,
}) {
  return legLength * baseToLegRatio.clamp(0.12, 0.95);
}

/// Isosceles triangle in local space: **short base** horizontal at the bottom,
/// **apex** (pointy angle) toward **negative Y** (up on screen). Centroid at `(0,0)`.
///
/// [legLength] is the length of the two equal long sides. Base length is
/// [baseToLegRatio] × [legLength] (default **0.8**: leg 1 → base 0.8).
List<Offset> isoscelesTriangleVerticesCentroid({
  required double legLength,
  double baseToLegRatio = kIsoscelesBaseToLegRatio,
}) {
  final double base = isoscelesShortSideLength(legLength, baseToLegRatio: baseToLegRatio);
  final double halfB = base / 2;
  final double hSq = legLength * legLength - halfB * halfB;
  final double h = hSq > 1e-6 ? math.sqrt(hSq) : legLength * 0.55;

  return <Offset>[
    Offset(0, -2 * h / 3),
    Offset(-halfB, h / 3),
    Offset(halfB, h / 3),
  ];
}
