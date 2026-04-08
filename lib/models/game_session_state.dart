import 'package:flutter/material.dart';

import '../widgets/soldier_design_catalog.dart';
import 'cohort_models.dart';
import 'soldier_design.dart';
import 'soldier_design_palette.dart';

/// Persistent app session data that survives screen changes.
///
/// Only lightweight cohort configuration lives here so screens themselves can
/// be popped and disposed without losing the player's formation setup.
class GameSessionState {
  static const int inventorySize = 44;

  static final List<SoldierDesign> roster = List<SoldierDesign>.unmodifiable(
    <SoldierDesign>[
      for (int i = 0; i < 10; i++) kProductionSoldierDesignCatalog[1],
      for (int i = 0; i < 10; i++) kProductionSoldierDesignCatalog[0],
      for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[3],
      for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[4],
      for (int i = 0; i < 8; i++) kProductionSoldierDesignCatalog[5],
    ],
  );

  SoldierDesignPalette palette = SoldierDesignPalette.yellow;
  List<bool> selected = List<bool>.filled(inventorySize, false);
  Map<int, Offset> offsets = <int, Offset>{};
  int? cohortLeaderIndex;

  void saveInventoryState({
    required SoldierDesignPalette palette,
    required List<bool> selected,
    required Map<int, Offset> offsets,
    required int? cohortLeaderIndex,
  }) {
    this.palette = palette;
    this.selected = List<bool>.from(selected);
    this.offsets = Map<int, Offset>.from(offsets);
    this.cohortLeaderIndex = cohortLeaderIndex;
  }

  int get selectedCount => selected.where((bool value) => value).length;

  CohortDeployment buildDeployment() {
    final List<PlacedSoldier> soldiers = <PlacedSoldier>[];
    final int? leader = cohortLeaderIndex;

    if (leader != null && leader >= 0 && leader < inventorySize && selected[leader]) {
      soldiers.add(
        PlacedSoldier(
          inventoryIndex: leader,
          type: SoldierType.triangle,
          localOffset: offsets[leader] ?? Offset.zero,
          soldierDesign: roster[leader],
          cohortPalette: palette,
        ),
      );
    }

    for (int i = 0; i < inventorySize; i++) {
      if (!selected[i] || i == leader) continue;
      soldiers.add(
        PlacedSoldier(
          inventoryIndex: i,
          type: SoldierType.triangle,
          localOffset: offsets[i] ?? Offset.zero,
          soldierDesign: roster[i],
          cohortPalette: palette,
        ),
      );
    }

    return CohortDeployment(soldiers: soldiers);
  }
}
