import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
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
  static const _HexGlowConfig _hexGlowConfig = _HexGlowConfig(
    outerRadiusScale: 0.71,
    innerRadiusScale: 0.61,
    outerOpacity: 0.54,
    innerOpacity: 0.74,
    outerBlur: 2,
    innerBlur: 0,
  );
  _TempBottomRibbonDesign _bottomRibbonDesign =
      _TempBottomRibbonDesign.defaultMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _GalacticBackground(designIndex: 0),
          Positioned.fill(
            child: SafeArea(
              child: Pseudo3DScene(
                meshMode: Pseudo3DMeshMode.outlineHalfTransparent,
                boardBottomInset: 0,
                viewportHeightFactor: 0.92,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 12,
            bottom: 0,
            child: SafeArea(
              child: Center(
                child: _TempBottomRibbonPanel(
                  selectedDesign: _bottomRibbonDesign,
                  onChanged: (_TempBottomRibbonDesign value) {
                    setState(() {
                      _bottomRibbonDesign = value;
                    });
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomRibbon(
              designIndex:
                  _bottomRibbonDesign == _TempBottomRibbonDesign.defaultMode
                  ? 0
                  : 10,
              onOpenDesigns: widget.onOpenDesigns,
              onOpenInventory: widget.onOpenInventory,
              onOpenWar: widget.onOpenWar,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TempBottomRibbonDesign { defaultMode, color }

class _TempBottomRibbonPanel extends StatelessWidget {
  const _TempBottomRibbonPanel({
    required this.selectedDesign,
    required this.onChanged,
  });

  final _TempBottomRibbonDesign selectedDesign;
  final ValueChanged<_TempBottomRibbonDesign> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC0A1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TempBottomRibbonButton(
              label: 'Default',
              isSelected: selectedDesign == _TempBottomRibbonDesign.defaultMode,
              onTap: () => onChanged(_TempBottomRibbonDesign.defaultMode),
            ),
            const SizedBox(width: 6),
            _TempBottomRibbonButton(
              label: 'Color',
              isSelected: selectedDesign == _TempBottomRibbonDesign.color,
              onTap: () => onChanged(_TempBottomRibbonDesign.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempBottomRibbonButton extends StatelessWidget {
  const _TempBottomRibbonButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? const Color(0xFF3A74FF).withValues(alpha: 0.26)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF9BC0FF)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalacticBackground extends StatefulWidget {
  const _GalacticBackground({required this.designIndex});

  final int designIndex;

  @override
  State<_GalacticBackground> createState() => _GalacticBackgroundState();
}

class _GalacticBackgroundState extends State<_GalacticBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _scrollPeriod = Duration(seconds: 150);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _scrollPeriod)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final _GalaxyBackgroundSpec spec =
                _galaxyBackgroundSpecs[widget.designIndex];
            final double tileWidth = math.max(720, constraints.maxWidth * 1.25);
            final double shift = _controller.value * tileWidth;
            return ColoredBox(
              color: const Color(0xFF02040A),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      left: -tileWidth + shift,
                      top: 0,
                      bottom: 0,
                      width: tileWidth,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GalaxyTilePainter(spec: spec),
                        ),
                      ),
                    ),
                    Positioned(
                      left: shift,
                      top: 0,
                      bottom: 0,
                      width: tileWidth,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GalaxyTilePainter(spec: spec),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GalaxyTilePainter extends CustomPainter {
  const _GalaxyTilePainter({required this.spec});

  final _GalaxyBackgroundSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _GalaxyStamp galaxy in spec.galaxies) {
      _paintGalaxy(canvas, size, galaxy);
    }

    final math.Random random = math.Random(spec.seed);
    for (int i = 0; i < spec.starCount; i++) {
      final Offset star = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final double radius = i % 9 == 0 ? 2.0 : (i % 3 == 0 ? 1.2 : 0.8);
      final Color color = switch (i % 5) {
        0 => spec.starBright,
        1 => spec.starMid,
        2 => spec.starWarm,
        _ => spec.starDim,
      };
      canvas.drawCircle(star, radius, Paint()..color = color);
    }
  }

  void _paintGalaxy(Canvas canvas, Size size, _GalaxyStamp galaxy) {
    final Offset center = Offset(
      galaxy.center.dx * size.width,
      galaxy.center.dy * size.height,
    );
    final double radius = size.width * galaxy.radiusFactor;
    _paintHalo(canvas, center, radius, galaxy);
    switch (galaxy.shape) {
      case _GalaxyShape.spiral:
        _paintSpiralGalaxy(
          canvas,
          center,
          radius,
          galaxy,
          armCount: 2,
          barStrength: 0,
        );
      case _GalaxyShape.barredSpiral:
        _paintSpiralGalaxy(
          canvas,
          center,
          radius,
          galaxy,
          armCount: 2,
          barStrength: 1,
        );
      case _GalaxyShape.elliptical:
        _paintEllipticalGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.ring:
        _paintRingGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.lenticular:
        _paintLenticularGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.doubleCore:
        _paintDoubleCoreGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.cluster:
        _paintClusterGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.arc:
        _paintArcGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.irregular:
        _paintIrregularGalaxy(canvas, center, radius, galaxy);
      case _GalaxyShape.dwarfSwarm:
        _paintDwarfSwarm(canvas, center, radius, galaxy);
    }
    _paintCore(canvas, center, radius, galaxy);
  }

  void _paintHalo(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Rect haloRect = Rect.fromCircle(
      center: center,
      radius: radius * 1.35,
    );
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            galaxy.haloColor.withValues(alpha: 0.28),
            galaxy.haloColor.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(haloRect),
    );
  }

  void _paintCore(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Rect coreRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.42,
    );
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            galaxy.coreColor,
            galaxy.coreColor.withValues(alpha: 0.75),
            galaxy.armColor.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.32, 0.72, 1],
        ).createShader(coreRect),
    );
  }

  void _paintSpiralGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy, {
    required int armCount,
    required double barStrength,
  }) {
    final Paint armPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    if (barStrength > 0) {
      final Rect barRect = Rect.fromCenter(
        center: center,
        width: radius * 1.05,
        height: radius * 0.18,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(galaxy.rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(radius * 0.1)),
        Paint()
          ..color = galaxy.armColor.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.restore();
    }

    for (int arm = 0; arm < armCount; arm++) {
      final double baseArmAngle =
          galaxy.rotation + arm * (math.pi * 2 / armCount);
      for (int i = 0; i < 140; i++) {
        final double t = i / 139;
        final double angle = baseArmAngle + t * galaxy.swirl;
        final double distance = radius * (0.08 + t * 0.96);
        final Offset p =
            center + Offset(math.cos(angle), math.sin(angle) * 0.58) * distance;
        final double dotRadius = radius * (0.034 + (1 - t) * 0.018);
        armPaint.color =
            Color.lerp(
              galaxy.armColor.withValues(alpha: 0.52),
              galaxy.coreColor.withValues(alpha: 0.14),
              t,
            ) ??
            galaxy.armColor;
        canvas.drawCircle(p, dotRadius, armPaint);
      }
    }
  }

  void _paintEllipticalGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Rect rect = Rect.fromCenter(
      center: center,
      width: radius * 1.8,
      height: radius * 1.05,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(galaxy.rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            galaxy.coreColor.withValues(alpha: 0.88),
            galaxy.armColor.withValues(alpha: 0.34),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.52, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _paintRingGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Rect outerRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.95,
    );
    final Rect innerRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.52,
    );
    canvas.drawCircle(
      center,
      radius * 0.95,
      Paint()
        ..color = galaxy.armColor.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()..blendMode = BlendMode.clear,
    );
    final Path ring = Path()
      ..addOval(outerRect)
      ..addOval(innerRect);
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.18
        ..color = galaxy.armColor.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  void _paintLenticularGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Rect discRect = Rect.fromCenter(
      center: center,
      width: radius * 1.9,
      height: radius * 0.6,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(galaxy.rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      discRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.transparent,
            galaxy.armColor.withValues(alpha: 0.26),
            galaxy.coreColor.withValues(alpha: 0.72),
            galaxy.armColor.withValues(alpha: 0.26),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.22, 0.5, 0.78, 1],
        ).createShader(discRect),
    );
    canvas.restore();
  }

  void _paintDoubleCoreGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Offset a =
        center +
        Offset(math.cos(galaxy.rotation), math.sin(galaxy.rotation)) *
            radius *
            0.22;
    final Offset b =
        center -
        Offset(math.cos(galaxy.rotation), math.sin(galaxy.rotation)) *
            radius *
            0.22;
    for (final Offset p in <Offset>[a, b]) {
      canvas.drawCircle(
        p,
        radius * 0.28,
        Paint()
          ..color = galaxy.coreColor.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.9,
      Paint()
        ..color = galaxy.armColor.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _paintClusterGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final math.Random random = math.Random(galaxy.seed);
    final Paint paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = 0; i < 70; i++) {
      final double angle = random.nextDouble() * math.pi * 2;
      final double dist = radius * math.sqrt(random.nextDouble()) * 1.15;
      final Offset p =
          center + Offset(math.cos(angle), math.sin(angle) * 0.75) * dist;
      final double r = radius * (0.018 + random.nextDouble() * 0.028);
      paint.color =
          Color.lerp(
            galaxy.coreColor.withValues(alpha: 0.55),
            galaxy.armColor.withValues(alpha: 0.18),
            random.nextDouble(),
          ) ??
          galaxy.armColor;
      canvas.drawCircle(p, r, paint);
    }
  }

  void _paintArcGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (int i = 0; i < 4; i++) {
      paint.color = galaxy.armColor.withValues(alpha: 0.18 + i * 0.04);
      paint.strokeWidth = radius * (0.06 - i * 0.01);
      final Rect rect = Rect.fromCenter(
        center: center,
        width: radius * (1.0 + i * 0.22),
        height: radius * (0.7 + i * 0.16),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(galaxy.rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(rect, 0.2 + i * 0.18, 2.2, false, paint);
      canvas.restore();
    }
  }

  void _paintIrregularGalaxy(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final math.Random random = math.Random(galaxy.seed);
    final Paint paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (int i = 0; i < 110; i++) {
      final Offset p =
          center +
          Offset(
            (random.nextDouble() - 0.5) * radius * 1.8,
            (random.nextDouble() - 0.5) * radius * 1.1,
          );
      final double r = radius * (0.015 + random.nextDouble() * 0.03);
      paint.color = i % 3 == 0
          ? galaxy.coreColor.withValues(alpha: 0.38)
          : galaxy.armColor.withValues(alpha: 0.22);
      canvas.drawCircle(p, r, paint);
    }
  }

  void _paintDwarfSwarm(
    Canvas canvas,
    Offset center,
    double radius,
    _GalaxyStamp galaxy,
  ) {
    final math.Random random = math.Random(galaxy.seed);
    final Paint paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = 0; i < 9; i++) {
      final double angle = galaxy.rotation + i * 0.68;
      final double dist = radius * (0.25 + i * 0.12);
      final Offset c =
          center + Offset(math.cos(angle), math.sin(angle) * 0.72) * dist;
      paint.color = galaxy.armColor.withValues(alpha: 0.18);
      canvas.drawCircle(c, radius * (0.16 - i * 0.01), paint);
      for (int j = 0; j < 18; j++) {
        final Offset p =
            c +
            Offset(
              (random.nextDouble() - 0.5) * radius * 0.24,
              (random.nextDouble() - 0.5) * radius * 0.18,
            );
        canvas.drawCircle(
          p,
          radius * 0.012,
          Paint()..color = galaxy.coreColor.withValues(alpha: 0.38),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyTilePainter oldDelegate) {
    return oldDelegate.spec != spec;
  }
}

class _GalaxyBackgroundSpec {
  const _GalaxyBackgroundSpec({
    required this.seed,
    required this.galaxies,
    required this.starCount,
    required this.starBright,
    required this.starMid,
    required this.starWarm,
    required this.starDim,
  });

  final int seed;
  final List<_GalaxyStamp> galaxies;
  final int starCount;
  final Color starBright;
  final Color starMid;
  final Color starWarm;
  final Color starDim;
}

class _GalaxyStamp {
  const _GalaxyStamp({
    required this.shape,
    required this.center,
    required this.radiusFactor,
    required this.rotation,
    required this.swirl,
    required this.coreColor,
    required this.armColor,
    required this.haloColor,
    this.seed = 0,
  });

  final _GalaxyShape shape;
  final Offset center;
  final double radiusFactor;
  final double rotation;
  final double swirl;
  final Color coreColor;
  final Color armColor;
  final Color haloColor;
  final int seed;
}

enum _GalaxyShape {
  spiral,
  barredSpiral,
  elliptical,
  ring,
  lenticular,
  doubleCore,
  cluster,
  arc,
  irregular,
  dwarfSwarm,
}

const List<_GalaxyBackgroundSpec> _galaxyBackgroundSpecs =
    <_GalaxyBackgroundSpec>[
      _GalaxyBackgroundSpec(
        seed: 11,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.spiral,
            center: Offset(0.32, 0.34),
            radiusFactor: 0.11,
            rotation: 0.4,
            swirl: 6.2,
            coreColor: Color(0xFFFFF3C6),
            armColor: Color(0xFFAE8BFF),
            haloColor: Color(0xFF7A5CFF),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.arc,
            center: Offset(0.74, 0.64),
            radiusFactor: 0.08,
            rotation: 2.4,
            swirl: 5.4,
            coreColor: Color(0xFFFFE8BC),
            armColor: Color(0xFF65D7FF),
            haloColor: Color(0xFF2C8AD7),
          ),
        ],
        starCount: 170,
        starBright: Color(0xFFEFF6FF),
        starMid: Color(0xFFBFD6FF),
        starWarm: Color(0xFFFFF0C3),
        starDim: Color(0x66FFFFFF),
      ),
      _GalaxyBackgroundSpec(
        seed: 19,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.barredSpiral,
            center: Offset(0.64, 0.3),
            radiusFactor: 0.12,
            rotation: 1.3,
            swirl: 6.8,
            coreColor: Color(0xFFFFE4D1),
            armColor: Color(0xFFFF74BC),
            haloColor: Color(0xFFA44BFF),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.cluster,
            center: Offset(0.24, 0.62),
            radiusFactor: 0.09,
            rotation: -0.6,
            swirl: 4.8,
            coreColor: Color(0xFFFFF4D8),
            armColor: Color(0xFF9A8BFF),
            haloColor: Color(0xFF5A4ED7),
            seed: 1902,
          ),
        ],
        starCount: 180,
        starBright: Color(0xFFFFFFFF),
        starMid: Color(0xFFE3C7FF),
        starWarm: Color(0xFFFFE8BC),
        starDim: Color(0x55F3E7FF),
      ),
      _GalaxyBackgroundSpec(
        seed: 27,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.elliptical,
            center: Offset(0.36, 0.28),
            radiusFactor: 0.1,
            rotation: 0.35,
            swirl: 0,
            coreColor: Color(0xFFFFF5D9),
            armColor: Color(0xFF5FFFD7),
            haloColor: Color(0xFF13AFA0),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.irregular,
            center: Offset(0.68, 0.68),
            radiusFactor: 0.08,
            rotation: 2.8,
            swirl: 0,
            coreColor: Color(0xFFF8FFE6),
            armColor: Color(0xFF69D6FF),
            haloColor: Color(0xFF277F9E),
            seed: 2711,
          ),
        ],
        starCount: 165,
        starBright: Color(0xFFE8FFFF),
        starMid: Color(0xFF89FFD6),
        starWarm: Color(0xFFFFF1C9),
        starDim: Color(0x663EE0FF),
      ),
      _GalaxyBackgroundSpec(
        seed: 33,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.ring,
            center: Offset(0.28, 0.62),
            radiusFactor: 0.11,
            rotation: 2.0,
            swirl: 0,
            coreColor: Color(0xFFFFF3D5),
            armColor: Color(0xFFFFB25B),
            haloColor: Color(0xFFBE5D15),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.arc,
            center: Offset(0.74, 0.34),
            radiusFactor: 0.09,
            rotation: -0.8,
            swirl: 4.0,
            coreColor: Color(0xFFFFF0C0),
            armColor: Color(0xFFFFD16B),
            haloColor: Color(0xFFA44414),
          ),
        ],
        starCount: 172,
        starBright: Color(0xFFFFF9E5),
        starMid: Color(0xFFFFD695),
        starWarm: Color(0xFFFFE4AE),
        starDim: Color(0x66FFB36A),
      ),
      _GalaxyBackgroundSpec(
        seed: 41,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.lenticular,
            center: Offset(0.5, 0.36),
            radiusFactor: 0.12,
            rotation: 0.9,
            swirl: 0,
            coreColor: Color(0xFFFFFFFF),
            armColor: Color(0xFFC4BDFF),
            haloColor: Color(0xFF6768D6),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.dwarfSwarm,
            center: Offset(0.78, 0.72),
            radiusFactor: 0.06,
            rotation: 1.8,
            swirl: 0,
            coreColor: Color(0xFFF4FFF7),
            armColor: Color(0xFFA9FFF0),
            haloColor: Color(0xFF39C1A7),
            seed: 4178,
          ),
        ],
        starCount: 195,
        starBright: Color(0xFFFFFFFF),
        starMid: Color(0xFFD6E1FF),
        starWarm: Color(0xFFFFF3D0),
        starDim: Color(0x55D7D9FF),
      ),
      _GalaxyBackgroundSpec(
        seed: 52,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.doubleCore,
            center: Offset(0.32, 0.36),
            radiusFactor: 0.09,
            rotation: 0.7,
            swirl: 0,
            coreColor: Color(0xFFFFFFFF),
            armColor: Color(0xFF7EDBFF),
            haloColor: Color(0xFF1B7CCF),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.barredSpiral,
            center: Offset(0.66, 0.56),
            radiusFactor: 0.12,
            rotation: -1.1,
            swirl: 6.4,
            coreColor: Color(0xFFEAF5FF),
            armColor: Color(0xFF8194FF),
            haloColor: Color(0xFF2957AD),
          ),
        ],
        starCount: 188,
        starBright: Color(0xFFEFFFFF),
        starMid: Color(0xFFB7E8FF),
        starWarm: Color(0xFFFFF2D6),
        starDim: Color(0x553AA6FF),
      ),
      _GalaxyBackgroundSpec(
        seed: 63,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.cluster,
            center: Offset(0.38, 0.54),
            radiusFactor: 0.11,
            rotation: 2.5,
            swirl: 0,
            coreColor: Color(0xFFFFF3D8),
            armColor: Color(0xFFFF8ACC),
            haloColor: Color(0xFFA93CF3),
            seed: 6301,
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.irregular,
            center: Offset(0.76, 0.28),
            radiusFactor: 0.08,
            rotation: 0.2,
            swirl: 0,
            coreColor: Color(0xFFFFF0E0),
            armColor: Color(0xFF9C8BFF),
            haloColor: Color(0xFF6138D1),
            seed: 6302,
          ),
        ],
        starCount: 178,
        starBright: Color(0xFFFFF6FD),
        starMid: Color(0xFFFFBAEA),
        starWarm: Color(0xFFFFF2D0),
        starDim: Color(0x556C4AFF),
      ),
      _GalaxyBackgroundSpec(
        seed: 74,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.arc,
            center: Offset(0.54, 0.42),
            radiusFactor: 0.11,
            rotation: -0.4,
            swirl: 4.2,
            coreColor: Color(0xFFF8FFE7),
            armColor: Color(0xFF8CFF9F),
            haloColor: Color(0xFF2F8A51),
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.ring,
            center: Offset(0.22, 0.66),
            radiusFactor: 0.07,
            rotation: 1.8,
            swirl: 0,
            coreColor: Color(0xFFFFF3D4),
            armColor: Color(0xFFC6FF6F),
            haloColor: Color(0xFF708C21),
          ),
        ],
        starCount: 176,
        starBright: Color(0xFFF4FFF0),
        starMid: Color(0xFFC9FFD4),
        starWarm: Color(0xFFFFF3C9),
        starDim: Color(0x5557DB82),
      ),
      _GalaxyBackgroundSpec(
        seed: 81,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.dwarfSwarm,
            center: Offset(0.3, 0.56),
            radiusFactor: 0.1,
            rotation: 1.2,
            swirl: 0,
            coreColor: Color(0xFFFFF6E3),
            armColor: Color(0xFFD2A2FF),
            haloColor: Color(0xFF8451CE),
            seed: 8101,
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.lenticular,
            center: Offset(0.68, 0.34),
            radiusFactor: 0.1,
            rotation: 2.9,
            swirl: 0,
            coreColor: Color(0xFFFFF0D4),
            armColor: Color(0xFFFFC571),
            haloColor: Color(0xFFBB6F2A),
          ),
        ],
        starCount: 182,
        starBright: Color(0xFFFFFFFF),
        starMid: Color(0xFFE4C8FF),
        starWarm: Color(0xFFFFE2B0),
        starDim: Color(0x556E7BFF),
      ),
      _GalaxyBackgroundSpec(
        seed: 97,
        galaxies: <_GalaxyStamp>[
          _GalaxyStamp(
            shape: _GalaxyShape.irregular,
            center: Offset(0.42, 0.42),
            radiusFactor: 0.12,
            rotation: 0.5,
            swirl: 0,
            coreColor: Color(0xFFF5FCFF),
            armColor: Color(0xFF83D2FF),
            haloColor: Color(0xFF4260DB),
            seed: 9701,
          ),
          _GalaxyStamp(
            shape: _GalaxyShape.doubleCore,
            center: Offset(0.76, 0.72),
            radiusFactor: 0.06,
            rotation: -1.5,
            swirl: 0,
            coreColor: Color(0xFFF2FFF8),
            armColor: Color(0xFF8FFFE9),
            haloColor: Color(0xFF2B9A88),
          ),
        ],
        starCount: 190,
        starBright: Color(0xFFF4FEFF),
        starMid: Color(0xFFBFE0FF),
        starWarm: Color(0xFFFFF0D2),
        starDim: Color(0x55367DFF),
      ),
    ];

