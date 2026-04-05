import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/rendering.dart';

/// Forge2D body using the design's **contact polygon** (trapezoid, etc.) for collision.
/// Falls back to a circle for soldiers without a polygon (plain triangles).
///
/// Uses category **0x0002** and mask **0xFFFE** so it does **not** collide with the cohort leader (0x0001).
/// **Friction** is kept low; **restitution** small but non-zero so contacts separate cleanly.
class SoldierContactBody extends BodyComponent<Forge2DGame> {
  SoldierContactBody._({
    required Vector2 position,
    required Shape contactShape,
  }) : super(
         renderBody: false,
         bodyDef: BodyDef(
           type: BodyType.dynamic,
           position: position,
           linearDamping: 3.5,
           angularDamping: 1,
           fixedRotation: true,
         ),
         fixtureDefs: <FixtureDef>[
           FixtureDef(
             contactShape,
             density: 0.9,
             friction: 0.1,
             restitution: 0.08,
             filter: Filter()
               ..categoryBits = 0x0002
               ..maskBits = 0xFFFE,
           ),
         ],
       );

  /// Polygon contact body — [worldVertices] are in **body-local** space (centered on body origin).
  /// Forge2D `PolygonShape` requires convex, CCW, ≤8 vertices.
  factory SoldierContactBody.polygon({
    required List<Vector2> worldVertices,
    required Vector2 position,
  }) {
    final PolygonShape shape = PolygonShape()..set(worldVertices);
    return SoldierContactBody._(position: position, contactShape: shape);
  }

  /// Circle fallback for soldiers without a design polygon.
  factory SoldierContactBody.circle({
    required double radius,
    required Vector2 position,
  }) {
    final CircleShape shape = CircleShape()..radius = radius;
    return SoldierContactBody._(position: position, contactShape: shape);
  }

  @override
  void render(Canvas canvas) {}

  @override
  void renderDebugMode(Canvas canvas) {}
}
