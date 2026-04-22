/// Strategic-map hex paint variant (territory strength → **L1…L4** via [hexCellStyleForStrengthLevel]).
enum HexCellPreviewStyle {
  /// Faction-colored ring (original map look).
  defaultStyle,

  /// L1: same geometry as default; thick ring + inner from faction ramp index **1**.
  l1,

  /// L2: two-ring layout; fixed faction accent; **no** corner parallelograms.
  l2,

  /// L3: same rings + accent as **L2**, plus only three corner parallelograms.
  l3,

  /// L4: previous **L3** look with six corner parallelograms.
  l4,

  /// A1: gold rim, echoes, inner corner triangles ([A1HexCellPaint]).
  a1,

  /// A2: fills **#1,#3,#1** ↔ **#3,#1,#3** every 0.45s (black strokes on ring edges).
  a2,
}

extension HexCellPreviewStylePaint on HexCellPreviewStyle {
  /// A1, A2, L2–L4 use [HexCellStylesPaint.paintProjectedCell]; L1 uses default mesh fill (index **1**).
  bool get usesVariantPaint =>
      this == HexCellPreviewStyle.a1 ||
      this == HexCellPreviewStyle.a2 ||
      this == HexCellPreviewStyle.l2 ||
      this == HexCellPreviewStyle.l3 ||
      this == HexCellPreviewStyle.l4;
}

/// Territory strength level **1…4** → **L1…L4** cell art (strategic map).
HexCellPreviewStyle hexCellStyleForStrengthLevel(int strengthLevel) {
  return switch (strengthLevel) {
    1 => HexCellPreviewStyle.l1,
    2 => HexCellPreviewStyle.l2,
    3 => HexCellPreviewStyle.l3,
    _ => HexCellPreviewStyle.l4,
  };
}