class _BottomRibbon extends StatelessWidget {
  const _BottomRibbon({
    required this.designIndex,
    required this.onOpenDesigns,
    required this.onOpenInventory,
    required this.onOpenWar,
  });

  final int designIndex;
  final VoidCallback onOpenDesigns;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenWar;

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final List<_RibbonAction> actions = <_RibbonAction>[
      _RibbonAction(label: 'Soldier', onTap: onOpenInventory),
      _RibbonAction(label: 'Atlas', onTap: onOpenDesigns),
      _RibbonAction(
        label: 'Rank',
        onTap: () => _showPlaceholder(context, 'Rank'),
      ),
      _RibbonAction(label: 'War', onTap: onOpenWar),
      _RibbonAction(
        label: 'Achievement',
        onTap: () => _showPlaceholder(context, 'Achievement'),
      ),
      _RibbonAction(
        label: 'Shop',
        onTap: () => _showPlaceholder(context, 'Shop'),
      ),
      _RibbonAction(
        label: 'Setting',
        onTap: () => _showPlaceholder(context, 'Setting'),
      ),
    ];

    return switch (designIndex) {
      0 => _buildClassic(context, actions),
      10 => _buildColorClassic(context, actions),
      1 => _buildGlassRail(context, actions),
      2 => _buildSpeedTabs(context, actions),
      3 => _buildInsetConsole(context, actions),
      4 => _buildFloatingPods(context, actions),
      5 => _buildChevronRun(context, actions),
      6 => _buildSteppedDeck(context, actions),
      7 => _buildConnectedTrain(context, actions),
      8 => _buildOrbitNodes(context, actions),
      _ => _buildTicketStrip(context, actions),
    };
  }

  TextStyle _labelStyle(
    BuildContext context, {
    required Color color,
    double size = 10.5,
    FontWeight weight = FontWeight.w700,
    double spacing = 0.45,
  }) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
    );
  }

  Color _purpleRibbonTierColor(int tier) {
    final HSLColor source = HSLColor.fromColor(
      factionTierColor(SoldierDesignPalette.red, tier),
    );
    final double purpleHue = HSLColor.fromColor(const Color(0xFFA44BFF)).hue;
    return source.withHue(purpleHue).toColor();
  }

  Widget _circleShell({
    required double size,
    required Color border,
    required List<BoxShadow> shadows,
    Color? color,
    Gradient? gradient,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradient == null ? color : null,
        gradient: gradient,
        border: Border.all(color: border, width: 1.8),
        boxShadow: shadows,
      ),
    );
  }

  Widget _roundedShell({
    required double width,
    required double height,
    required double radius,
    required Color border,
    required List<BoxShadow> shadows,
    Color? color,
    Gradient? gradient,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: gradient == null ? color : null,
        gradient: gradient,
        border: Border.all(color: border, width: 1.6),
        boxShadow: shadows,
      ),
    );
  }

  Widget _slantedShell({
    required double width,
    required double height,
    required double slant,
    required Color border,
    required List<BoxShadow> shadows,
    Color? color,
    Gradient? gradient,
  }) {
    return ClipPath(
      clipper: _SlantedCapsuleClipper(slant: slant),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          border: Border.all(color: border, width: 1.4),
          boxShadow: shadows,
        ),
      ),
    );
  }

  Widget _buildClassic(BuildContext context, List<_RibbonAction> actions) {
    final TextStyle labelStyle = _labelStyle(
      context,
      color: const Color(0xFF151C28).withValues(alpha: 0.9),
      size: 10,
      weight: FontWeight.w800,
      spacing: 0.35,
    );
    return SizedBox(
      height: 98,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Color> accentColors = <Color>[
            factionTierColor(SoldierDesignPalette.red, 1),
            factionTierColor(SoldierDesignPalette.red, 3),
            factionTierColor(SoldierDesignPalette.yellow, 1),
            factionTierColor(SoldierDesignPalette.yellow, 3),
            factionTierColor(SoldierDesignPalette.blue, 1),
            factionTierColor(SoldierDesignPalette.blue, 3),
            factionTierColor(SoldierDesignPalette.blue, 4),
          ];
          final List<Color> fillColors = <Color>[
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
          ];
          final List<Color> borderColors = <Color>[
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
          ];
          const List<double> imageDxWidthUnits = <double>[
            0.01,
            0.00,
            0.00,
            -0.01,
            0.00,
            0.00,
            0.00,
          ];
          const List<double> imageDyHeightUnits = <double>[
            0.03,
            0.01,
            0.00,
            0.055,
            0.00,
            0.02,
            0.00,
          ];
          const List<double> glowDyHeightUnits = <double>[
            0.00,
            0.00,
            0.00,
            0.04,
            0.00,
            0.00,
            0.00,
          ];
          const List<double> imageScaleRatios = <double>[
            1.27,
            0.95,
            1.31,
            1.495,
            1.20,
            0.97,
            1.16,
          ];
          const List<double> visualScaleRatios = <double>[
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
          ];
          return _buildPolygonClassicPanel(
            constraints: constraints,
            actions: actions,
            labelStyle: labelStyle,
            accentColors: accentColors,
            fillColors: fillColors,
            borderColors: borderColors,
            imageDxWidthUnits: imageDxWidthUnits,
            imageDyHeightUnits: imageDyHeightUnits,
            glowDyHeightUnits: glowDyHeightUnits,
            imageScaleRatios: imageScaleRatios,
            visualScaleRatios: visualScaleRatios,
            showGlow: true,
            contentOffsetYPx: 0,
          );
        },
      ),
    );
  }

  Widget _buildColorClassic(BuildContext context, List<_RibbonAction> actions) {
    final TextStyle labelStyle = _labelStyle(
      context,
      color: Colors.white.withValues(alpha: 0.95),
      size: 10,
      weight: FontWeight.w800,
      spacing: 0.35,
    );
    return SizedBox(
      height: 98,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Color> accentColors = <Color>[
            factionTierColor(SoldierDesignPalette.red, 1),
            factionTierColor(SoldierDesignPalette.yellow, 1),
            factionTierColor(SoldierDesignPalette.blue, 1),
            _purpleRibbonTierColor(1),
            factionTierColor(SoldierDesignPalette.blue, 1),
            factionTierColor(SoldierDesignPalette.yellow, 1),
            factionTierColor(SoldierDesignPalette.red, 1),
          ];
          final List<Color> fillColors = <Color>[
            factionTierColor(
              SoldierDesignPalette.red,
              3,
            ).withValues(alpha: 0.5),
            factionTierColor(
              SoldierDesignPalette.yellow,
              3,
            ).withValues(alpha: 0.5),
            factionTierColor(
              SoldierDesignPalette.blue,
              3,
            ).withValues(alpha: 0.5),
            _purpleRibbonTierColor(3).withValues(alpha: 0.5),
            factionTierColor(
              SoldierDesignPalette.blue,
              3,
            ).withValues(alpha: 0.5),
            factionTierColor(
              SoldierDesignPalette.yellow,
              3,
            ).withValues(alpha: 0.5),
            factionTierColor(
              SoldierDesignPalette.red,
              3,
            ).withValues(alpha: 0.5),
          ];
          final List<Color> borderColors = <Color>[
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
          ];
          const List<double> imageDxWidthUnits = <double>[
            0.01,
            0.00,
            0.00,
            -0.01,
            0.00,
            0.00,
            0.00,
          ];
          const List<double> imageDyHeightUnits = <double>[
            0.03,
            0.01,
            0.00,
            0.055,
            0.00,
            0.02,
            0.00,
          ];
          const List<double> glowDyHeightUnits = <double>[
            0.00,
            0.00,
            0.00,
            0.04,
            0.00,
            0.00,
            0.00,
          ];
          const List<double> imageScaleRatios = <double>[
            1.27,
            0.95,
            1.31,
            1.495,
            1.20,
            0.97,
            1.16,
          ];
          const List<double> visualScaleRatios = <double>[
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
            1.00,
          ];
          return _buildPolygonClassicPanel(
            constraints: constraints,
            actions: actions,
            labelStyle: labelStyle,
            accentColors: accentColors,
            fillColors: fillColors,
            borderColors: borderColors,
            imageDxWidthUnits: imageDxWidthUnits,
            imageDyHeightUnits: imageDyHeightUnits,
            glowDyHeightUnits: glowDyHeightUnits,
            imageScaleRatios: imageScaleRatios,
            visualScaleRatios: visualScaleRatios,
            showGlow: false,
            contentOffsetYPx: -10,
          );
        },
      ),
    );
  }

  Widget _buildPolygonClassicPanel({
    required BoxConstraints constraints,
    required List<_RibbonAction> actions,
    required TextStyle labelStyle,
    required List<Color> accentColors,
    required List<Color> fillColors,
    required List<Color> borderColors,
    required List<double> imageDxWidthUnits,
    required List<double> imageDyHeightUnits,
    required List<double> glowDyHeightUnits,
    required List<double> imageScaleRatios,
    required List<double> visualScaleRatios,
    required bool showGlow,
    required double contentOffsetYPx,
  }) {
    const double buttonHeight = 81.84;
    const double warWidthScale = 1.10;
    const double warHeightScale = 1.18;
    const double preferredPanelWidth = 696.0;
    final double panelWidth = math.min(
      constraints.maxWidth,
      preferredPanelWidth,
    );
    final double baseButtonWidth = math.max(
      0,
      panelWidth / ((actions.length - 1) + warWidthScale),
    );
    final List<double> buttonWidths = <double>[
      baseButtonWidth,
      baseButtonWidth,
      baseButtonWidth,
      baseButtonWidth * warWidthScale,
      baseButtonWidth,
      baseButtonWidth,
      baseButtonWidth,
    ];
    final List<double> buttonHeights = <double>[
      buttonHeight,
      buttonHeight,
      buttonHeight,
      buttonHeight * warHeightScale,
      buttonHeight,
      buttonHeight,
      buttonHeight,
    ];
    final double totalButtonsWidth = buttonWidths.reduce(
      (double a, double b) => a + b,
    );
    final double rowLeft = (panelWidth - totalButtonsWidth) / 2;
    final List<double> buttonLefts = <double>[];
    double currentLeft = rowLeft;
    for (int index = 0; index < actions.length; index++) {
      buttonLefts.add(currentLeft);
      currentLeft += buttonWidths[index];
    }
    final List<_RibbonPolygonButtonSpec> specs = <_RibbonPolygonButtonSpec>[
      for (int index = 0; index < actions.length; index++)
        (() {
          final double left = buttonLefts[index];
          final double right = buttonLefts[index] + buttonWidths[index];
          final double top = (buttonHeight - buttonHeights[index]).clamp(
            -1000,
            1000,
          );
          final double midY = (top + buttonHeight) / 2;
          final double inset = math.min(
            buttonWidths[index] * 0.16,
            buttonHeights[index] * 0.24,
          );
          return _RibbonPolygonButtonSpec(
            label: actions[index].label,
            onTap: actions[index].onTap,
            assetPath: 'image/button_${actions[index].label.toLowerCase()}.png',
            polygon: <Offset>[
              Offset(left + inset, top),
              Offset(right - inset, top),
              Offset(right, midY),
              Offset(right - inset, buttonHeight),
              Offset(left + inset, buttonHeight),
              Offset(left, midY),
            ],
            accentColor: accentColors[index],
            fill: fillColors[index],
            border: borderColors[index],
            imageDeltaXWidthUnits: imageDxWidthUnits[index],
            imageDeltaYHeightUnits: imageDyHeightUnits[index],
            glowDeltaYHeightUnits: glowDyHeightUnits[index],
            imageScaleRatio: imageScaleRatios[index],
            visualScaleRatio: visualScaleRatios[index],
            showGlow: showGlow,
            paintPolygonSurface: showGlow,
            contentOffsetYPx: contentOffsetYPx,
          );
        })(),
    ];
    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: const Offset(0, 8.184),
        child: SizedBox(
          width: panelWidth,
          height: buttonHeight,
          child: _PolygonRibbonPanel(
            specs: specs,
            labelStyle: labelStyle,
            panelSize: Size(panelWidth, buttonHeight),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassRail(BuildContext context, List<_RibbonAction> actions) {
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 6,
            right: 6,
            bottom: 18,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0x442E6B8D),
                    Color(0x88202B40),
                    Color(0x443667AA),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF52D8FF).withValues(alpha: 0.14),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 58,
            child: Container(
              height: 2,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: actions
                .map(
                  (_RibbonAction action) => _ActionTile(
                    label: action.label,
                    onTap: action.onTap,
                    width: 70,
                    labelStyle: _labelStyle(
                      context,
                      color: const Color(0xFFE6FBFF),
                      size: 10.5,
                      spacing: 0.55,
                    ),
                    button: _roundedShell(
                      width: 58,
                      height: 58,
                      radius: 20,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xAA2B5876), Color(0x66152131)],
                      ),
                      border: const Color(0xFF87E8FF).withValues(alpha: 0.78),
                      shadows: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF52D8FF,
                          ).withValues(alpha: 0.18),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTabs(BuildContext context, List<_RibbonAction> actions) {
    final List<double> yOffsets = List<double>.generate(actions.length, (
      int i,
    ) {
      if (actions.length <= 1) {
        return 0;
      }
      final double t = i / (actions.length - 1);
      return 4.0 - 8.0 * t;
    });
    return SizedBox(
      height: 124,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 10,
            right: 0,
            bottom: 26,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0x002A2A2A),
                    Color(0xAA8A1228),
                    Color(0x66F06452),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 0,
            bottom: 18,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0x0013151A),
                    Color(0x88F6904E),
                    Color(0x00F6904E),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(actions.length, (int index) {
              final _RibbonAction action = actions[index];
              return _ActionTile(
                label: action.label,
                onTap: action.onTap,
                width: 56,
                topOffset: yOffsets[index],
                gap: 6,
                labelStyle: _labelStyle(
                  context,
                  color: const Color(0xFFFFE8D8),
                  size: 9.8,
                  spacing: 0.7,
                ),
                button: _slantedShell(
                  width: 78,
                  height: 42,
                  slant: 16,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFF5B15A), Color(0xFF7E1F1B)],
                  ),
                  border: const Color(0xFFFFE7BF).withValues(alpha: 0.8),
                  shadows: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFF26D4E).withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInsetConsole(BuildContext context, List<_RibbonAction> actions) {
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF0A111A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 24,
            child: Row(
              children: List<Widget>.generate(5, (int index) {
                return Expanded(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: actions
                .map(
                  (_RibbonAction action) => _ActionTile(
                    label: action.label,
                    onTap: action.onTap,
                    width: 68,
                    topOffset: -2,
                    gap: 5,
                    labelStyle: _labelStyle(
                      context,
                      color: const Color(0xFFD9E7F7),
                      size: 10,
                      weight: FontWeight.w600,
                      spacing: 0.65,
                    ),
                    button: _roundedShell(
                      width: 56,
                      height: 46,
                      radius: 14,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFF4E5E73), Color(0xFF1E2A39)],
                      ),
                      border: Colors.white.withValues(alpha: 0.14),
                      shadows: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPods(BuildContext context, List<_RibbonAction> actions) {
    final List<double> yOffsets = <double>[2, 0, -4, 0, 2];
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 8,
            right: 8,
            bottom: 24,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0x222A2B3A),
                    Color(0x88393E59),
                    Color(0x222A2B3A),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(actions.length, (int index) {
              final _RibbonAction action = actions[index];
              return _ActionTile(
                label: action.label,
                onTap: action.onTap,
                width: 66,
                topOffset: yOffsets[index % yOffsets.length],
                gap: 6,
                labelStyle: _labelStyle(
                  context,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                button: SizedBox(
                  width: 58,
                  height: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _circleShell(
                        size: 42,
                        gradient: const RadialGradient(
                          colors: <Color>[Color(0xFF8A83FF), Color(0xFF1A1F38)],
                        ),
                        border: Colors.white.withValues(alpha: 0.58),
                        shadows: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF8A83FF,
                            ).withValues(alpha: 0.18),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChevronRun(BuildContext context, List<_RibbonAction> actions) {
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0x00121118),
                    Color(0xAA44244F),
                    Color(0x663488C8),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(actions.length, (int index) {
              final _RibbonAction action = actions[index];
              return _ActionTile(
                label: action.label,
                onTap: action.onTap,
                width: 56,
                topOffset: index.isEven ? -2 : 2,
                gap: 6,
                labelStyle: _labelStyle(
                  context,
                  color: const Color(0xFFF3E7FF),
                  size: 10,
                  spacing: 0.75,
                ),
                button: _slantedShell(
                  width: 82,
                  height: 46,
                  slant: 18,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFC86DFF), Color(0xFF1E224A)],
                  ),
                  border: Colors.white.withValues(alpha: 0.62),
                  shadows: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFB05DFF).withValues(alpha: 0.2),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSteppedDeck(BuildContext context, List<_RibbonAction> actions) {
    final List<double> yOffsets = <double>[8, 4, 0, -4, -8];
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0x22305068),
                        Color(0xAA111C2E),
                        Color(0x22305068),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(actions.length, (int index) {
              final _RibbonAction action = actions[index];
              return _ActionTile(
                label: action.label,
                onTap: action.onTap,
                width: 66,
                topOffset: yOffsets[index % yOffsets.length],
                gap: 6,
                labelStyle: _labelStyle(
                  context,
                  color: const Color(0xFFE9F3FF),
                  size: 10,
                  weight: FontWeight.w600,
                ),
                button: _roundedShell(
                  width: 52,
                  height: 52,
                  radius: 12,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF8FAACF), Color(0xFF26324A)],
                  ),
                  border: Colors.white.withValues(alpha: 0.52),
                  shadows: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFB7CBF8).withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedTrain(
    BuildContext context,
    List<_RibbonAction> actions,
  ) {
    final TextStyle labelStyle = _labelStyle(
      context,
      color: const Color(0xFFFFF2D8),
      size: 10,
      spacing: 0.55,
    );
    return SizedBox(
      height: 112,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color(0xFF3B2114),
              Color(0xFF7A3C19),
              Color(0xFF3B2114),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFFFD597).withValues(alpha: 0.42),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFCC7B35).withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: List<Widget>.generate(actions.length, (int index) {
            final _RibbonAction action = actions[index];
            final BorderRadius radius = BorderRadius.only(
              topLeft: index == 0 ? const Radius.circular(999) : Radius.zero,
              bottomLeft: index == 0 ? const Radius.circular(999) : Radius.zero,
              topRight: index == actions.length - 1
                  ? const Radius.circular(999)
                  : Radius.zero,
              bottomRight: index == actions.length - 1
                  ? const Radius.circular(999)
                  : Radius.zero,
            );
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: radius,
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border(
                        right: index == actions.length - 1
                            ? BorderSide.none
                            : BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(
                                0xFFFFE5B4,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(action.label, style: labelStyle),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildOrbitNodes(BuildContext context, List<_RibbonAction> actions) {
    final List<double> yOffsets = <double>[0, -4, 2, -4, 0];
    return SizedBox(
      height: 130,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 22,
            right: 22,
            bottom: 42,
            child: Container(
              height: 3,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(actions.length, (int index) {
              final _RibbonAction action = actions[index];
              return _ActionTile(
                label: action.label,
                onTap: action.onTap,
                width: 68,
                topOffset: yOffsets[index % yOffsets.length],
                gap: 7,
                labelStyle: _labelStyle(
                  context,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 10,
                ),
                button: SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      _circleShell(
                        size: 40,
                        gradient: const RadialGradient(
                          colors: <Color>[Color(0xFF78F0FF), Color(0xFF16243F)],
                        ),
                        border: Colors.white.withValues(alpha: 0.62),
                        shadows: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF78F0FF,
                            ).withValues(alpha: 0.18),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketStrip(BuildContext context, List<_RibbonAction> actions) {
    final TextStyle labelStyle = _labelStyle(
      context,
      color: const Color(0xFFF2F5FF),
      size: 10.2,
      weight: FontWeight.w700,
      spacing: 0.35,
    );
    return SizedBox(
      height: 120,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151C2B).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFBCCCF1).withValues(alpha: 0.24),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: List<Widget>.generate(actions.length, (int index) {
            final _RibbonAction action = actions[index];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action.onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF859AC4), Color(0xFF2B3956)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _RibbonAction {
  const _RibbonAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.onTap,
    required this.button,
    required this.width,
    required this.labelStyle,
    this.gap = 8,
    this.topOffset = 0,
  });

  final String label;
  final VoidCallback onTap;
  final Widget button;
  final double width;
  final TextStyle labelStyle;
  final double gap;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, topOffset),
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(child: button),
                SizedBox(height: gap),
                Text(label, textAlign: TextAlign.center, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HexGlowConfig {
  const _HexGlowConfig({
    this.outerRadiusScale = 0.98,
    this.innerRadiusScale = 0.72,
    this.outerOpacity = 0.85,
    this.innerOpacity = 1,
    this.outerBlur = 5,
    this.innerBlur = 2,
  });

  final double outerRadiusScale;
  final double innerRadiusScale;
  final double outerOpacity;
  final double innerOpacity;
  final double outerBlur;
  final double innerBlur;

  _HexGlowConfig copyWith({
    double? outerRadiusScale,
    double? innerRadiusScale,
    double? outerOpacity,
    double? innerOpacity,
    double? outerBlur,
    double? innerBlur,
  }) {
    return _HexGlowConfig(
      outerRadiusScale: outerRadiusScale ?? this.outerRadiusScale,
      innerRadiusScale: innerRadiusScale ?? this.innerRadiusScale,
      outerOpacity: outerOpacity ?? this.outerOpacity,
      innerOpacity: innerOpacity ?? this.innerOpacity,
      outerBlur: outerBlur ?? this.outerBlur,
      innerBlur: innerBlur ?? this.innerBlur,
    );
  }
}

class _RibbonPolygonButtonSpec {
  const _RibbonPolygonButtonSpec({
    required this.label,
    required this.onTap,
    required this.assetPath,
    required this.polygon,
    required this.accentColor,
    required this.fill,
    required this.border,
    required this.imageDeltaXWidthUnits,
    required this.imageDeltaYHeightUnits,
    required this.glowDeltaYHeightUnits,
    required this.imageScaleRatio,
    required this.visualScaleRatio,
    this.showGlow = true,
    this.paintPolygonSurface = true,
    this.contentOffsetYPx = 0,
  });

  final String label;
  final VoidCallback onTap;
  final String assetPath;
  final List<Offset> polygon;
  final Color accentColor;
  final Color fill;
  final Color border;
  final double imageDeltaXWidthUnits;
  final double imageDeltaYHeightUnits;
  final double glowDeltaYHeightUnits;
  final double imageScaleRatio;
  final double visualScaleRatio;
  final bool showGlow;
  final bool paintPolygonSurface;
  final double contentOffsetYPx;
}

class _PolygonRibbonPanel extends StatefulWidget {
  const _PolygonRibbonPanel({
    required this.specs,
    required this.labelStyle,
    required this.panelSize,
  });

  final List<_RibbonPolygonButtonSpec> specs;
  final TextStyle labelStyle;
  final Size panelSize;

  @override
  State<_PolygonRibbonPanel> createState() => _PolygonRibbonPanelState();

  static bool pointInPolygon(Offset p, List<Offset> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final Offset a = polygon[i];
      final Offset b = polygon[j];
      final bool intersect =
          ((a.dy > p.dy) != (b.dy > p.dy)) &&
          (p.dx <
              (b.dx - a.dx) *
                      (p.dy - a.dy) /
                      ((b.dy - a.dy) == 0 ? 1e-9 : (b.dy - a.dy)) +
                  a.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

class _PolygonRibbonPanelState extends State<_PolygonRibbonPanel>
    with SingleTickerProviderStateMixin {
  final Map<String, ui.Image> _imagesByAssetPath = <String, ui.Image>{};
  bool _loadingStarted = false;
  int? _pressedIndex;
  bool _isPointerInsidePressedButton = false;
  late final Ticker _pressTicker;
  Duration? _lastTickElapsed;
  double _pressElapsedSeconds = 0;

  static const double _pressGlowSpeed = 220;
  static const double _pressScaleSpeed = 1.6;

  @override
  void initState() {
    super.initState();
    _pressTicker = createTicker(_onPressTick);
  }

  void _onPressTick(Duration elapsed) {
    if (_lastTickElapsed == null) {
      _lastTickElapsed = elapsed;
      return;
    }
    final double dt =
        (elapsed - _lastTickElapsed!).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastTickElapsed = elapsed;
    if (!mounted || _pressedIndex == null || !_isPointerInsidePressedButton) {
      return;
    }
    setState(() {
      _pressElapsedSeconds += dt;
    });
  }

  void _startPressAnimation() {
    _pressElapsedSeconds = 0;
    _lastTickElapsed = null;
    if (!_pressTicker.isActive) {
      _pressTicker.start();
    }
  }

  void _stopPressAnimation() {
    if (_pressTicker.isActive) {
      _pressTicker.stop();
    }
    _lastTickElapsed = null;
    _pressElapsedSeconds = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadingStarted) {
      return;
    }
    _loadingStarted = true;
    for (final _RibbonPolygonButtonSpec spec in widget.specs) {
      _loadAssetImage(spec.assetPath);
    }
  }

  Future<void> _loadAssetImage(String assetPath) async {
    if (_imagesByAssetPath.containsKey(assetPath)) {
      return;
    }
    ByteData? data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (_) {
      final String fallbackAssetPath = assetPath.replaceFirst('.png', '.jpg');
      try {
        data = await rootBundle.load(fallbackAssetPath);
      } catch (_) {
        return;
      }
    }
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _imagesByAssetPath[assetPath] = frame.image;
    });
  }

  @override
  void dispose() {
    _pressTicker.dispose();
    for (final ui.Image image in _imagesByAssetPath.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (DragDownDetails details) {
        final Offset point = details.localPosition;
        int? pressedIndex;
        for (int index = widget.specs.length - 1; index >= 0; index--) {
          if (_PolygonRibbonPanel.pointInPolygon(
            point,
            widget.specs[index].polygon,
          )) {
            pressedIndex = index;
            break;
          }
        }
        if (pressedIndex != null) {
          _startPressAnimation();
        } else {
          _stopPressAnimation();
        }
        setState(() {
          _pressedIndex = pressedIndex;
          _isPointerInsidePressedButton = pressedIndex != null;
        });
      },
      onPanUpdate: (DragUpdateDetails details) {
        if (_pressedIndex == null) {
          return;
        }
        final bool isInside = _PolygonRibbonPanel.pointInPolygon(
          details.localPosition,
          widget.specs[_pressedIndex!].polygon,
        );
        if (!isInside) {
          _stopPressAnimation();
        } else if (!_pressTicker.isActive) {
          _startPressAnimation();
        }
        setState(() {
          _isPointerInsidePressedButton = isInside;
        });
      },
      onPanEnd: (DragEndDetails details) {
        final int? pressedIndex = _pressedIndex;
        final bool shouldTrigger =
            pressedIndex != null && _isPointerInsidePressedButton;
        _stopPressAnimation();
        setState(() {
          _pressedIndex = null;
          _isPointerInsidePressedButton = false;
        });
        if (shouldTrigger) {
          widget.specs[pressedIndex].onTap();
        }
      },
      onPanCancel: () {
        _stopPressAnimation();
        setState(() {
          _pressedIndex = null;
          _isPointerInsidePressedButton = false;
        });
      },
      child: CustomPaint(
        size: widget.panelSize,
        painter: _PolygonRibbonPainter(
          specs: widget.specs,
          labelStyle: widget.labelStyle,
          textDirection: Directionality.of(context),
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          imagesByAssetPath: _imagesByAssetPath,
          pressedIndex: _isPointerInsidePressedButton ? _pressedIndex : null,
          pressedScale: _isPointerInsidePressedButton
              ? math.min(1.3, 1 + _pressScaleSpeed * _pressElapsedSeconds)
              : 1,
        ),
      ),
    );
  }
}

class _PolygonRibbonPainter extends CustomPainter {
  const _PolygonRibbonPainter({
    required this.specs,
    required this.labelStyle,
    required this.textDirection,
    required this.devicePixelRatio,
    required this.imagesByAssetPath,
    required this.pressedIndex,
    required this.pressedScale,
  });

  final List<_RibbonPolygonButtonSpec> specs;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final double devicePixelRatio;
  final Map<String, ui.Image> imagesByAssetPath;
  final int? pressedIndex;
  final double pressedScale;

  Path _buildHexagonPath(Offset center, double radius) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = -math.pi / 2 + math.pi / 6 + i * math.pi / 3;
      final Offset point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int index = 0; index < specs.length; index++) {
      final _RibbonPolygonButtonSpec spec = specs[index];
      final Path path = Path()..addPolygon(spec.polygon, true);
      if (spec.paintPolygonSurface) {
        canvas.drawPath(path, Paint()..color = spec.fill);
        canvas.drawPath(
          path,
          Paint()
            ..color = spec.border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }

      final double minX = spec.polygon.map((Offset p) => p.dx).reduce(math.min);
      final double maxX = spec.polygon.map((Offset p) => p.dx).reduce(math.max);
      final double minY = spec.polygon.map((Offset p) => p.dy).reduce(math.min);
      final double maxY = spec.polygon.map((Offset p) => p.dy).reduce(math.max);
      final Rect bounds = Rect.fromLTRB(minX, minY, maxX, maxY);

      final ui.Image? image = imagesByAssetPath[spec.assetPath];
      if (image != null) {
        final Rect contentRect = Rect.fromLTRB(
          bounds.left + 6,
          bounds.top + 8,
          bounds.right - 6,
          bounds.bottom - 18,
        );
        final Size adjustedDestinationSize = Size(
          contentRect.width * spec.imageScaleRatio,
          contentRect.height * spec.imageScaleRatio,
        );
        final FittedSizes fitted = applyBoxFit(
          BoxFit.contain,
          Size(image.width.toDouble(), image.height.toDouble()),
          adjustedDestinationSize,
        );
        final Rect inputSubrect = Alignment.center.inscribe(
          fitted.source,
          Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        );
        final Rect baseOutputSubrect = Alignment.center.inscribe(
          fitted.destination,
          contentRect,
        );
        final Rect outputSubrect = baseOutputSubrect.shift(
          Offset(
            spec.imageDeltaXWidthUnits * bounds.width,
            spec.imageDeltaYHeightUnits * bounds.height + spec.contentOffsetYPx,
          ),
        );
        final Offset imageGlowCenter = contentRect.center.translate(
          0,
          spec.glowDeltaYHeightUnits * bounds.height + spec.contentOffsetYPx,
        );
        final double imageGlowRadius =
            math.max(contentRect.width, contentRect.height) *
            0.84 *
            0.78 *
            spec.visualScaleRatio;
        final Offset glowPivot = Offset(
          bounds.center.dx,
          imageGlowCenter.dy + imageGlowRadius * 0.61,
        );
        final double effectiveScale =
            spec.visualScaleRatio * (pressedIndex == index ? pressedScale : 1);
        Matrix4 pivotScaleMatrix(Offset pivot, double scale) {
          return Matrix4.identity()
            ..translate(pivot.dx, pivot.dy)
            ..scale(scale, scale)
            ..translate(-pivot.dx, -pivot.dy);
        }

        if (spec.showGlow) {
          final Path outerHexGlow = _buildHexagonPath(
            imageGlowCenter,
            imageGlowRadius * 0.71,
          );
          final Path innerHexGlow = _buildHexagonPath(
            imageGlowCenter,
            imageGlowRadius * 0.61,
          );
          canvas.save();
          canvas.transform(pivotScaleMatrix(glowPivot, effectiveScale).storage);
          canvas.drawPath(
            outerHexGlow,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.54)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
          canvas.drawPath(
            innerHexGlow,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.74)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0),
          );
          canvas.restore();
        } else {
          final Path outerHex = _buildHexagonPath(
            imageGlowCenter,
            imageGlowRadius * 0.71,
          );
          final Color badgeFill = spec.fill.withValues(
            alpha: math.min(1.0, spec.fill.a + 0.08),
          );
          canvas.save();
          canvas.transform(pivotScaleMatrix(glowPivot, effectiveScale).storage);
          canvas.drawPath(outerHex, Paint()..color = badgeFill);
          canvas.drawPath(
            outerHex,
            Paint()
              ..color = spec.accentColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4,
          );
          canvas.restore();
        }
        canvas.save();
        canvas.clipPath(path);
        canvas.transform(pivotScaleMatrix(glowPivot, effectiveScale).storage);
        canvas.drawImageRect(
          image,
          inputSubrect,
          outputSubrect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonRibbonPainter oldDelegate) {
    return oldDelegate.specs != specs ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.imagesByAssetPath != imagesByAssetPath ||
        oldDelegate.pressedIndex != pressedIndex ||
        oldDelegate.pressedScale != pressedScale;
  }
}

class _SlantedCapsuleClipper extends CustomClipper<Path> {
  const _SlantedCapsuleClipper({required this.slant});

  final double slant;

  @override
  Path getClip(Size size) {
    final double s = slant.clamp(0, size.width / 3);
    final double r = size.height / 2;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - s - r, 0)
      ..quadraticBezierTo(size.width - s, 0, size.width - s * 0.5, r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(s + r, size.height)
      ..quadraticBezierTo(s, size.height, s * 0.5, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SlantedCapsuleClipper oldClipper) {
    return oldClipper.slant != slant;
  }
}
