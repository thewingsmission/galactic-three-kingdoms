import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/triangle_soldier.dart';
import '../widgets/virtual_joystick.dart';

class Pseudo3DScreen extends StatefulWidget {
  const Pseudo3DScreen({super.key});

  @override
  State<Pseudo3DScreen> createState() => _Pseudo3DScreenState();
}

class _Pseudo3DScreenState extends State<Pseudo3DScreen>
    with SingleTickerProviderStateMixin {
  static const double _boardMoveSpeed = 220;

  late final Ticker _ticker;
  Duration? _lastElapsed;
  Offset _joystick = Offset.zero;
  Offset _boardOffset = Offset.zero;
  Size _viewportSize = Size.zero;
  double _anchorWorldY = 0;
  bool _didInitializeBoardOffset = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }

    final double dt =
        (elapsed - _lastElapsed!).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    if (_joystick == Offset.zero || !mounted) return;

    setState(() {
      Offset next = _boardOffset.translate(
        -_joystick.dx * _boardMoveSpeed * dt,
        _joystick.dy * _boardMoveSpeed * dt,
      );
      if (_viewportSize != Size.zero) {
        next = _Pseudo3DBoardPainter.clampOffsetForAnchor(
          next,
          anchorWorldY: _anchorWorldY,
        );
      }
      _boardOffset = next;
    });
  }

  void _onJoystickChanged(Offset value) {
    setState(() => _joystick = value);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _Pseudo3DBackground(),
          SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 16,
                  top: 12,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 14,
                  child: IgnorePointer(
                    child: Text(
                      'Pseudo3D Preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double viewportWidth =
                          math.min(constraints.maxWidth * 0.94, 980);
                      final double viewportHeight =
                          math.min(constraints.maxHeight * 0.72, 540);
                      _viewportSize = Size(viewportWidth, viewportHeight);
                      _anchorWorldY = _Pseudo3DBoardPainter.anchorWorldYForViewport(
                        _viewportSize,
                      );
                      final Offset initialOffset =
                          _Pseudo3DBoardPainter.initialOffsetForViewport(
                        _viewportSize,
                      );
                      if (!_didInitializeBoardOffset) {
                        _didInitializeBoardOffset = true;
                        _boardOffset = initialOffset;
                      }
                      final Offset clampedOffset =
                          _Pseudo3DBoardPainter.clampOffsetForAnchor(
                        _didInitializeBoardOffset ? _boardOffset : initialOffset,
                        anchorWorldY: _anchorWorldY,
                      );

                      return Center(
                        child: SizedBox(
                          width: viewportWidth,
                          height: viewportHeight,
                          child: CustomPaint(
                            painter: _Pseudo3DBoardPainter(
                              boardOffset: clampedOffset,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: TriangleSoldier(
                        size: 72,
                        side: 48,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: SafeArea(
                    child: VirtualJoystick(
                      outerRadius: 56,
                      knobRadius: 24,
                      onChanged: _onJoystickChanged,
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

class _Pseudo3DBackground extends StatelessWidget {
  const _Pseudo3DBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF02040A),
            Color(0xFF081120),
            Color(0xFF010208),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _Pseudo3DStarfieldPainter(),
      ),
    );
  }
}

class _Pseudo3DStarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint faint = Paint()..color = Colors.white.withValues(alpha: 0.28);
    final Paint mid = Paint()..color = const Color(0xFFB8C7FF).withValues(alpha: 0.45);

    const List<Offset> stars = <Offset>[
      Offset(0.04, 0.14),
      Offset(0.1, 0.26),
      Offset(0.18, 0.12),
      Offset(0.22, 0.34),
      Offset(0.3, 0.08),
      Offset(0.35, 0.2),
      Offset(0.4, 0.14),
      Offset(0.48, 0.06),
      Offset(0.54, 0.18),
      Offset(0.61, 0.11),
      Offset(0.67, 0.27),
      Offset(0.74, 0.08),
      Offset(0.82, 0.21),
      Offset(0.9, 0.13),
      Offset(0.95, 0.3),
      Offset(0.08, 0.55),
      Offset(0.16, 0.68),
      Offset(0.28, 0.6),
      Offset(0.42, 0.73),
      Offset(0.56, 0.62),
      Offset(0.7, 0.75),
      Offset(0.84, 0.58),
      Offset(0.92, 0.7),
    ];

    for (int i = 0; i < stars.length; i++) {
      final Offset p = Offset(stars[i].dx * size.width, stars[i].dy * size.height);
      final Paint paint = i.isEven ? faint : mid;
      final double r = i % 4 == 0 ? 1.5 : 1.0;
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pseudo3DBoardPainter extends CustomPainter {
  _Pseudo3DBoardPainter({
    required this.boardOffset,
  });

  final Offset boardOffset;

  static const double _baseRadius = 28;
  static const int _landSideHexes = 12;
  static const double _planeDepthOffset = 860;
  static const double _cameraHeight = 250;
  static const double _cameraPitch = 0.93;
  static const double _focalLength = 420;
  static const double _nearClipZ = 120;
  static const double _hexHalfHeight = _baseRadius * 0.8660254;
  static final double landExtentX =
      _baseRadius * (1 + 1.5 * (_landSideHexes - 1));
  static final double landExtentY =
      math.sqrt(3) * _baseRadius * (_landSideHexes - 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint frame = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, frame);

    final Offset worldOrigin = Offset(
      boardOffset.dx,
      boardOffset.dy,
    );
    final List<_ProjectedHexPolygon> projected = <_ProjectedHexPolygon>[];

    for (final Offset localCenter in _landTileCenters) {
      final Offset worldCenter = localCenter + worldOrigin;
      final _ProjectedHexPolygon? polygon = _projectHex(worldCenter, size);
      if (polygon == null) continue;
      projected.add(
        polygon.copyWith(
          fillColor: _territoryColor(localCenter),
        ),
      );
    }

    projected.sort(
      (_ProjectedHexPolygon a, _ProjectedHexPolygon b) =>
          b.depthT.compareTo(a.depthT),
    );

    for (final _ProjectedHexPolygon polygon in projected) {
      canvas.drawPath(
        polygon.path,
        Paint()..color = polygon.fillColor,
      );
      canvas.drawPath(
        polygon.path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.9, 2.0 * polygon.strokeScale),
      );
    }

  }

  _ProjectedHexPolygon? _projectHex(Offset worldCenter, Size size) {
    final _ProjectedPoint center = _projectPoint(worldCenter, size);
    final List<Offset> localVertices = <Offset>[
      Offset(_baseRadius, 0),
      Offset(_baseRadius * 0.5, _baseRadius * 0.8660254),
      Offset(-_baseRadius * 0.5, _baseRadius * 0.8660254),
      Offset(-_baseRadius, 0),
      Offset(-_baseRadius * 0.5, -_baseRadius * 0.8660254),
      Offset(_baseRadius * 0.5, -_baseRadius * 0.8660254),
    ];

    final List<Offset> projectedVertices = <Offset>[
      for (final Offset local in localVertices)
        _projectPoint(worldCenter + local, size).screen,
    ];

    final Path path = Path()
      ..moveTo(projectedVertices.first.dx, projectedVertices.first.dy);
    for (int i = 1; i < projectedVertices.length; i++) {
      path.lineTo(projectedVertices[i].dx, projectedVertices[i].dy);
    }
    path.close();

    return _ProjectedHexPolygon(
      path: path,
      strokeScale: center.scale,
      depthT: center.depthT,
      fillColor: Colors.transparent,
    );
  }

  _ProjectedPoint _projectPoint(Offset world, Size size) {
    return _projectPointStatic(world.dx, world.dy, size);
  }

  static _ProjectedPoint _projectPointStatic(
    double worldX,
    double worldY,
    Size size,
  ) {
    final double zPlane = worldY + _planeDepthOffset;
    final double cosPitch = math.cos(_cameraPitch);
    final double sinPitch = math.sin(_cameraPitch);

    final double rotatedY = (-_cameraHeight * cosPitch) + (zPlane * sinPitch);
    final double rotatedZ = (_cameraHeight * sinPitch) + (zPlane * cosPitch);
    final double safeZ = math.max(rotatedZ, _nearClipZ);
    final double scale = _focalLength / safeZ;

    final double screenX = size.width / 2 + worldX * scale;
    final double screenY = size.height * 1.02 - rotatedY * scale;
    return _ProjectedPoint(
      screen: Offset(screenX, screenY),
      scale: scale,
      depthT: safeZ,
    );
  }

  Color _territoryColor(Offset center) {
    final Offset n = Offset(
      (center.dx / (landExtentX * 2)) + 0.5,
      (center.dy / (landExtentY * 2)) + 0.5,
    );

    double score(Offset seed, double weight) {
      final double dx = n.dx - seed.dx;
      final double dy = n.dy - seed.dy;
      final double distance2 = dx * dx + dy * dy;
      return weight - distance2;
    }

    final double red =
        score(const Offset(0.16, 0.38), 0.9) + math.sin(n.dy * 9.5) * 0.03;
    final double yellow =
        score(const Offset(0.5, 0.48), 0.86) + math.cos((n.dx + n.dy) * 8.5) * 0.035;
    final double blue =
        score(const Offset(0.82, 0.42), 0.92) + math.sin(n.dx * 10.0) * 0.03;

    if (red >= yellow && red >= blue) return const Color(0xFFD65122);
    if (yellow >= red && yellow >= blue) return const Color(0xFFE2BD10);
    return const Color(0xFF5C8FA6);
  }

  static Offset clampOffsetForAnchor(
    Offset offset, {
    required double anchorWorldY,
  }) {
    final Offset anchorLocal = Offset(-offset.dx, anchorWorldY - offset.dy);
    final Offset boundaryProbe = anchorLocal.translate(0, -_hexHalfHeight);
    final Offset clampedProbe = _clampPointToLand(boundaryProbe);
    if ((clampedProbe - boundaryProbe).distanceSquared < 0.0001) {
      return offset;
    }
    final Offset clampedLocal = clampedProbe.translate(0, _hexHalfHeight);
    return Offset(-clampedLocal.dx, anchorWorldY - clampedLocal.dy);
  }

  static Offset initialOffsetForViewport(Size viewport) {
    if (viewport == Size.zero) return Offset.zero;
    return Offset(0, anchorWorldYForViewport(viewport));
  }

  static double anchorWorldYForViewport(Size viewport) {
    final double targetY = viewport.height / 2;
    double low = -landExtentY;
    double high = landExtentY;
    final bool increasing =
        _projectScreenYForWorldY(high, viewport) > _projectScreenYForWorldY(low, viewport);

    for (int i = 0; i < 28; i++) {
      final double mid = (low + high) / 2;
      final double value = _projectScreenYForWorldY(mid, viewport);
      if ((value < targetY) == increasing) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return (low + high) / 2;
  }

  static double _projectScreenYForWorldY(double worldY, Size viewport) {
    return _projectPointStatic(0, worldY, viewport).screen.dy;
  }

  static Offset _clampPointToLand(Offset point) {
    if (_isPointInsideLand(point)) return point;

    Offset bestPoint = _landTileCenters.first;
    double bestDistance2 = double.infinity;

    for (final Offset center in _landTileCenters) {
      final List<Offset> vertices = _hexVerticesForCenter(center);
      for (int i = 0; i < vertices.length; i++) {
        final Offset a = vertices[i];
        final Offset b = vertices[(i + 1) % vertices.length];
        final Offset candidate = _nearestPointOnSegment(point, a, b);
        final double distance2 = (candidate - point).distanceSquared;
        if (distance2 < bestDistance2) {
          bestDistance2 = distance2;
          bestPoint = candidate;
        }
      }
    }

    return bestPoint;
  }

  static bool _isPointInsideLand(Offset point) {
    for (final Offset center in _landTileCenters) {
      if (_isPointInsideHex(point, center)) return true;
    }
    return false;
  }

  static bool _isPointInsideHex(Offset point, Offset center) {
    final Offset p = point - center;
    final double x = p.dx.abs();
    final double y = p.dy.abs();

    if (x > _baseRadius || y > _hexHalfHeight) return false;
    return (1.7320508 * x + y) <= (1.7320508 * _baseRadius);
  }

  static List<Offset> _hexVerticesForCenter(Offset center) {
    return <Offset>[
      center + Offset(_baseRadius, 0),
      center + Offset(_baseRadius * 0.5, _hexHalfHeight),
      center + Offset(-_baseRadius * 0.5, _hexHalfHeight),
      center + Offset(-_baseRadius, 0),
      center + Offset(-_baseRadius * 0.5, -_hexHalfHeight),
      center + Offset(_baseRadius * 0.5, -_hexHalfHeight),
    ];
  }

  static Offset _nearestPointOnSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double length2 = ab.distanceSquared;
    if (length2 == 0) return a;

    final double t = (((p.dx - a.dx) * ab.dx) + ((p.dy - a.dy) * ab.dy)) / length2;
    final double clampedT = t.clamp(0.0, 1.0);
    return Offset(
      a.dx + ab.dx * clampedT,
      a.dy + ab.dy * clampedT,
    );
  }


  @override
  bool shouldRepaint(covariant _Pseudo3DBoardPainter oldDelegate) {
    return oldDelegate.boardOffset != boardOffset;
  }

  static final List<Offset> _landTileCenters = _buildLandTileCenters();

  static List<Offset> _buildLandTileCenters() {
    final int radius = _landSideHexes - 1;
    final List<Offset> centers = <Offset>[];
    for (int q = -radius; q <= radius; q++) {
      final int rMin = math.max(-radius, -q - radius);
      final int rMax = math.min(radius, -q + radius);
      for (int r = rMin; r <= rMax; r++) {
        centers.add(
          Offset(
            _baseRadius * 1.5 * q,
            _baseRadius * math.sqrt(3) * (r + q / 2),
          ),
        );
      }
    }
    return centers;
  }
}

class _ProjectedPoint {
  const _ProjectedPoint({
    required this.screen,
    required this.scale,
    required this.depthT,
  });

  final Offset screen;
  final double scale;
  final double depthT;
}

class _ProjectedHexPolygon {
  const _ProjectedHexPolygon({
    required this.path,
    required this.strokeScale,
    required this.depthT,
    required this.fillColor,
  });

  final Path path;
  final double strokeScale;
  final double depthT;
  final Color fillColor;

  _ProjectedHexPolygon copyWith({
    Path? path,
    double? strokeScale,
    double? depthT,
    Color? fillColor,
  }) {
    return _ProjectedHexPolygon(
      path: path ?? this.path,
      strokeScale: strokeScale ?? this.strokeScale,
      depthT: depthT ?? this.depthT,
      fillColor: fillColor ?? this.fillColor,
    );
  }
}

