import 'package:flutter/material.dart';

/// Single soldier type for the warm-up.
enum SoldierType { triangle }

/// One deployed unit with formation offset in cohort space (screen coords: +x right, +y down).
/// Default cohort forward is `(0, -1)` (up on screen); rotation is applied around cohort center.
class PlacedSoldier {
  PlacedSoldier({
    required this.inventoryIndex,
    required this.type,
    required this.localOffset,
  });

  final int inventoryIndex;
  final SoldierType type;
  Offset localOffset;

  PlacedSoldier copyWith({Offset? localOffset}) {
    return PlacedSoldier(
      inventoryIndex: inventoryIndex,
      type: type,
      localOffset: localOffset ?? this.localOffset,
    );
  }
}

/// Snapshot passed into the war scene.
class CohortDeployment {
  CohortDeployment({required this.soldiers});

  final List<PlacedSoldier> soldiers;

  CohortDeployment copy() {
    return CohortDeployment(
      soldiers: soldiers
          .map((PlacedSoldier s) => s.copyWith(localOffset: s.localOffset))
          .toList(),
    );
  }
}
