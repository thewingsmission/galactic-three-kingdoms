import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../models/cohort_soldier.dart';
import '../widgets/soldier_contact_painter.dart';
import '../widgets/triangle_soldier.dart';
import 'cohort_kinematics.dart';
import 'orange_field_debris.dart';
import 'soldier_contact_body.dart';

/// **Attack range** radius = contact radius × this (visual + facing / engagement checks).
const double _attackRangeRadiusScale = 3;
/// **Detection range** radius = attack radius × 7 = contact × (3 × 7).
const double _detectionRangeRadiusScale = _attackRangeRadiusScale * 7;

/// War scene: Forge2D leader + per-soldier **contact** circle bodies.
/// [CohortRuntime] drives formation via **forces** toward targets; [localOffset] syncs from bodies.
///
/// **Movement / facing (player + mirrored enemy):**
/// - **Moving** (player: stick ≥6% of throw; enemy: any soldier speed > [_enemyCohortMovingVel]):
///   formation PD toward slots; face earliest enemy in **attack** range by entry time, else face
///   cohort velocity (player: leader vel; enemy: mean soldier vel).
/// - **Not moving**: if **detection** has enemies: face earliest by detection entry time; chase
///   toward that enemy if not in **attack** range (velocity steered to **cohortMaxSpeed** along
///   that bearing—same cap as full-stick cohort move). If in attack range, no formation/chase (hold).
///   If no detection: **formation PD** toward slots (idle holds shape), frozen facing.
class CohortWarGame extends Forge2DGame {
  CohortWarGame({
    required CohortDeployment deployment,
    required this.velocityHud,
  }) : _deployment = deployment,
       super(
         gravity: Vector2.zero(),
         zoom: 1,
       );

  final CohortDeployment _deployment;
  final ValueNotifier<Vector2> velocityHud;

  Vector2 stick = Vector2.zero();

  static const double cohortMaxSpeed = 220;
  static const double steeringGain = 7;
  /// Position gain k in e'' = k·e − c·v_rel (same units as acceleration per unit error).
  static const double soldierFormationGain = 12;
  /// Critically damped PD: **c = 2√k** (ζ = 1). Using **56%** of that.
  static final double soldierFormationVelDamp =
      2 * math.sqrt(soldierFormationGain) * 0.56;
  static const double _stickNeutral = 0.06;
  static const double _velocitySnap2 = 20 * 20;
  /// Ignore flip-detect when nearly still (avoids noise).
  static const double _neutralOppClampMinVel2 = 25;
  /// Enemy cohort treated as "moving" if any soldier speed exceeds this (no joystick).
  static const double _enemyCohortMovingVel = 25;
  static final double _enemyCohortMovingVel2 =
      _enemyCohortMovingVel * _enemyCohortMovingVel;
  /// Aim / velocity magnitude² below this → use cohort aim instead of velocity direction.
  static const double _moveDirEpsilon2 = 4;
  /// Chase steering: drive soldier velocity toward [cohortMaxSpeed] along line to target (stationary cohort).
  static const double _chaseVelocitySteerGain = 8;

  late final CohortLeader leader;
  late final CohortRuntime playerCohort;
  late final List<SoldierContactBody> playerSoldierBodies;
  late final List<Vector2> _soldierVelBefore;
  final Vector2 _leaderVelBefore = Vector2.zero();
  final List<EnemyCohort> enemyCohorts = <EnemyCohort>[];

  double _warTime = 0;
  late List<Map<String, double>> _playerAttackEntry;
  late List<Map<String, double>> _playerDetectionEntry;
  late List<double> _lastPlayerFacing;
  late List<List<Map<String, double>>> _enemyAttackPlayerEntry;
  late List<List<Map<String, double>>> _enemyDetectionPlayerEntry;
  late List<List<double>> _lastEnemySoldierFacing;

  void setStick(Offset normalized) {
    stick.setValues(normalized.dx, normalized.dy);
  }

  int get soldierCount => _deployment.soldiers.length;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Default 10/10: dense circles + formation can leave contacts under-resolved; a bit more solver work.
    velocityIterations = 12;
    positionIterations = 12;

