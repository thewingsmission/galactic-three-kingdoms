import 'package:flutter/material.dart';

import 'core_color_theme.dart';
import 'soldier_design_palette.dart';
import 'soldier_faction_color_theme.dart';

/// Fills and strokes for hex cell **art** (not the green debug outline).
@immutable
class CellCorePalette {
  const CellCorePalette({
    required this.ring,
    required this.ringDeep,
    required this.highlight,
    required this.accent,
    required this.panel,
    required this.stroke,
    required this.componentIndex1,
    required this.componentIndex3,
  });

  /// Primary band / body.
  final Color ring;

  /// Shadows, notches, dark facets.
  final Color ringDeep;

  /// Bright rims, “silver”, inner double lines.
  final Color highlight;

  /// Secondary accent (cyan-line role in blue-forward designs).
  final Color accent;

  /// Dark frame interiors.
  final Color panel;

  /// Outer cell stroke (default style).
  final Color stroke;

  /// [factionTierList] index **1** (second tone); A2 outer ring, shared inner hole default.
  final Color componentIndex1;

  /// [factionTierList] index **3** (fourth tone); A2 inner theme ring, A3 body.
  final Color componentIndex3;

  /// Inner hex hole: `lerp([base], #02040A, 0.45)` @ α 0.1 (default [base] = [componentIndex1]).
  Color innerHexHolePaintFrom(Color base) => Color.lerp(
    base,
    const Color(0xFF02040A),
    0.45,
  )!.withValues(alpha: (1 - innerHexHoleTransparency).clamp(0.0, 1.0));

  Color get innerHexHolePaint => innerHexHolePaintFrom(componentIndex1);

  /// Same as preview / map `_fixedInnerTransparency` (visible α = 0.1).
  static const double innerHexHoleTransparency = 0.9;

  /// Per-hex colors matching **default** territory fill: faction + strength tier
  /// (same mapping as strategic map `_territoryPalette`).
  factory CellCorePalette.fromTerritoryField({
    required SoldierDesignPalette faction,
    required int strengthLevel,
  }) {
    int tierForLevel(int level) {
      return switch (level) {
        5 => 1,
        4 => 1,
        3 => 2,
        2 => 3,
        _ => 4,
      };
    }

    final int tier = tierForLevel(strengthLevel);
    final List<Color> list = factionTierList(faction);
    final int i = tier - 1;
    return CellCorePalette(
      ring: list[i],
      ringDeep: list[(i - 1).clamp(0, 4)],
      highlight: list[(i + 1).clamp(0, 4)],
      accent: list[(i + 1).clamp(0, 4)],
      panel: Color.lerp(list[i], const Color(0xFF02040A), 0.45)!,
      stroke: Colors.black.withValues(alpha: 0.72),
      componentIndex1: list[1],
      componentIndex3: list[3],
    );
  }
}

extension CoreColorThemeCellPalette on CoreColorTheme {
  CellCorePalette get cellPalette {
    final List<Color> tier = switch (this) {
      CoreColorTheme.red => kRedFactionComponentColors,
      CoreColorTheme.yellow => kYellowFactionComponentColors,
      CoreColorTheme.blue => kBlueFactionComponentColors,
    };
    return CellCorePalette(
      ring: tier[2],
      ringDeep: tier[0],
      highlight: tier[4],
      accent: tier[3],
      panel: Color.lerp(tier[0], const Color(0xFF02040A), 0.55)!,
      stroke: Colors.black.withValues(alpha: 0.72),
      componentIndex1: tier[1],
      componentIndex3: tier[3],
    );
  }
}
