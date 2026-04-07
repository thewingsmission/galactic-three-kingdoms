import 'package:flutter/material.dart';

/// Rarity reflects **structural / visual complexity** (parts, weapon detail), not polygon count alone.
enum SoldierRarity {
  common(1, 'Common'),
  rare(2, 'Rare'),
  epic(3, 'Epic'),
  legendary(4, 'Legendary');

  const SoldierRarity(this.structureTier, this.label);

  /// Rough tier 1–4 for UI (chips, power hooks).
  final int structureTier;
  final String label;

  int get powerTier => index + 1;

  Color get accentColor => switch (this) {
        SoldierRarity.common => const Color(0xFF66BB6A),
        SoldierRarity.rare => const Color(0xFF42A5F5),
        SoldierRarity.epic => const Color(0xFFAB47BC),
        SoldierRarity.legendary => const Color(0xFFFFCA28),
      };

  /// Legacy helper when only "part count" is available (procedural filler).
  static SoldierRarity fromPartCount(int n) {
    if (n <= 3) return SoldierRarity.common;
    if (n <= 6) return SoldierRarity.rare;
    if (n <= 9) return SoldierRarity.epic;
    return SoldierRarity.legendary;
  }
}