    playerCohort = CohortRuntime.fromDeployment(_deployment);

    final Vector2 start =
        size.x > 0 && size.y > 0 ? size / 2 : Vector2(400, 240);

    _spawnEnemyCohorts(start);

    leader = CohortLeader(start: start);
    await world.add(leader);

    final List<SoldierContactBody> pb = <SoldierContactBody>[];
    for (int i = 0; i < playerCohort.soldierCount; i++) {
      final CohortSoldier s = playerCohort.soldier(i);
      final Vector2 pos = leader.body.position + s.localOffset;
      final SoldierContactBody b = SoldierContactBody(
        contactRadius: s.contact.radius,
        position: pos,
      );
      pb.add(b);
      await world.add(b);
    }
    playerSoldierBodies = pb;
    _soldierVelBefore = List<Vector2>.generate(
      playerSoldierBodies.length,
      (_) => Vector2.zero(),
    );

    _playerAttackEntry = List<Map<String, double>>.generate(
      playerCohort.soldierCount,
      (_) => <String, double>{},
    );
    _playerDetectionEntry = List<Map<String, double>>.generate(
      playerCohort.soldierCount,
      (_) => <String, double>{},
    );
    _lastPlayerFacing = List<double>.generate(
      playerCohort.soldierCount,
      (_) => playerCohort.visualAngle,
    );
    _enemyAttackPlayerEntry = <List<Map<String, double>>>[];
    _enemyDetectionPlayerEntry = <List<Map<String, double>>>[];
    _lastEnemySoldierFacing = <List<double>>[];
    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      final EnemyCohort ec = enemyCohorts[ci];
      ec.cohortIndex = ci;
      final int n = ec.runtime.soldierCount;
      _enemyAttackPlayerEntry.add(
        List<Map<String, double>>.generate(n, (_) => <String, double>{}),
      );
      _enemyDetectionPlayerEntry.add(
        List<Map<String, double>>.generate(n, (_) => <String, double>{}),
      );
      _lastEnemySoldierFacing.add(List<double>.filled(n, 0));
    }

    for (final EnemyCohort e in enemyCohorts) {
      for (int i = 0; i < e.runtime.soldierCount; i++) {
        final CohortSoldier s = e.runtime.soldier(i);
        final Vector2 pos = e.position + s.localOffset;
        final SoldierContactBody b = SoldierContactBody(
          contactRadius: s.contact.radius,
          position: pos,
        );
        e.soldierBodies.add(b);
        await world.add(b);
      }
    }

    await world.add(
      _PlayerSoldierDetectionRangeLayer(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
      ),
    );
    await world.add(
      _PlayerSoldierAttackRangeLayer(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
      ),
    );

    for (final EnemyCohort e in enemyCohorts) {
      await world.add(
        EnemyFormationPainter(
          runtime: e.runtime,
          soldierWorldPosition: (int i) => e.soldierBodies[i].body.position,
          visualAngleForSoldier: (int i) => _enemySoldierRenderAngle(e.cohortIndex, i),
        ),
      );
    }

    await world.add(
      PlayerFormationPainter(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
        visualAngleForSoldier: _playerSoldierRenderAngle,
      ),
    );

    // World updates before camera (lower priority), so [FollowBehavior] sees the leader
    // after Forge2D; infinite maxSpeed keeps the viewfinder locked to the cohort center.
    camera.follow(leader, snap: true, maxSpeed: double.infinity);
  }

  /// Cohort convention: [atan2(dx, -dy)] matches [CohortRuntime] aim / forward `(0,-1)`.
  static double _aimAngleToward(Vector2 delta) {
    return math.atan2(delta.x, -delta.y);
  }

  double _playerSoldierRenderAngle(int i) => _playerSoldierFacingAngle(i);

  double _enemySoldierRenderAngle(int cohortIndex, int soldierIndex) =>
      _enemySoldierFacingAngle(cohortIndex, soldierIndex);

  bool _playerCohortMoving() =>
      stick.length2 > _stickNeutral * _stickNeutral;

  bool _enemyCohortMoving(int cohortIndex) {
    final EnemyCohort e = enemyCohorts[cohortIndex];
    for (int i = 0; i < e.soldierBodies.length; i++) {
      if (e.soldierBodies[i].body.linearVelocity.length2 > _enemyCohortMovingVel2) {
        return true;
      }
    }
    return false;
  }

  Vector2 _enemyWorldPosFromKey(String key) {
    final List<String> p = key.split('-');
    final int ci = int.parse(p[0]);
    final int sj = int.parse(p[1]);
    return enemyCohorts[ci].soldierBodies[sj].body.position;
  }

  Vector2 _playerWorldPosFromKey(String key) {
    final int j = int.parse(key.substring(2));
    return playerSoldierBodies[j].body.position;
  }

  void _updateRangeEntryMaps() {
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      final Vector2 pos = playerSoldierBodies[i].body.position;
      final double cr = playerCohort.soldier(i).contact.radius;
      final double rA = cr * _attackRangeRadiusScale;
      final double rD = cr * _detectionRangeRadiusScale;
      final double rA2 = rA * rA;
      final double rD2 = rD * rD;
      final Set<String> inA = <String>{};
      final Set<String> inD = <String>{};
      for (int ci = 0; ci < enemyCohorts.length; ci++) {
        final EnemyCohort e = enemyCohorts[ci];
        for (int sj = 0; sj < e.runtime.soldierCount; sj++) {
          final Vector2 c = e.soldierBodies[sj].body.position;
          final String k = '$ci-$sj';
          final double d2 = (c - pos).length2;
          if (d2 <= rA2) inA.add(k);
          if (d2 <= rD2) inD.add(k);
        }
      }
      _playerAttackEntry[i].removeWhere((String k, double _) => !inA.contains(k));
      for (final String k in inA) {
        _playerAttackEntry[i].putIfAbsent(k, () => _warTime);
      }
      _playerDetectionEntry[i].removeWhere((String k, double _) => !inD.contains(k));
      for (final String k in inD) {
        _playerDetectionEntry[i].putIfAbsent(k, () => _warTime);
      }
    }

    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      final EnemyCohort e = enemyCohorts[ci];
      for (int si = 0; si < e.runtime.soldierCount; si++) {
        final Vector2 pos = e.soldierBodies[si].body.position;
        final double cr = e.runtime.soldier(si).contact.radius;
        final double rA = cr * _attackRangeRadiusScale;
        final double rD = cr * _detectionRangeRadiusScale;
        final double rA2 = rA * rA;
        final double rD2 = rD * rD;
        final Set<String> inA = <String>{};
        final Set<String> inD = <String>{};
        for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
          final Vector2 c = playerSoldierBodies[pj].body.position;
          final String k = 'p-$pj';
          final double d2 = (c - pos).length2;
          if (d2 <= rA2) inA.add(k);
          if (d2 <= rD2) inD.add(k);
        }
        _enemyAttackPlayerEntry[ci][si]
            .removeWhere((String k, double _) => !inA.contains(k));
        for (final String k in inA) {
          _enemyAttackPlayerEntry[ci][si].putIfAbsent(k, () => _warTime);
        }
        _enemyDetectionPlayerEntry[ci][si]
            .removeWhere((String k, double _) => !inD.contains(k));
        for (final String k in inD) {
          _enemyDetectionPlayerEntry[ci][si].putIfAbsent(k, () => _warTime);
        }
      }
    }
  }

  String? _earliestKeyInSet(Set<String> keys, Map<String, double> times) {
    String? best;
    double? bestT;
    for (final String k in keys) {
      final double? t = times[k];
      if (t == null) continue;
      if (bestT == null || t < bestT) {
        bestT = t;
        best = k;
      }
    }
    return best;
  }

  String? _earliestEnemyInAttackForPlayer(int i) {
    final Vector2 pos = playerSoldierBodies[i].body.position;
    final double cr = playerCohort.soldier(i).contact.radius;
    final double rA = cr * _attackRangeRadiusScale;
    final double rA2 = rA * rA;
    final Set<String> inA = <String>{};
    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      final EnemyCohort e = enemyCohorts[ci];
      for (int sj = 0; sj < e.runtime.soldierCount; sj++) {
        final Vector2 c = e.soldierBodies[sj].body.position;
        if ((c - pos).length2 <= rA2) inA.add('$ci-$sj');
      }
    }
    return _earliestKeyInSet(inA, _playerAttackEntry[i]);
  }

  String? _earliestEnemyInDetectionForPlayer(int i) {
    final Vector2 pos = playerSoldierBodies[i].body.position;
    final double cr = playerCohort.soldier(i).contact.radius;
    final double rD = cr * _detectionRangeRadiusScale;
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      final EnemyCohort e = enemyCohorts[ci];
      for (int sj = 0; sj < e.runtime.soldierCount; sj++) {
        final Vector2 c = e.soldierBodies[sj].body.position;
        if ((c - pos).length2 <= rD2) inD.add('$ci-$sj');
      }
    }
    return _earliestKeyInSet(inD, _playerDetectionEntry[i]);
  }

  bool _enemyCenterInPlayerAttackRange(int playerIndex, String enemyKey) {
    final Vector2 pos = playerSoldierBodies[playerIndex].body.position;
    final double cr = playerCohort.soldier(playerIndex).contact.radius;
    final double rA = cr * _attackRangeRadiusScale;
    final Vector2 c = _enemyWorldPosFromKey(enemyKey);
    return (c - pos).length2 <= rA * rA;
  }

  String? _earliestPlayerInAttackForEnemy(int cohortIndex, int soldierIndex) {
    final EnemyCohort e = enemyCohorts[cohortIndex];
    final Vector2 pos = e.soldierBodies[soldierIndex].body.position;
    final double cr = e.runtime.soldier(soldierIndex).contact.radius;
    final double rA = cr * _attackRangeRadiusScale;
    final double rA2 = rA * rA;
    final Set<String> inA = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      final Vector2 c = playerSoldierBodies[pj].body.position;
      if ((c - pos).length2 <= rA2) inA.add('p-$pj');
    }
    return _earliestKeyInSet(inA, _enemyAttackPlayerEntry[cohortIndex][soldierIndex]);
  }

  String? _earliestPlayerInDetectionForEnemy(int cohortIndex, int soldierIndex) {
    final EnemyCohort e = enemyCohorts[cohortIndex];
    final Vector2 pos = e.soldierBodies[soldierIndex].body.position;
    final double cr = e.runtime.soldier(soldierIndex).contact.radius;
    final double rD = cr * _detectionRangeRadiusScale;
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      final Vector2 c = playerSoldierBodies[pj].body.position;
      if ((c - pos).length2 <= rD2) inD.add('p-$pj');
    }
    return _earliestKeyInSet(inD, _enemyDetectionPlayerEntry[cohortIndex][soldierIndex]);
  }

  bool _playerCenterInEnemyAttackRange(
    int cohortIndex,
    int enemySoldierIndex,
    String playerKey,
  ) {
    final Vector2 pos = enemyCohorts[cohortIndex]
        .soldierBodies[enemySoldierIndex]
        .body
        .position;
    final double cr =
        enemyCohorts[cohortIndex].runtime.soldier(enemySoldierIndex).contact.radius;
    final double rA = cr * _attackRangeRadiusScale;
    final Vector2 c = _playerWorldPosFromKey(playerKey);
    return (c - pos).length2 <= rA * rA;
  }

  double _playerSoldierFacingAngle(int i) {
    final bool moving = _playerCohortMoving();
    final Vector2 p = playerSoldierBodies[i].body.position;
    double angle;

    if (moving) {
      final String? ea = _earliestEnemyInAttackForPlayer(i);
      if (ea != null) {
        final Vector2 d = _enemyWorldPosFromKey(ea) - p;
        angle = d.length2 < 1e-12 ? _lastPlayerFacing[i] : _aimAngleToward(d);
      } else {
        final Vector2 v = leader.body.linearVelocity;
        angle = v.length2 > _moveDirEpsilon2
            ? _aimAngleToward(v)
            : playerCohort.visualAngle;
      }
    } else {
      final String? ed = _earliestEnemyInDetectionForPlayer(i);
      if (ed != null) {
        final Vector2 d = _enemyWorldPosFromKey(ed) - p;
        angle = d.length2 < 1e-12 ? _lastPlayerFacing[i] : _aimAngleToward(d);
      } else {
        angle = _lastPlayerFacing[i];
      }
    }

    if (moving || _earliestEnemyInDetectionForPlayer(i) != null) {
      _lastPlayerFacing[i] = angle;
    }
    return angle;
  }

  double _enemySoldierFacingAngle(int cohortIndex, int soldierIndex) {
    final EnemyCohort e = enemyCohorts[cohortIndex];
    final bool moving = _enemyCohortMoving(cohortIndex);
    final Vector2 p = e.soldierBodies[soldierIndex].body.position;
    final String? pa = _earliestPlayerInAttackForEnemy(cohortIndex, soldierIndex);
    final String? pd = _earliestPlayerInDetectionForEnemy(cohortIndex, soldierIndex);
    double angle;

    // Order matters: [moving] used to win over [detection] while chase speed crossed
    // [_enemyCohortMovingVel], flipping between mean-velocity aim and face-player → flicker.
    // While any player remains in **detection**, keep aiming at that target (stable during approach).
    if (pa != null) {
      final Vector2 d = _playerWorldPosFromKey(pa) - p;
      angle = d.length2 < 1e-12
          ? _lastEnemySoldierFacing[cohortIndex][soldierIndex]
          : _aimAngleToward(d);
    } else if (pd != null) {
      final Vector2 d = _playerWorldPosFromKey(pd) - p;
      angle = d.length2 < 1e-12
          ? _lastEnemySoldierFacing[cohortIndex][soldierIndex]
          : _aimAngleToward(d);
    } else if (moving) {
      Vector2 sum = Vector2.zero();
      int n = 0;
      for (int k = 0; k < e.soldierBodies.length; k++) {
        sum += e.soldierBodies[k].body.linearVelocity;
        n++;
      }
      final Vector2 v = n > 0 ? Vector2(sum.x / n, sum.y / n) : Vector2.zero();
      angle = v.length2 > _moveDirEpsilon2
          ? _aimAngleToward(v)
          : e.runtime.visualAngle;
    } else {
      angle = _lastEnemySoldierFacing[cohortIndex][soldierIndex];
    }

    if (moving || pa != null || pd != null) {
      _lastEnemySoldierFacing[cohortIndex][soldierIndex] = angle;
    }
    return angle;
  }

  /// While cohort is stationary, chase uses velocity steering so |v| → [cohortMaxSpeed] (same as full-stick leader cap).
  void _applyChaseVelocityToward(Body b, Vector2 targetWorldPos) {
    final Vector2 to = targetWorldPos - b.worldCenter;
    if (to.length2 < 1e-10) return;
    final Vector2 dir = to.normalized();
    final Vector2 vWant = dir * cohortMaxSpeed;
    final Vector2 err = vWant - b.linearVelocity;
    b.applyForce(err * b.mass * _chaseVelocitySteerGain);
  }

  void _applyChaseForces() {
    if (!_playerCohortMoving()) {
      for (int i = 0; i < playerSoldierBodies.length; i++) {
        final String? ed = _earliestEnemyInDetectionForPlayer(i);
        if (ed == null) continue;
        if (_enemyCenterInPlayerAttackRange(i, ed)) continue;
        final Body b = playerSoldierBodies[i].body;
        _applyChaseVelocityToward(b, _enemyWorldPosFromKey(ed));
      }
    }

    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      if (_enemyCohortMoving(ci)) continue;
      final EnemyCohort e = enemyCohorts[ci];
      for (int si = 0; si < e.soldierBodies.length; si++) {
        final String? pd = _earliestPlayerInDetectionForEnemy(ci, si);
        if (pd == null) continue;
        if (_playerCenterInEnemyAttackRange(ci, si, pd)) continue;
        final Body b = e.soldierBodies[si].body;
        _applyChaseVelocityToward(b, _playerWorldPosFromKey(pd));
      }
    }
  }

  void _spawnEnemyCohorts(Vector2 center) {
    final math.Random rng = math.Random(21);
    final List<List<Vector2>> patterns = <List<Vector2>>[
      <Vector2>[
        Vector2(0, -36),
        Vector2(-32, 28),
        Vector2(32, 28),
      ],
      <Vector2>[
        Vector2(0, -40),
        Vector2(-44, 20),
        Vector2(44, 20),
        Vector2(0, 32),
      ],
      <Vector2>[
        Vector2(-50, -10),
        Vector2(0, -38),
        Vector2(50, -10),
        Vector2(-28, 36),
        Vector2(28, 36),
      ],
    ];

    for (int i = 0; i < 3; i++) {
      final Vector2 offset = Vector2(
        (rng.nextDouble() - 0.5) * 900,
        (rng.nextDouble() - 0.5) * 700,
      );
      enemyCohorts.add(
        EnemyCohort(
          position: center + offset,
          runtime: CohortRuntime.withSlots(patterns[i % patterns.length]),
        ),
      );
    }
  }

  void _steer() {
    final Vector2 v = leader.body.linearVelocity;
    if (stick.length2 <= _stickNeutral * _stickNeutral) {
      if (v.length2 <= _velocitySnap2) {
        leader.body.linearVelocity.setZero();
        return;
      }
    }
    final Vector2 target = stick * cohortMaxSpeed;
    final Vector2 err = target - v;
    leader.body.applyForce(err * leader.body.mass * steeringGain);
  }

  void _applySoldierFormationForces() {
    final Vector2 lc = leader.body.position;
    final Vector2 vLeader = leader.body.linearVelocity;
    final double c = soldierFormationVelDamp;

    // Player: formation whenever moving, or idle with no detection engagement (settle to slots).
    // Skip per soldier while idle+detection (chase / hold replaces formation for that soldier).
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      if (!_playerCohortMoving() &&
          _earliestEnemyInDetectionForPlayer(i) != null) {
        continue;
      }
      final Body b = playerSoldierBodies[i].body;
      final Vector2 target = lc + playerCohort.formationTargetLocal(i);
      final Vector2 err = target - b.worldCenter;
      final Vector2 relVel = b.linearVelocity - vLeader;
      final Vector2 accel = err * soldierFormationGain - relVel * c;
      b.applyForce(accel * b.mass);
    }
    for (int ci = 0; ci < enemyCohorts.length; ci++) {
      if (!_enemyCohortMoving(ci)) continue;
      final EnemyCohort e = enemyCohorts[ci];
      for (int i = 0; i < e.soldierBodies.length; i++) {
        final Body b = e.soldierBodies[i].body;
        final Vector2 target = e.position + e.runtime.formationTargetLocal(i);
        final Vector2 err = target - b.worldCenter;
        final Vector2 v = b.linearVelocity;
        final Vector2 accel = err * soldierFormationGain - v * c;
        b.applyForce(accel * b.mass);
      }
    }
  }

  void _syncSoldierOffsetsFromBodies() {
    final Vector2 lc = leader.body.position;
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      playerCohort.soldier(i).localOffset =
          playerSoldierBodies[i].body.position - lc;
    }
    for (final EnemyCohort e in enemyCohorts) {
      for (int i = 0; i < e.soldierBodies.length; i++) {
        e.runtime.soldier(i).localOffset =
            e.soldierBodies[i].body.position - e.position;
      }
    }
  }

  void _snapshotVelocitiesBeforeStep() {
    _leaderVelBefore.setFrom(leader.body.linearVelocity);
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      _soldierVelBefore[i].setFrom(playerSoldierBodies[i].body.linearVelocity);
    }
  }

  /// With stick neutral, spring/damping can overshoot and briefly reverse velocity;
  /// zero it when the new velocity opposes the previous step's direction.
  void _neutralClampOppositeVelocities() {
    if (stick.length2 > _stickNeutral * _stickNeutral) return;

    void clampIfFlipped(Body body, Vector2 velBefore) {
      if (velBefore.length2 <= _neutralOppClampMinVel2) return;
      final Vector2 v = body.linearVelocity;
      if (v.dot(velBefore) < 0) {
        body.linearVelocity.setZero();
      }
    }

    clampIfFlipped(leader.body, _leaderVelBefore);
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      clampIfFlipped(playerSoldierBodies[i].body, _soldierVelBefore[i]);
    }
  }

  @override
  void update(double dt) {
    _snapshotVelocitiesBeforeStep();
    _steer();
    playerCohort.update(dt, stick, integratePositions: false);
    for (final EnemyCohort e in enemyCohorts) {
      e.runtime.update(dt, Vector2.zero(), integratePositions: false);
    }
    _warTime += dt;
    _updateRangeEntryMaps();
    _applySoldierFormationForces();
    _applyChaseForces();
    super.update(dt);

    _neutralClampOppositeVelocities();

    _syncSoldierOffsetsFromBodies();

    final Vector2 v = leader.body.linearVelocity;
    velocityHud.value = Vector2(v.x, v.y);
  }
}

