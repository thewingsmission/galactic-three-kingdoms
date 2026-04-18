/// Distinguishes the six playable boundary animations (plus [defaultSolid] for
/// non-VFX / neutral defaults).
enum Level4UnitDesign {
  defaultSolid,
  yLose,
  yWin,
  rWin,
  bWin,
  rLose,
  bLose,
}

/// Level 4 boundary war VFX catalog: six variants, stable order for
/// [warAnimationDesignForCell]. Pivot fields in [Level4EffectTune] are 0–1 in
/// texture space with origin at the top-left.
const List<Level4UnitDesign> kLevel4WarAnimationDesigns = <Level4UnitDesign>[
  Level4UnitDesign.yLose,
  Level4UnitDesign.yWin,
  Level4UnitDesign.rWin,
  Level4UnitDesign.rLose,
  Level4UnitDesign.bWin,
  Level4UnitDesign.bLose,
];

/// Tuning parameters for one Level 4 war VFX variant.
class Level4EffectTune {
  const Level4EffectTune({
    this.animScaleX = 1.0,
    this.animScaleY = 1.0,
    this.animPivotX = 0.5,
    this.animPivotY = 0.7,
    this.mascotScale = 1.0,
    this.mascotPivotX = 0.5,
    this.mascotPivotY = 0.75,
  });

  final double animScaleX;
  final double animScaleY;
  final double animPivotX;
  final double animPivotY;
  final double mascotScale;
  final double mascotPivotX;
  final double mascotPivotY;

  /// Shipped defaults per animation id.
  static Level4EffectTune forDesign(Level4UnitDesign design) {
    switch (design) {
      case Level4UnitDesign.rWin:
        return const Level4EffectTune(
          animScaleX: 1.0,
          animScaleY: 1.0,
          animPivotX: 0.537,
          animPivotY: 0.619,
          mascotScale: 1.14,
          mascotPivotX: 0.409,
          mascotPivotY: 0.846,
        );
      case Level4UnitDesign.rLose:
        return const Level4EffectTune(
          animScaleX: 1.21,
          animScaleY: 1.42,
          animPivotX: 0.492,
          animPivotY: 0.73,
          mascotScale: 1.14,
          mascotPivotX: 0.475,
          mascotPivotY: 0.619,
        );
      case Level4UnitDesign.yWin:
        return const Level4EffectTune(
          animScaleX: 1.42,
          animScaleY: 1.21,
          animPivotX: 0.5,
          animPivotY: 0.620,
          mascotScale: 1.19,
          mascotPivotX: 0.566,
          mascotPivotY: 0.895,
        );
      case Level4UnitDesign.yLose:
        return const Level4EffectTune(
          animScaleX: 1.21,
          animScaleY: 1.42,
          animPivotX: 0.492,
          animPivotY: 0.73,
          mascotScale: 1.06,
          mascotPivotX: 0.5,
          mascotPivotY: 0.73,
        );
      case Level4UnitDesign.bWin:
        return const Level4EffectTune(
          animScaleX: 1.0,
          animScaleY: 1.4,
          animPivotX: 0.5,
          animPivotY: 0.578,
          mascotScale: 0.98,
          mascotPivotX: 0.467,
          mascotPivotY: 0.763,
        );
      case Level4UnitDesign.bLose:
        return const Level4EffectTune(
          animScaleX: 1.21,
          animScaleY: 1.42,
          animPivotX: 0.492,
          animPivotY: 0.73,
          mascotScale: 1.12,
          mascotPivotX: 0.5,
          mascotPivotY: 0.619,
        );
      case Level4UnitDesign.defaultSolid:
        return const Level4EffectTune();
    }
  }
}

/// Which of the six animations plays on this cell (stable across frames).
Level4UnitDesign warAnimationDesignForCell(int q, int r) {
  final int hash = ((q * 92821) ^ (r * 68917) ^ 0xA17E) & 0x7fffffff;
  return kLevel4WarAnimationDesigns[hash % kLevel4WarAnimationDesigns.length];
}
