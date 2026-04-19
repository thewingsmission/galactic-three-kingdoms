import 'package:flutter/material.dart';

import 'soldier_faction_color_theme.dart';

/// One of three strategic UI color cores (aligned with faction ramps).
enum CoreColorTheme {
  red,
  yellow,
  blue,
}

extension CoreColorThemeSpec on CoreColorTheme {
  /// Strong accent (tier-3 aligned).
  Color get accent => switch (this) {
        CoreColorTheme.red => kRedFactionComponentColors[2],
        CoreColorTheme.yellow => kYellowFactionComponentColors[2],
        CoreColorTheme.blue => kBlueFactionComponentColors[2],
      };
}