class EnemyCohort {
  EnemyCohort({
    required this.position,
    required this.runtime,
  });

  Vector2 position;
  final CohortRuntime runtime;
  /// Index in [CohortWarGame.enemyCohorts] (set in [CohortWarGame.onLoad]).
  int cohortIndex = 0;
  final List<SoldierContactBody> soldierBodies = <SoldierContactBody>[];
}

/// Solid **detection** disk (lowest render layer among range visuals).
class _PlayerSoldierDetectionRangeLayer extends Component {
  _PlayerSoldierDetectionRangeLayer({
    required this.runtime,
    required this.soldierWorldPosition,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;

  static final Paint _fill = Paint()..color = const Color(0xFFBBDEFB);

  @override
  int get priority => -1001;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final double r = s.contact.radius * _detectionRangeRadiusScale;
      final Vector2 p = soldierWorldPosition(i);
      canvas.drawCircle(Offset(p.x, p.y), r, _fill);
    }
  }
}

/// Solid **attack** disk; one priority step above [_PlayerSoldierDetectionRangeLayer].
class _PlayerSoldierAttackRangeLayer extends Component {
  _PlayerSoldierAttackRangeLayer({
    required this.runtime,
    required this.soldierWorldPosition,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;

  static final Paint _fill = Paint()..color = const Color(0xFFC8E6C9);

  @override
  int get priority => -1000;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final double r = s.contact.radius * _attackRangeRadiusScale;
      final Vector2 p = soldierWorldPosition(i);
      canvas.drawCircle(Offset(p.x, p.y), r, _fill);
    }
  }
}

