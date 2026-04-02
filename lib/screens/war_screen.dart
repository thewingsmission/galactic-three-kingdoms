import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cohort_war_game.dart';
import '../models/cohort_models.dart';
import '../widgets/virtual_joystick.dart';

class WarScreen extends StatefulWidget {
  const WarScreen({super.key, required this.deployment});

  final CohortDeployment deployment;

  @override
  State<WarScreen> createState() => _WarScreenState();
}

class _WarScreenState extends State<WarScreen> {
  late final ValueNotifier<Vector2> _velocityHud = ValueNotifier<Vector2>(Vector2.zero());
  late final CohortWarGame _game = CohortWarGame(
    deployment: widget.deployment.copy(),
    velocityHud: _velocityHud,
  );

  @override
  void dispose() {
    _velocityHud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: GameWidget<CohortWarGame>(game: _game),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: VirtualJoystick(
              outerRadius: 72,
              knobRadius: 28,
              onChanged: _game.setStick,
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Cohort: ${_game.soldierCount}  ·  Forge2D velocity',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<Vector2>(
                  valueListenable: _velocityHud,
                  builder: (BuildContext context, Vector2 v, Widget? child) {
                    final double speed = v.length;
                    return Text(
                      'v = (${v.x.toStringAsFixed(0)}, ${v.y.toStringAsFixed(0)})  '
                      '|v| = ${speed.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
