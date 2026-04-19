import 'package:flutter/material.dart';

import 'soldier_faction_color_theme.dart';

/// One of three strategic UI color cores (aligned with faction ramps).
enum CoreColorTheme {
  red,
  yellow,
  blue,
}

extension CoreColorThemeSpec on CoreColorTheme {
  /// Strong accent (tier-3 aligned); used by [HexCellDemoPanel] only.
  Color get accent => switch (this) {
        CoreColorTheme.red => kRedFactionComponentColors[2],
        CoreColorTheme.yellow => kYellowFactionComponentColors[2],
        CoreColorTheme.blue => kBlueFactionComponentColors[2],
      };

  /// Right-hand preview column base (near-black + hue).
  Color get previewPanelBase => switch (this) {
        CoreColorTheme.red => const Color(0xFF12080A),
        CoreColorTheme.yellow => const Color(0xFF100E06),
        CoreColorTheme.blue => const Color(0xFF060A12),
      };

  String get shortLabel => switch (this) {
        CoreColorTheme.red => 'Red',
        CoreColorTheme.yellow => 'Yellow',
        CoreColorTheme.blue => 'Blue',
      };
}