class CohortLeader extends BodyComponent<CohortWarGame> {
  CohortLeader({required Vector2 start})
    : super(
        renderBody: false,
        bodyDef: BodyDef(
          type: BodyType.dynamic,
          position: start,
          linearDamping: 5.2,
          angularDamping: 0.9,
          fixedRotation: true,
        ),
        fixtureDefs: <FixtureDef>[
          FixtureDef(
            CircleShape()..radius = 2.8,
            density: 1.2,
            friction: 0.2,
            filter: Filter()
              ..categoryBits = 0x0001
              ..maskBits = 0x0000,
          ),
        ],
      );
}

class PlayerFormationPainter extends Component {
  PlayerFormationPainter({
    required this.runtime,
    required this.soldierWorldPosition,
    required this.visualAngleForSoldier,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;

  @override
  int get priority => 20;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final SoldierModel m = s.model;
      final SoldierContact sc = s.contact;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.translate(-half, -half);
      TriangleSoldierPainter(side: m.side).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      SoldierContactPainter(radius: sc.radius, strokeWidth: 2.5).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      canvas.restore();
    }
  }
}

class EnemyFormationPainter extends Component {
  EnemyFormationPainter({
    required this.runtime,
    required this.soldierWorldPosition,
    required this.visualAngleForSoldier,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;

  @override
  int get priority => 5;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final SoldierModel m = s.model;
      final SoldierContact sc = s.contact;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.translate(-half, -half);
      OrangeTrianglePainter(side: m.side).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      SoldierContactPainter(radius: sc.radius, strokeWidth: 2).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      canvas.restore();
    }
  }
}
