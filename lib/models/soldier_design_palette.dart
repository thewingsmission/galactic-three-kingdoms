import 'package:flutter/material.dart';

/// Three preview / production options; each [SoldierShapePart] uses the same **tier index**
/// with [kRedFactionComponentColors] / yellow / blue (see soldier_faction_color_theme.dart).
enum SoldierDesignPalette {
  red,
  yellow,
  blue,
}

extension SoldierDesignPaletteX on SoldierDesignPalette {
  /// Accent for attack beams / UI that should follow the palette.
  Color get attackAccent => switch (this) {
        SoldierDesignPalette.red => const Color(0xFFE53935),
        SoldierDesignPalette.yellow => const Color(0xFFFFC107),
        SoldierDesignPalette.blue => const Color(0xFF42A5F5),
      };

  /// Crown flame VFX: bright core, mid body, deep ember ([MultiPolygonSoldierPainter]).
  ({Color bright, Color mid, Color deep}) get crownFlameColors =>
      switch (this) {
        SoldierDesignPalette.red => (
            bright: const Color(0xFFFF7043),
            mid: const Color(0xFFFFAB91),
            deep: const Color(0xFFC62828),
          ),
        SoldierDesignPalette.yellow => (
            bright: const Color(0xFFFFF176),
            mid: const Color(0xFFFFD54F),
            deep: const Color(0xFFE65100),
          ),
        SoldierDesignPalette.blue => (
            bright: const Color(0xFF84FFFF),
            mid: const Color(0xFF4FC3F7),
            deep: const Color(0xFF1565C0),
          ),
      };

  /// Electric shadow footprint + chrome rim on the strategic map (per territory color).
  ({
    Color spark,
    Color sparkCore,
    Color zig,
    Color halo,
    Color glow,
    Color rim,
    Color chromeBloom,
    Color chromeMid,
    Color chromeHot,
    Color chromeSpecularTint,
  }) get shadowFootprintElectricColors => switch (this) {
        SoldierDesignPalette.red => (
            spark: const Color(0xFFFF6B7A),
            sparkCore: const Color(0xFFFFE8EC),
            zig: const Color(0xFFFFA8B4),
            halo: const Color(0xFFFF3D4D),
            glow: const Color(0xFFFF8A95),
            rim: const Color(0xFFFFF5F6),
            chromeBloom: const Color(0xFFFF5C6B),
            chromeMid: const Color(0xFFFFB3BC),
            chromeHot: const Color(0xFFFFF0F1),
            chromeSpecularTint: const Color(0xFFFFB8C3),
          ),
        SoldierDesignPalette.yellow => (
            spark: const Color(0xFFFFD54F),
            sparkCore: const Color(0xFFFFFDE7),
            zig: const Color(0xFFFFECB3),
            halo: const Color(0xFFFFB300),
            glow: const Color(0xFFFFE082),
            rim: const Color(0xFFFFFBF0),
            chromeBloom: const Color(0xFFFFD740),
            chromeMid: const Color(0xFFFFF59D),
            chromeHot: const Color(0xFFFFFBF5),
            chromeSpecularTint: const Color(0xFFFFF9C4),
          ),
        SoldierDesignPalette.blue => (
            spark: const Color(0xFF7CD8FF),
            sparkCore: const Color(0xFFE8FBFF),
            zig: const Color(0xFFB0EAFF),
            halo: const Color(0xFF4AB0FF),
            glow: const Color(0xFF9FD8FF),
            rim: const Color(0xFFF5FDFF),
            chromeBloom: const Color(0xFF5AD4FF),
            chromeMid: const Color(0xFFB8F8FF),
            chromeHot: const Color(0xFFF2FFFF),
            chromeSpecularTint: const Color(0xFFB8FFFF),
          ),
      };
}
