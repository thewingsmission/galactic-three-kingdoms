import 'package:flutter/material.dart';

import '../widgets/pseudo3d_scene.dart';

class MainScreen extends StatefulWidget {
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
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Pseudo3DMeshMode _selectedMode = Pseudo3DMeshMode.solid;
  double _outlineHalfTransparentInnerTransparency = 0.9;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _GalacticBackground(),
          SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Pseudo3DScene(
                    meshMode: _selectedMode,
                    outlineHalfTransparentInnerTransparency:
                        _outlineHalfTransparentInnerTransparency,
                    boardBottomInset: 0,
                    joystickBottomInset: 138,
                    viewportHeightFactor: 0.92,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _MeshModeToggleGroup(
                        selectedMode: _selectedMode,
                        onSelected: (Pseudo3DMeshMode mode) {
                          setState(() => _selectedMode = mode);
                        },
                      ),
                      if (_selectedMode == Pseudo3DMeshMode.outlineHalfTransparent)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _TransparencySliderCard(
                            value: _outlineHalfTransparentInnerTransparency,
                            onChanged: (double value) {
                              setState(() {
                                _outlineHalfTransparentInnerTransparency = value;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _BottomRibbon(
                      onOpenDesigns: widget.onOpenDesigns,
                      onOpenInventory: widget.onOpenInventory,
                      onOpenWar: widget.onOpenWar,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeshModeToggleGroup extends StatelessWidget {
  const _MeshModeToggleGroup({
    required this.selectedMode,
    required this.onSelected,
  });

  final Pseudo3DMeshMode selectedMode;
  final ValueChanged<Pseudo3DMeshMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: Pseudo3DMeshMode.values
              .map(
                (Pseudo3DMeshMode mode) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _MeshModeButton(
                    label: _labelForMode(mode),
                    isSelected: mode == selectedMode,
                    onTap: () => onSelected(mode),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _labelForMode(Pseudo3DMeshMode mode) {
    return switch (mode) {
      Pseudo3DMeshMode.solid => 'Solid',
      Pseudo3DMeshMode.outlineTransparent => 'Outline + Transparent',
      Pseudo3DMeshMode.outlineHalfTransparent => 'Outline + Half-transparent',
    };
  }
}

class _MeshModeButton extends StatelessWidget {
  const _MeshModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.62)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isSelected ? 1 : 0.82),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _TransparencySliderCard extends StatelessWidget {
  const _TransparencySliderCard({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Inner Transparency ${((value * 100).round())}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 100,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withValues(alpha: 0.22),
              onChanged: onChanged,
            ),
          ),
        ],
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

class _BottomRibbon extends StatelessWidget {
  const _BottomRibbon({
    required this.onOpenDesigns,
    required this.onOpenInventory,
    required this.onOpenWar,
  });

  final VoidCallback onOpenDesigns;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenWar;

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_RibbonAction> actions = <_RibbonAction>[
      _RibbonAction(label: 'Codex', onTap: onOpenDesigns),
      _RibbonAction(label: 'Inventory', onTap: onOpenInventory),
      _RibbonAction(label: 'War', onTap: onOpenWar),
      _RibbonAction(
        label: 'Shop',
        onTap: () => _showPlaceholder(context, 'Shop'),
      ),
      _RibbonAction(
        label: 'Settings',
        onTap: () => _showPlaceholder(context, 'Settings'),
      ),
    ];

    return SizedBox(
      height: 122,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: actions
                .map(
                  (_RibbonAction action) => _RibbonButton(
                    label: action.label,
                    onTap: action.onTap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RibbonAction {
  const _RibbonAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

class _RibbonButton extends StatelessWidget {
  const _RibbonButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        );

    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkResponse(
              onTap: onTap,
              radius: 34,
              customBorder: const CircleBorder(),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: 2.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: labelStyle,
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
