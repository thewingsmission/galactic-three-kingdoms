/// Visual style for hex cells on the strategic map and the black preview panel.
enum HexCellPreviewStyle {
  /// Faction-colored ring (original map look).
  defaultStyle,

  /// L1: same geometry as default; thick ring + inner from faction ramp index **1**.
  l1,

  /// L2: two-ring layout; fixed faction accent (red / yellow / blue); inner band blinks on a **1.4s** cycle (then matches **L1**); sixfold corner parallelograms.
  l2,

  /// A1: gold rim, echoes, inner corner triangles ([A1HexCellPaint]).
  a1,

  /// A2: fills **#1,#3,#1** ↔ **#3,#1,#3** every 0.45s (black strokes on ring edges).
  a2,
}

extension HexCellPreviewStyleLabel on HexCellPreviewStyle {
  String get label => switch (this) {
        HexCellPreviewStyle.defaultStyle => 'Default',
        HexCellPreviewStyle.l1 => 'L1',
        HexCellPreviewStyle.l2 => 'L2',
        HexCellPreviewStyle.a1 => 'A1',
        HexCellPreviewStyle.a2 => 'A2',
      };
}

extension HexCellPreviewStylePaint on HexCellPreviewStyle {
  /// A1, A2, L2 use [HexCellStylesPaint.paintProjectedCell]; L1 uses default mesh fill (index **1**).
  bool get usesVariantPaint =>
      this == HexCellPreviewStyle.a1 ||
      this == HexCellPreviewStyle.a2 ||
      this == HexCellPreviewStyle.l2;
}
