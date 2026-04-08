import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    required this.onOpenInventory,
    required this.onOpenWar,
    required this.onOpenDesigns,
  });

  final VoidCallback onOpenInventory;
  final VoidCallback onOpenWar;
  final VoidCallback onOpenDesigns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _GalacticBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compactHeight = constraints.maxHeight < 360;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.36),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: compactHeight ? 18 : 22,
                              vertical: compactHeight ? 18 : 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Galactic Three Kingdoms',
                                  textAlign: TextAlign.center,
                                  style: (compactHeight
                                          ? theme.textTheme.headlineSmall
                                          : theme.textTheme.headlineMedium)
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                SizedBox(height: compactHeight ? 8 : 12),
                                Text(
                                  'Choose a destination.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: compactHeight ? 20 : 32),
                                _MenuButton(
                                  label: 'Inventory',
                                  icon: Icons.inventory_2_outlined,
                                  onPressed: onOpenInventory,
                                  compact: compactHeight,
                                ),
                                SizedBox(height: compactHeight ? 10 : 14),
                                _MenuButton(
                                  label: 'War',
                                  icon: Icons.shield_moon_outlined,
                                  onPressed: onOpenWar,
                                  compact: compactHeight,
                                ),
                                SizedBox(height: compactHeight ? 10 : 14),
                                _MenuButton(
                                  label: 'Designs',
                                  icon: Icons.category_outlined,
                                  onPressed: onOpenDesigns,
                                  compact: compactHeight,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _GalacticBackground extends StatelessWidget {
  const _GalacticBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF05070F),
            Color(0xFF090F22),
            Color(0xFF02040A),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.55, -0.35),
                radius: 0.55,
                colors: <Color>[
                  Color(0xAA7B5BFF),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.2),
                radius: 0.5,
                colors: <Color>[
                  Color(0x6656CCF2),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.15, 0.85),
                radius: 0.7,
                colors: <Color>[
                  Color(0x44FFC857),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _StarfieldPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint bright = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final Paint mid = Paint()..color = const Color(0xFFB5C7FF).withValues(alpha: 0.5);
    final Paint faint = Paint()..color = const Color(0xFFFFF3D1).withValues(alpha: 0.35);

    const List<Offset> stars = <Offset>[
      Offset(0.08, 0.16),
      Offset(0.14, 0.32),
      Offset(0.2, 0.24),
      Offset(0.26, 0.12),
      Offset(0.32, 0.28),
      Offset(0.38, 0.18),
      Offset(0.44, 0.36),
      Offset(0.52, 0.14),
      Offset(0.58, 0.3),
      Offset(0.66, 0.11),
      Offset(0.72, 0.24),
      Offset(0.78, 0.18),
      Offset(0.84, 0.34),
      Offset(0.9, 0.2),
      Offset(0.12, 0.58),
      Offset(0.18, 0.7),
      Offset(0.27, 0.52),
      Offset(0.35, 0.66),
      Offset(0.42, 0.56),
      Offset(0.5, 0.72),
      Offset(0.6, 0.6),
      Offset(0.68, 0.76),
      Offset(0.76, 0.56),
      Offset(0.84, 0.7),
      Offset(0.92, 0.62),
    ];

    for (int i = 0; i < stars.length; i++) {
      final Offset star = Offset(stars[i].dx * size.width, stars[i].dy * size.height);
      final double radius = i % 5 == 0 ? 1.9 : (i % 2 == 0 ? 1.3 : 0.9);
      final Paint paint = i % 4 == 0 ? bright : (i % 3 == 0 ? mid : faint);
      canvas.drawCircle(star, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
