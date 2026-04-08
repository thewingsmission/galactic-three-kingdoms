import 'dart:math' as math;

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:galactic_three_kingdoms_epic_saga/game/cohort_kinematics.dart';
import 'package:galactic_three_kingdoms_epic_saga/models/cohort_models.dart';

void main() {
  group('cohort from deployment', () {
    test('canonical slot matches PlacedSoldier.localOffset (e.g. center = 0,0)', () {
      final CohortDeployment d = CohortDeployment(
        soldiers: <PlacedSoldier>[
          PlacedSoldier(
            inventoryIndex: 0,
            type: SoldierType.triangle,
            localOffset: Offset.zero,
          ),
        ],
      );
      final CohortRuntime rt = CohortRuntime.fromDeployment(d);
      expect(rt.soldierCount, 1);
      expect(rt.soldier(0).canonicalSlot, Vector2.zero());
    });

    test(
        'forward slot (0,-r): aim right → visualAngle π/2; target (r,0); lerp not teleport',
        () {
      final CohortDeployment d = CohortDeployment(
        soldiers: <PlacedSoldier>[
          PlacedSoldier(
            inventoryIndex: 0,
            type: SoldierType.triangle,
            localOffset: Offset(0, -kCohortFormationRadius),
          ),
        ],
      );
      final CohortRuntime rt = CohortRuntime.fromDeployment(d);
      const double dt = 1 / 60;
      rt.update(dt, Vector2(1, 0));

      expect(rt.visualAngle, closeTo(math.pi / 2, 1e-6));

      final Vector2 target = Vector2(kCohortFormationRadius, 0);
      expect(
        rt.soldier(0).localOffset.distanceTo(target) > 10,
        isTrue,
        reason: 'soldier should not teleport to target in one frame',
      );

      for (int i = 0; i < 600; i++) {
        rt.update(dt, Vector2(1, 0));
      }
      expect(rt.soldier(0).localOffset.x, closeTo(kCohortFormationRadius, 0.5));
      expect(rt.soldier(0).localOffset.y, closeTo(0, 0.5));
    });
  });
}
