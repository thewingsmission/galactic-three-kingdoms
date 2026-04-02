import 'package:flame_forge2d/flame_forge2d.dart';

/// Forge2D body for [SoldierContact]: circle = non-penetrable boundary.
/// Uses category **0x0002** and mask **0xFFFE** so it does **not** collide with the cohort leader (0x0001).
///
/// **Friction** is kept low: high μ with strong formation normals makes circle–circle
/// contacts behave like a static-friction lock (bodies “welded” until torn apart).
/// **Restitution** is small but non-zero so contacts can separate cleanly.
class SoldierContactBody extends BodyComponent<Forge2DGame> {
  SoldierContactBody({
    required this.contactRadius,
    required Vector2 position,
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
             CircleShape()..radius = contactRadius,
             density: 0.9,
             friction: 0.1,
             restitution: 0.08,
             filter: Filter()
               ..categoryBits = 0x0002
               ..maskBits = 0xFFFE,
           ),
         ],
       );

  final double contactRadius;
}
