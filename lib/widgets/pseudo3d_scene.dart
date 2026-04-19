import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

export '../models/level4_war_vfx.dart';

import '../models/cell_core_palette.dart';
import '../models/hex_cell_preview_style.dart';
import '../models/level4_war_vfx.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
import 'hex_cell_preview_layout.dart';
import 'hex_cell_styles_paint.dart';
import 'multi_polygon_soldier_painter.dart';
import 'soldier_design_catalog.dart';

class Pseudo3DScene extends StatefulWidget {
  const Pseudo3DScene({
    super.key,
    this.meshMode = Pseudo3DMeshMode.solid,
    this.boardBottomInset = 0,
    this.viewportHeightFactor = 0.72,
    this.maxViewportHeight = 540,
    this.viewportWidthFactor = 0.94,
    this.maxViewportWidth = 980,
    this.cellVisualStyle = HexCellPreviewStyle.defaultStyle,
  });

  final Pseudo3DMeshMode meshMode;
  final double boardBottomInset;
  final double viewportHeightFactor;
  final double maxViewportHeight;
  final double viewportWidthFactor;
  final double maxViewportWidth;
  final HexCellPreviewStyle cellVisualStyle;

  @override
  State<Pseudo3DScene> createState() => _Pseudo3DSceneState();
}

enum Pseudo3DMeshMode {
  solid,
  outlineTransparent,
  outlineHalfTransparent,
}

class _Pseudo3DSceneState extends State<Pseudo3DScene>
    with SingleTickerProviderStateMixin {
  static const double _boardMoveSpeed = 220;
  static const double _soldierMotionCycleSeconds = 1.4;
  static const double _soldierAnchorScreenYOffsetFactor = 0.15;
  static const double _markerBoxSize = 84;
  static const double _touchHoldControlRadius = 110;
  static const double _minZoom = 0.7;
  static const double _maxZoom = 1.8;
  static const double _keyboardZoomStep = 0.08;

  late final Ticker _ticker;
  late final FocusNode _keyboardFocusNode;
  Duration? _lastElapsed;
  Offset _movementVector = Offset.zero;
  Offset _boardOffset = Offset.zero;
  Size _viewportSize = Size.zero;
  Size _sceneSize = Size.zero;
  double _shadowAnchorWorldY = 0;
  double _soldierMotionT = 0;
  double _effectT = 0;
  double _zoom = 1;
  double _gestureStartZoom = 1;
  double _latestBoardLayoutHeight = 0;
  int _activePointerCount = 0;
  bool _didInitializeBoardOffset = false;
  bool _yellowSlimeFramesLoadingStarted = false;
  final List<ui.Image> _yellowSlimeFrames = <ui.Image>[];
  bool _fireYellowFramesLoadingStarted = false;
  final List<ui.Image> _fireYellowFrames = <ui.Image>[];
  bool _tornadoRedFramesLoadingStarted = false;
  final List<ui.Image> _tornadoRedFrames = <ui.Image>[];
  bool _tornadoIceFramesLoadingStarted = false;
  final List<ui.Image> _tornadoIceFrames = <ui.Image>[];
  bool _redSlimeFramesLoadingStarted = false;
  final List<ui.Image> _redSlimeFrames = <ui.Image>[];
  bool _blueSlimeFramesLoadingStarted = false;
  final List<ui.Image> _blueSlimeFrames = <ui.Image>[];
  bool _tigerLoseLoadingStarted = false;
  ui.Image? _tigerLoseImage;
  bool _tigerWinLoadingStarted = false;
  ui.Image? _tigerWinImage;
  bool _eagleLoseLoadingStarted = false;
  ui.Image? _eagleLoseImage;
  bool _eagleWinLoadingStarted = false;
  ui.Image? _eagleWinImage;
  bool _dragonLoseLoadingStarted = false;
  ui.Image? _dragonLoseImage;
  bool _dragonWinLoadingStarted = false;
  ui.Image? _dragonWinImage;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode = FocusNode(debugLabel: 'Pseudo3DSceneKeyboardFocus');
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_yellowSlimeFramesLoadingStarted) {
      _yellowSlimeFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/slime yellow ',
        suffix: '.png',
        target: _yellowSlimeFrames,
      );
    }
    if (!_redSlimeFramesLoadingStarted) {
      _redSlimeFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/slime red ',
        suffix: '.png',
        target: _redSlimeFrames,
      );
    }
    if (!_blueSlimeFramesLoadingStarted) {
      _blueSlimeFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/slime blue ',
        suffix: '.png',
        target: _blueSlimeFrames,
      );
    }
    if (!_fireYellowFramesLoadingStarted) {
      _fireYellowFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/fire yellow ',
        suffix: '.png',
        target: _fireYellowFrames,
        frameCount: 6,
      );
    }
    if (!_tornadoRedFramesLoadingStarted) {
      _tornadoRedFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/tornado red ',
        suffix: '.png',
        target: _tornadoRedFrames,
        frameCount: 6,
      );
    }
    if (!_tornadoIceFramesLoadingStarted) {
      _tornadoIceFramesLoadingStarted = true;
      _loadFrames(
        prefix: 'image/ice blue ',
        suffix: '.png',
        target: _tornadoIceFrames,
        frameCount: 6,
      );
    }
    if (!_tigerLoseLoadingStarted) {
      _tigerLoseLoadingStarted = true;
      _loadTigerLose();
    }
    if (!_tigerWinLoadingStarted) {
      _tigerWinLoadingStarted = true;
      _loadTigerWin();
    }
    if (!_eagleLoseLoadingStarted) {
      _eagleLoseLoadingStarted = true;
      _loadEagleLose();
    }
    if (!_eagleWinLoadingStarted) {
      _eagleWinLoadingStarted = true;
      _loadEagleWin();
    }
    if (!_dragonLoseLoadingStarted) {
      _dragonLoseLoadingStarted = true;
      _loadDragonLose();
    }
    if (!_dragonWinLoadingStarted) {
      _dragonWinLoadingStarted = true;
      _loadDragonWin();
    }
  }

  Future<void> _loadFrames({
    required String prefix,
    required String suffix,
    required List<ui.Image> target,
    int frameCount = 9,
  }) async {
    final List<ui.Image> loaded = <ui.Image>[];
    for (int i = 1; i <= frameCount; i++) {
      try {
        final ByteData data = await rootBundle.load('$prefix$i$suffix');
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        loaded.add(frame.image);
      } catch (_) {
        for (final ui.Image image in loaded) {
          image.dispose();
        }
        return;
      }
    }
    if (!mounted) {
      for (final ui.Image image in loaded) {
        image.dispose();
      }
      return;
    }
    setState(() {
      target.addAll(loaded);
    });
  }

  Future<void> _loadTigerLose() async {
    try {
      final ByteData data = await rootBundle.load('image/tiger_lose.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _tigerLoseImage?.dispose();
        _tigerLoseImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/tiger_lose.png: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadTigerWin() async {
    try {
      final ByteData data = await rootBundle.load('image/tiger_win.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _tigerWinImage?.dispose();
        _tigerWinImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/tiger_win.png: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadEagleWin() async {
    try {
      final ByteData data = await rootBundle.load('image/eagle_win.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _eagleWinImage?.dispose();
        _eagleWinImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/eagle_win.png: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadEagleLose() async {
    try {
      final ByteData data = await rootBundle.load('image/eagle_lose.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _eagleLoseImage?.dispose();
        _eagleLoseImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/eagle_lose.png: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadDragonWin() async {
    try {
      final ByteData data = await rootBundle.load('image/dragon_win.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _dragonWinImage?.dispose();
        _dragonWinImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/dragon_win.png: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _loadDragonLose() async {
    try {
      final ByteData data = await rootBundle.load('image/dragon_lose.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _dragonLoseImage?.dispose();
        _dragonLoseImage = frame.image;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Pseudo3DScene: failed loading image/dragon_lose.png: $e');
        debugPrint('$st');
      }
    }
  }

  void _tick(Duration elapsed) {
    final double elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final double nextMotionT =
        (elapsedSeconds / _soldierMotionCycleSeconds) % 1.0;

    if (_lastElapsed == null) {
      setState(() {
        _soldierMotionT = nextMotionT;
        _effectT = elapsedSeconds;
      });
      _lastElapsed = elapsed;
      return;
    }

    final double dt =
        (elapsed - _lastElapsed!).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    setState(() {
      _soldierMotionT = nextMotionT;
      _effectT = elapsedSeconds;

      if (_movementVector != Offset.zero && mounted) {
        final Offset proposed = _boardOffset.translate(
          -_movementVector.dx * _boardMoveSpeed * dt,
          _movementVector.dy * _boardMoveSpeed * dt,
        );
        if (_viewportSize != Size.zero) {
          _boardOffset = _Pseudo3DBoardPainter.clampOffsetForLocalAnchor(
            currentOffset: _boardOffset,
            proposedOffset: proposed,
            anchorWorldY: _shadowAnchorWorldY,
            hexGap: 0,
            zoom: _zoom,
          );
        } else {
          _boardOffset = proposed;
        }
      }
    });
  }

  void _beginTouchHoldMovement(Offset localPosition, Size size) {
    _updateTouchHoldVector(localPosition, size);
  }

  void _updateTouchHoldMovement(Offset localPosition, Size size) {
    _updateTouchHoldVector(localPosition, size);
  }

  void _endTouchHoldMovement() {
    setState(() => _movementVector = Offset.zero);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final bool isPinchZoom =
        _activePointerCount >= 2 && (details.scale - 1).abs() > 0.01;
    if (isPinchZoom) {
      _setZoom(_gestureStartZoom * details.scale);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_activePointerCount == 0) {
      _endTouchHoldMovement();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointerCount += 1;
    if (_activePointerCount == 1) {
      _beginTouchHoldMovement(event.localPosition, _sceneSize);
    } else {
      _endTouchHoldMovement();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointerCount == 1) {
      _updateTouchHoldMovement(event.localPosition, _sceneSize);
    }
  }

  void _onPointerEnd() {
    _activePointerCount = math.max(0, _activePointerCount - 1);
    if (_activePointerCount == 0) {
      _endTouchHoldMovement();
    }
  }

  void _setZoom(double value) {
    final double clampedZoom = value.clamp(_minZoom, _maxZoom);
    if ((clampedZoom - _zoom).abs() < 1e-6) {
      return;
    }
    setState(() {
      final Offset currentLocalAnchor = Offset(
        -_boardOffset.dx,
        _shadowAnchorWorldY - _boardOffset.dy,
      );
      _zoom = clampedZoom;
      if (_viewportSize != Size.zero && _latestBoardLayoutHeight > 0) {
        final double totalScreenHeight =
            _latestBoardLayoutHeight + widget.boardBottomInset;
        final double shadowCenterScreenY =
            totalScreenHeight / 2 +
            totalScreenHeight * _soldierAnchorScreenYOffsetFactor +
            _ProductionJollyCircleMarker.shadowCenterOffsetFromMarkerCenter(
                  _markerBoxSize,
                ) *
                _zoom;
        final double viewportTop = (_latestBoardLayoutHeight - _viewportSize.height) / 2;
        final double shadowCenterViewportY = shadowCenterScreenY - viewportTop;
        _shadowAnchorWorldY = _Pseudo3DBoardPainter.anchorWorldYForViewport(
          _viewportSize,
          targetScreenY: shadowCenterViewportY,
          hexGap: 0,
          zoom: _zoom,
        );
        _boardOffset = Offset(
          -currentLocalAnchor.dx,
          _shadowAnchorWorldY - currentLocalAnchor.dy,
        );
        _boardOffset = _Pseudo3DBoardPainter.clampOffsetForLocalAnchor(
          currentOffset: _boardOffset,
          proposedOffset: _boardOffset,
          anchorWorldY: _shadowAnchorWorldY,
          hexGap: 0,
          zoom: _zoom,
        );
      }
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      _setZoom(_zoom - _keyboardZoomStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.logicalKey == LogicalKeyboardKey.add) {
      _setZoom(_zoom + _keyboardZoomStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _updateTouchHoldVector(Offset localPosition, Size size) {
    final Offset shadowCenter = _shadowCenterInScene(size);
    Offset delta = localPosition - shadowCenter;
    if (delta.distance > _touchHoldControlRadius && delta.distance > 0) {
      delta = delta * (_touchHoldControlRadius / delta.distance);
    }
    setState(() {
      _movementVector = Offset(
        delta.dx / _touchHoldControlRadius,
        delta.dy / _touchHoldControlRadius,
      );
    });
  }

  Offset _shadowCenterInScene(Size size) {
    final double totalScreenHeight = size.height + widget.boardBottomInset;
    return Offset(
      size.width / 2,
      totalScreenHeight / 2 +
          totalScreenHeight * _soldierAnchorScreenYOffsetFactor +
          _ProductionJollyCircleMarker.shadowCenterOffsetFromMarkerCenter(
                _markerBoxSize,
              ) *
              _zoom,
    );
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _ticker.dispose();
    for (final ui.Image image in _yellowSlimeFrames) {
      image.dispose();
    }
    for (final ui.Image image in _fireYellowFrames) {
      image.dispose();
    }
    for (final ui.Image image in _redSlimeFrames) {
      image.dispose();
    }
    for (final ui.Image image in _blueSlimeFrames) {
      image.dispose();
    }
    _tigerLoseImage?.dispose();
    _tigerWinImage?.dispose();
    _eagleLoseImage?.dispose();
    _eagleWinImage?.dispose();
    _dragonLoseImage?.dispose();
    _dragonWinImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _keyboardFocusNode,
      onKeyEvent: (_, KeyEvent event) => _handleKeyEvent(event),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          _sceneSize = size;

          final double boardLayoutHeight = math.max(
            0.0,
            constraints.maxHeight - widget.boardBottomInset,
          );
          _latestBoardLayoutHeight = boardLayoutHeight;
          final double viewportWidth = math.min(
            constraints.maxWidth * widget.viewportWidthFactor,
            widget.maxViewportWidth,
          );
          final double viewportHeight = math.min(
            boardLayoutHeight * widget.viewportHeightFactor,
            widget.maxViewportHeight,
          );
          _viewportSize = Size(viewportWidth, viewportHeight);

          final double totalScreenHeight = constraints.maxHeight;
          final double shadowCenterScreenY =
              totalScreenHeight / 2 +
              totalScreenHeight * _soldierAnchorScreenYOffsetFactor +
              _ProductionJollyCircleMarker.shadowCenterOffsetFromMarkerCenter(
                    _markerBoxSize,
                  ) *
                  _zoom;
          final double viewportTop = (boardLayoutHeight - viewportHeight) / 2;
          final double shadowCenterViewportY = shadowCenterScreenY - viewportTop;

          _shadowAnchorWorldY = _Pseudo3DBoardPainter.anchorWorldYForViewport(
            _viewportSize,
            targetScreenY: shadowCenterViewportY,
            hexGap: 0,
            zoom: _zoom,
          );
          final Offset initialOffset =
              _Pseudo3DBoardPainter.initialOffsetForViewport(
            _viewportSize,
            targetScreenY: shadowCenterViewportY,
            hexGap: 0,
            zoom: _zoom,
          );
          if (!_didInitializeBoardOffset) {
            _didInitializeBoardOffset = true;
            _boardOffset = initialOffset;
          }
          final Offset clampedOffset = _Pseudo3DBoardPainter.clampOffsetForLocalAnchor(
            currentOffset: _didInitializeBoardOffset ? _boardOffset : initialOffset,
            proposedOffset: _didInitializeBoardOffset ? _boardOffset : initialOffset,
            anchorWorldY: _shadowAnchorWorldY,
            hexGap: 0,
            zoom: _zoom,
          );
          _boardOffset = clampedOffset;

          final Widget sceneStack = Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: widget.boardBottomInset,
                child: Center(
                  child: SizedBox(
                    width: viewportWidth,
                    height: viewportHeight,
                    child: CustomPaint(
                      painter: _Pseudo3DBoardPainter(
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        cellVisualStyle: widget.cellVisualStyle,
                        yellowSlimeFrames: _yellowSlimeFrames,
                        fireYellowFrames: _fireYellowFrames,
                        tornadoRedFrames: _tornadoRedFrames,
                        tornadoIceFrames: _tornadoIceFrames,
                        redSlimeFrames: _redSlimeFrames,
                        blueSlimeFrames: _blueSlimeFrames,
                        tigerLoseImage: _tigerLoseImage,
                        tigerWinImage: _tigerWinImage,
                        eagleLoseImage: _eagleLoseImage,
                        eagleWinImage: _eagleWinImage,
                        dragonLoseImage: _dragonLoseImage,
                        dragonWinImage: _dragonWinImage,
                        paintLayer: _BoardPaintLayer.hexMesh,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        constraints.maxHeight * _soldierAnchorScreenYOffsetFactor,
                      ),
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _markerBoxSize,
                          height: _markerBoxSize,
                          child: const _ProductionJollyCircleShadow(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: widget.boardBottomInset,
                child: Center(
                  child: SizedBox(
                    width: viewportWidth,
                    height: viewportHeight,
                    child: CustomPaint(
                      painter: _Pseudo3DBoardPainter(
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        cellVisualStyle: widget.cellVisualStyle,
                        yellowSlimeFrames: _yellowSlimeFrames,
                        fireYellowFrames: _fireYellowFrames,
                        tornadoRedFrames: _tornadoRedFrames,
                        tornadoIceFrames: _tornadoIceFrames,
                        redSlimeFrames: _redSlimeFrames,
                        blueSlimeFrames: _blueSlimeFrames,
                        tigerLoseImage: _tigerLoseImage,
                        tigerWinImage: _tigerWinImage,
                        eagleLoseImage: _eagleLoseImage,
                        eagleWinImage: _eagleWinImage,
                        dragonLoseImage: _dragonLoseImage,
                        dragonWinImage: _dragonWinImage,
                        paintLayer: _BoardPaintLayer.warEffects,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        constraints.maxHeight * _soldierAnchorScreenYOffsetFactor,
                      ),
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _markerBoxSize,
                          height: _markerBoxSize,
                          child: _ProductionJollyCircleBody(
                            motionT: _soldierMotionT,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (PointerDownEvent event) {
              if (!_keyboardFocusNode.hasFocus) {
                _keyboardFocusNode.requestFocus();
              }
              _onPointerDown(event);
            },
            onPointerMove: _onPointerMove,
            onPointerUp: (_) => _onPointerEnd(),
            onPointerCancel: (_) => _onPointerEnd(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!_keyboardFocusNode.hasFocus) {
                  _keyboardFocusNode.requestFocus();
                }
              },
              onScaleStart: _onScaleStart,
              onScaleUpdate: (ScaleUpdateDetails details) =>
                  _onScaleUpdate(details, size),
              onScaleEnd: _onScaleEnd,
              child: sceneStack,
            ),
          );
        },
      ),
    );
  }
}

class _ProductionJollyCircleMarker {
  _ProductionJollyCircleMarker._();

  static final SoldierDesign _design = kProductionSoldierDesignCatalog[5];
  static const double _anchorMotionT = 0.25;
  static final _RoleBottomMetrics _contactBottom = _bottomMetricsForRole(
    SoldierPartStackRole.contact,
  );
  static final _RoleBottomMetrics _targetBottom = _bottomMetricsForRole(
    SoldierPartStackRole.target,
  );

  static double shadowCenterOffsetFromMarkerCenter(double markerBoxSize) {
    final double size = markerBoxSize * 0.39;
    final double scale = size / _design.paintSize;
    final double targetBottomDeltaY =
        (_targetBottom.point.dy - _contactBottom.point.dy) * scale;
    final double shadowDiameter = size * 1.05;
    return targetBottomDeltaY + shadowDiameter / 6;
  }

  static _RoleBottomMetrics _bottomMetricsForRole(SoldierPartStackRole role) {
    final List<Offset> points = <Offset>[];
    for (final SoldierShapePart part in _design.parts) {
      if (part.stackRole != role) continue;
      final List<Offset>? fill = MultiPolygonSoldierPainter.transformedFillVertices(
        part,
        _anchorMotionT,
        null,
      );
      if (fill != null) {
        points.addAll(fill);
      }
    }

    if (points.isEmpty) {
      return const _RoleBottomMetrics(point: Offset.zero);
    }

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double maxY = points.first.dy;
    for (final Offset p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    return _RoleBottomMetrics(
      point: Offset((minX + maxX) / 2, maxY),
    );
  }
}

class _ProductionJollyCircleShadow extends StatelessWidget {
  const _ProductionJollyCircleShadow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.39;
        final double scale = size / _ProductionJollyCircleMarker._design.paintSize;
        final Offset contactBottomScreen = Offset(size / 2, size / 2);
        final Offset targetBottomScreen = Offset(
          contactBottomScreen.dx +
              (_ProductionJollyCircleMarker._targetBottom.point.dx -
                      _ProductionJollyCircleMarker._contactBottom.point.dx) *
                  scale,
          contactBottomScreen.dy +
              (_ProductionJollyCircleMarker._targetBottom.point.dy -
                      _ProductionJollyCircleMarker._contactBottom.point.dy) *
                  scale,
        );
        final double shadowDiameter = size * 1.05;
        final Offset shadowOffsetFromCenter = Offset(
          0,
          targetBottomScreen.dy + shadowDiameter / 6 - size / 2,
        );

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            Transform.translate(
              offset: shadowOffsetFromCenter,
              child: Transform.scale(
                scaleY: 1 / 3,
                alignment: Alignment.center,
                child: Container(
                  width: shadowDiameter,
                  height: shadowDiameter,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductionJollyCircleBody extends StatelessWidget {
  const _ProductionJollyCircleBody({
    required this.motionT,
  });
  final double motionT;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.39;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: MultiPolygonSoldierPainter(
              parts: _ProductionJollyCircleMarker._design.parts,
              displayPalette: SoldierDesignPalette.yellow,
              strokeWidth: _ProductionJollyCircleMarker._design.strokeWidth,
              motionT: motionT,
              uniformWorldScale: size / _ProductionJollyCircleMarker._design.paintSize,
              fixedModelAnchor: _ProductionJollyCircleMarker._contactBottom.point,
            ),
          ),
        );
      },
    );
  }
}

class _RoleBottomMetrics {
  const _RoleBottomMetrics({
    required this.point,
  });

  final Offset point;
}

/// Hex fills/outline vs war VFX must composite in separate layers so the shadow
/// widget can sit between mesh and slime overlays.
enum _BoardPaintLayer {
  hexMesh,
  warEffects,
}

class _Pseudo3DBoardPainter extends CustomPainter {
  _Pseudo3DBoardPainter({
    required this.boardOffset,
    required this.meshMode,
    required this.zoom,
    required this.effectT,
    required this.cellVisualStyle,
    required this.yellowSlimeFrames,
    required this.fireYellowFrames,
    required this.tornadoRedFrames,
    required this.tornadoIceFrames,
    required this.redSlimeFrames,
    required this.blueSlimeFrames,
    required this.tigerLoseImage,
    required this.tigerWinImage,
    required this.eagleLoseImage,
    required this.eagleWinImage,
    required this.dragonLoseImage,
    required this.dragonWinImage,
    required this.paintLayer,
  });

  final Offset boardOffset;
  final Pseudo3DMeshMode meshMode;
  final double zoom;
  final double effectT;
  final HexCellPreviewStyle cellVisualStyle;
  final List<ui.Image> yellowSlimeFrames;
  final List<ui.Image> fireYellowFrames;
  final List<ui.Image> tornadoRedFrames;
  final List<ui.Image> tornadoIceFrames;
  final List<ui.Image> redSlimeFrames;
  final List<ui.Image> blueSlimeFrames;
  final ui.Image? tigerLoseImage;
  final ui.Image? tigerWinImage;
  final ui.Image? eagleLoseImage;
  final ui.Image? eagleWinImage;
  final ui.Image? dragonLoseImage;
  final ui.Image? dragonWinImage;
  final _BoardPaintLayer paintLayer;

  static bool _isWinBattleEffect(Level4UnitDesign design) {
    return design == Level4UnitDesign.yWin ||
        design == Level4UnitDesign.rWin ||
        design == Level4UnitDesign.bWin;
  }

  /// Win clips: 6 frames × 3 loops; Lose clips: 9 frames × 2 loops → LCM = 18 steps.
  static const double _level4FrameDurationSec = 0.15 / 0.75;
  static const int _level4SyncedSteps = 18;
  static const double _level4PauseSec = 1.2;
  static const double _level4ScaleInDurationSec = 0.22;
  static const double _level4ScaleOutDurationSec = 0.22;

  /// 0→1 at cycle start, 1→0 before pause; scales around [pivotScreen].
  static double _level4VisibilityScale(
    double tInActive,
    double activeDuration,
  ) {
    if (tInActive < _level4ScaleInDurationSec) {
      final double u =
          (tInActive / _level4ScaleInDurationSec).clamp(0.0, 1.0);
      return Curves.easeOut.transform(u);
    }
    if (tInActive > activeDuration - _level4ScaleOutDurationSec) {
      final double u = ((activeDuration - tInActive) / _level4ScaleOutDurationSec)
          .clamp(0.0, 1.0);
      return Curves.easeIn.transform(u);
    }
    return 1.0;
  }

  /// Full `src` rect for [Canvas.drawImageRect]: texture local position (0,0),
  /// size = image pixel dimensions. All war VFX sprites use this (no cropped src).
  static Rect _imageSrcRectAtLocalOrigin(ui.Image image) {
    return Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  }

  static const double _fixedInnerScale = 0.847;

  static const double _baseRadius = 28;
  static const int _landSideHexes = 25;
  static const double _planeDepthOffset = 860;
  static const double _cameraHeight = 250;
  static const double _cameraPitch = 0.93;
  static const double _focalLength = 420;
  static const double _nearClipZ = 120;
  static const double _hexHalfHeight = _baseRadius * 0.8660254;
  static final double landExtentY =
      math.sqrt(3) * _baseRadius * (_landSideHexes - 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset worldOrigin = Offset(boardOffset.dx, boardOffset.dy);
    final List<_ProjectedHexPolygon> projected = <_ProjectedHexPolygon>[];

    for (final Offset localCenter in _baseLandTileCenters) {
      final Offset worldCenter = localCenter + worldOrigin;
      final _ProjectedHexPolygon? polygon = _projectHex(worldCenter, size);
      if (polygon == null) continue;
      final int level = _strengthLevel(localCenter);
      final SoldierDesignPalette faction = _territoryFaction(localCenter);
      projected.add(
        polygon.copyWith(
          fillColor: _territoryOuterColor(localCenter),
          innerColor: _territoryInnerColor(localCenter),
          level: level,
          localCenter: localCenter,
          faction: faction,
          isWarCell: _isWarCell(localCenter, faction),
        ),
      );
    }

    projected.sort(
      (_ProjectedHexPolygon a, _ProjectedHexPolygon b) =>
          b.depthT.compareTo(a.depthT),
    );

    for (final _ProjectedHexPolygon polygon in projected) {
      if (paintLayer == _BoardPaintLayer.hexMesh) {
        final Path innerPath = _buildScaledInnerPath(
          polygon.path,
          polygon.center,
          _fixedInnerScale,
        );
        final Path fillPath = switch (meshMode) {
          Pseudo3DMeshMode.outlineTransparent =>
            Path.combine(PathOperation.difference, polygon.path, innerPath),
          Pseudo3DMeshMode.outlineHalfTransparent =>
            Path.combine(PathOperation.difference, polygon.path, innerPath),
          _ => polygon.path,
        };

        if (cellVisualStyle.usesVariantPaint &&
            meshMode != Pseudo3DMeshMode.solid) {
          final SoldierDesignPalette faction =
              polygon.faction ?? SoldierDesignPalette.red;
          final CellCorePalette palette = CellCorePalette.fromTerritoryField(
            faction: faction,
            strengthLevel: polygon.level,
          );
          HexCellStylesPaint.paintProjectedCell(
            canvas,
            style: cellVisualStyle,
            palette: palette,
            center: polygon.center,
            outerVertices: polygon.outerVertices,
            outerRadius: polygon.outerRadius,
            strokeScale: polygon.strokeScale,
            boardEffectTimeSec: effectT,
            boardFaction: faction,
          );
          HexCellPreviewLayout.paintUnifiedHexOutline(
            canvas,
            polygon.path,
            polygon.strokeScale,
          );
        } else {
          final SoldierDesignPalette faction =
              polygon.faction ?? SoldierDesignPalette.red;
          final CellCorePalette pal = CellCorePalette.fromTerritoryField(
            faction: faction,
            strengthLevel: polygon.level,
          );
          Color fillColor = polygon.fillColor;
          if (cellVisualStyle == HexCellPreviewStyle.l1) {
            fillColor = pal.componentIndex1;
          }
          canvas.drawPath(
            fillPath,
            Paint()..color = fillColor,
          );
          if (meshMode == Pseudo3DMeshMode.outlineHalfTransparent) {
            canvas.drawPath(
              innerPath,
              Paint()..color = pal.innerHexHolePaint,
            );
          }
          HexCellPreviewLayout.paintUnifiedHexOutline(
            canvas,
            polygon.path,
            polygon.strokeScale,
          );
        }
      } else if (polygon.isWarCell && _shouldShowBoundaryWarVfx(polygon)) {
        _paintSlimeLose(canvas, polygon);
      }
    }
  }

  void _paintSlimeLose(Canvas canvas, _ProjectedHexPolygon polygon) {
    final Offset? local = polygon.localCenter;
    if (local == null) {
      return;
    }
    final int q = (local.dx / (_baseRadius * 1.5)).round();
    final int r =
        ((local.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    final Level4UnitDesign design = warAnimationDesignForCell(q, r);
    late final List<ui.Image> frames;
    late final ui.Image? mascot;
    switch (design) {
      case Level4UnitDesign.yLose:
        frames = yellowSlimeFrames;
        mascot = tigerLoseImage;
        break;
      case Level4UnitDesign.yWin:
        frames = fireYellowFrames;
        mascot = tigerWinImage;
        break;
      case Level4UnitDesign.rWin:
        frames = tornadoRedFrames;
        mascot = eagleWinImage;
        break;
      case Level4UnitDesign.bWin:
        frames = tornadoIceFrames;
        mascot = dragonWinImage;
        break;
      case Level4UnitDesign.rLose:
        frames = redSlimeFrames;
        mascot = eagleLoseImage;
        break;
      case Level4UnitDesign.bLose:
        frames = blueSlimeFrames;
        mascot = dragonLoseImage;
        break;
      case Level4UnitDesign.defaultSolid:
        return;
    }
    if (frames.isEmpty) {
      return;
    }
    final double activeDuration =
        _level4SyncedSteps * _level4FrameDurationSec;
    final double cycleDuration = activeDuration + _level4PauseSec;
    final double tInCycle = effectT % cycleDuration;
    if (tInCycle >= activeDuration) {
      return;
    }
    final double visibilityScale =
        _level4VisibilityScale(tInCycle, activeDuration);
    if (visibilityScale < 1e-5) {
      return;
    }
    final int step =
        (tInCycle / _level4FrameDurationSec).floor().clamp(0, _level4SyncedSteps - 1);
    final int frameIndex = _isWinBattleEffect(design)
        ? step % 6
        : step % 9;
    final ui.Image frame = frames[frameIndex];
    final Rect bounds = polygon.path.getBounds();
    final double imageAspect = frame.width / frame.height;
    final double baseAnimH = bounds.height * 1.7 * 1.15;
    final double baseAnimW = baseAnimH * imageAspect;
    final Offset pivotTarget = bounds.center.translate(0, bounds.height * 0.08);
    final Level4EffectTune tune = Level4EffectTune.forDesign(design);
    double animW = baseAnimW;
    double animH = baseAnimH;
    if (_isWinBattleEffect(design)) {
      animW *= 1.4;
      animH *= 1.4;
    }
    animW *= tune.animScaleX;
    animH *= tune.animScaleY;
    double animLeft = pivotTarget.dx - tune.animPivotX * animW;
    double animTop = pivotTarget.dy - tune.animPivotY * animH;
    if (_isWinBattleEffect(design)) {
      animTop -= 0.2 * animH;
    }
    final Rect dest = Rect.fromLTWH(animLeft, animTop, animW, animH);
    canvas.save();
    canvas.translate(pivotTarget.dx, pivotTarget.dy);
    canvas.scale(visibilityScale);
    canvas.translate(-pivotTarget.dx, -pivotTarget.dy);
    canvas.drawImageRect(
      frame,
      _imageSrcRectAtLocalOrigin(frame),
      dest,
      Paint()..filterQuality = FilterQuality.high,
    );
    if (mascot != null) {
      final ui.Image overlay = mascot;
      final double overlayAspect = overlay.width / overlay.height;
      double overlayHeight = baseAnimH * 1.6 * 0.7;
      double overlayWidth = overlayHeight * overlayAspect;
      switch (design) {
        case Level4UnitDesign.bLose:
          overlayHeight *= 1.06;
          overlayWidth = overlayHeight * overlayAspect;
          break;
        default:
          break;
      }
      overlayWidth *= tune.mascotScale;
      overlayHeight *= tune.mascotScale;
      final double left =
          pivotTarget.dx - tune.mascotPivotX * overlayWidth;
      final double top =
          pivotTarget.dy - tune.mascotPivotY * overlayHeight;
      final Rect overlayDest = Rect.fromLTWH(
        left,
        top,
        overlayWidth,
        overlayHeight,
      );
      canvas.drawImageRect(
        overlay,
        _imageSrcRectAtLocalOrigin(overlay),
        overlayDest,
        Paint()
          ..filterQuality = FilterQuality.high
          ..blendMode = BlendMode.srcOver,
      );
    }
    canvas.restore();
  }

  _ProjectedHexPolygon? _projectHex(Offset worldCenter, Size size) {
    return _projectHexStatic(worldCenter, size, zoom: zoom);
  }

  static _ProjectedHexPolygon? _projectHexStatic(
    Offset worldCenter,
    Size size, {
    required double zoom,
  }) {
    final _ProjectedPoint center =
        _projectPointStatic(worldCenter.dx, worldCenter.dy, size, zoom: zoom);
    final List<Offset> projectedVertices = <Offset>[
      for (final Offset local in _hexLocalVertices)
        _projectPointStatic(
          worldCenter.dx + local.dx,
          worldCenter.dy + local.dy,
          size,
          zoom: zoom,
        ).screen,
    ];

    final Path path = Path()
      ..moveTo(projectedVertices.first.dx, projectedVertices.first.dy);
    for (int i = 1; i < projectedVertices.length; i++) {
      path.lineTo(projectedVertices[i].dx, projectedVertices[i].dy);
    }
    path.close();

    final double outerRadius =
        (projectedVertices[0] - center.screen).distance;

    return _ProjectedHexPolygon(
      path: path,
      strokeScale: center.scale,
      depthT: center.depthT,
      fillColor: Colors.transparent,
      innerColor: Colors.transparent,
      center: center.screen,
      outerRadius: outerRadius,
      outerVertices: List<Offset>.unmodifiable(projectedVertices),
    );
  }

  Path _buildScaledInnerPath(
    Path outerPath,
    Offset center,
    double innerScale,
  ) {
    final Matrix4 transform = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(innerScale, innerScale)
      ..translate(-center.dx, -center.dy);
    return outerPath.transform(transform.storage);
  }

  _ProjectedPoint _projectPoint(Offset world, Size size) {
    return _projectPointStatic(world.dx, world.dy, size, zoom: zoom);
  }

  static _ProjectedPoint _projectPointStatic(
    double worldX,
    double worldY,
    Size size,
    {
    required double zoom,
  }
  ) {
    final double scaledWorldX = worldX * zoom;
    final double scaledWorldY = worldY * zoom;
    final double zPlane = scaledWorldY + _planeDepthOffset;
    final double cosPitch = math.cos(_cameraPitch);
    final double sinPitch = math.sin(_cameraPitch);

    final double rotatedY = (-_cameraHeight * cosPitch) + (zPlane * sinPitch);
    final double rotatedZ = (_cameraHeight * sinPitch) + (zPlane * cosPitch);
    final double safeZ = math.max(rotatedZ, _nearClipZ);
    final double scale = _focalLength / safeZ;

    final double screenX = size.width / 2 + scaledWorldX * scale;
    final double screenY = size.height * 1.02 - rotatedY * scale;
    return _ProjectedPoint(
      screen: Offset(screenX, screenY),
      scale: scale,
      depthT: safeZ,
    );
  }

  Color _territoryOuterColor(Offset center) {
    return _territoryPalette(center).outer;
  }

  Color _territoryInnerColor(Offset center) {
    return _territoryPalette(center).inner;
  }

  ({Color outer, Color inner}) _territoryPalette(Offset center) {
    int tierForLevel(int level) {
      return switch (level) {
        4 => 1,
        3 => 2,
        2 => 3,
        _ => 4,
      };
    }

    final int level = _strengthLevel(center);
    final int tier = tierForLevel(level);
    final SoldierDesignPalette faction = _territoryFaction(center);

    if (faction == SoldierDesignPalette.red) {
      return (
        outer: factionTierList(SoldierDesignPalette.red)[tier - 1],
        inner: factionTierList(SoldierDesignPalette.red)[tier - 1],
      );
    }
    if (faction == SoldierDesignPalette.yellow) {
      return (
        outer: factionTierList(SoldierDesignPalette.yellow)[tier - 1],
        inner: factionTierList(SoldierDesignPalette.yellow)[tier - 1],
      );
    }
    return (
      outer: factionTierList(SoldierDesignPalette.blue)[tier - 1],
      inner: factionTierList(SoldierDesignPalette.blue)[tier - 1],
    );
  }

  SoldierDesignPalette _territoryFaction(Offset center) {
    final Offset n = Offset(
      (center.dx / (_landExtentX * 2)) + 0.5,
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
    final double yellow = score(const Offset(0.5, 0.48), 0.86) +
        math.cos((n.dx + n.dy) * 8.5) * 0.035;
    final double blue =
        score(const Offset(0.82, 0.42), 0.92) + math.sin(n.dx * 10.0) * 0.03;

    if (red >= yellow && red >= blue) {
      return SoldierDesignPalette.red;
    }
    if (yellow >= red && yellow >= blue) {
      return SoldierDesignPalette.yellow;
    }
    return SoldierDesignPalette.blue;
  }

  static int _strengthLevel(Offset localCenter) {
    final int q = (localCenter.dx / (_baseRadius * 1.5)).round();
    final int r =
        ((localCenter.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    final int hash = ((q * 92821) ^ (r * 68917) ^ 0x5A17) & 0x7fffffff;
    return (hash % 4) + 1;
  }

  bool _isWarCell(Offset localCenter, SoldierDesignPalette faction) {
    final int q = (localCenter.dx / (_baseRadius * 1.5)).round();
    final int r =
        ((localCenter.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    const List<(int, int)> neighbors = <(int, int)>[
      (1, 0),
      (1, -1),
      (0, -1),
      (-1, 0),
      (-1, 1),
      (0, 1),
    ];
    for (final (int dq, int dr) in neighbors) {
      final Offset? neighborCenter =
          _baseLandCentersByAxial[_HexAxial(q + dq, r + dr)];
      if (neighborCenter == null) continue;
      if (_territoryFaction(neighborCenter) != faction) {
        return true;
      }
    }
    return false;
  }

  /// ~30% of boundary war cells show VFX (same hash scheme as before; was 10%).
  static bool _isBoundaryWarVfxSlot(int q, int r) {
    const int salt = 0x594F;
    final int hash = ((q * 92821) ^ (r * 68917) ^ salt) & 0x7fffffff;
    return (hash % 10) < 3;
  }

  bool _shouldShowBoundaryWarVfx(_ProjectedHexPolygon polygon) {
    final Offset? local = polygon.localCenter;
    if (local == null) {
      return false;
    }
    final int q = (local.dx / (_baseRadius * 1.5)).round();
    final int r =
        ((local.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    return _isBoundaryWarVfxSlot(q, r);
  }

  bool _isMagicCell(Offset localCenter) {
    final int q = (localCenter.dx / (_baseRadius * 1.5)).round();
    final int r =
        ((localCenter.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    final int hash = ((q * 73856093) ^ (r * 19349663) ^ 0x1BADC0DE) & 0x7fffffff;
    return (hash % 17) == 0;
  }

  static Offset initialOffsetForViewport(
    Size viewport, {
    double? targetScreenY,
    double hexGap = 0,
    double zoom = 1,
  }) {
    if (viewport == Size.zero) return Offset.zero;
    return Offset(
      0,
      anchorWorldYForViewport(
        viewport,
        targetScreenY: targetScreenY,
        hexGap: hexGap,
        zoom: zoom,
      ),
    );
  }

  static double anchorWorldYForViewport(
    Size viewport, {
    double? targetScreenY,
    double hexGap = 0,
    double zoom = 1,
  }) {
    final double targetY = targetScreenY ?? viewport.height / 2;
    double low = -landExtentY;
    double high = landExtentY;
    final bool increasing =
        _projectScreenYForWorldY(high, viewport, zoom: zoom) >
        _projectScreenYForWorldY(low, viewport, zoom: zoom);

    for (int i = 0; i < 28; i++) {
      final double mid = (low + high) / 2;
      final double value = _projectScreenYForWorldY(mid, viewport, zoom: zoom);
      if ((value < targetY) == increasing) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return (low + high) / 2;
  }

  static double _projectScreenYForWorldY(
    double worldY,
    Size viewport, {
    double zoom = 1,
  }) {
    return _projectPointStatic(0, worldY, viewport, zoom: zoom).screen.dy;
  }

  static double projectScreenYForWorldY(
    double worldY,
    Size viewport, {
    double zoom = 1,
  }) {
    return _projectScreenYForWorldY(worldY, viewport, zoom: zoom);
  }

  static Offset clampOffsetForLocalAnchor({
    required Offset currentOffset,
    required Offset proposedOffset,
    required double anchorWorldY,
    double hexGap = 0,
    double zoom = 1,
  }) {
    final Offset currentAnchorLocal =
        Offset(-currentOffset.dx, anchorWorldY - currentOffset.dy);
    final Offset proposedAnchorLocal =
        Offset(-proposedOffset.dx, anchorWorldY - proposedOffset.dy);

    if (_isPointInsideLand(proposedAnchorLocal, hexGap)) {
      return proposedOffset;
    }

    final Offset currentInside =
        _isPointInsideLand(currentAnchorLocal, hexGap)
            ? currentAnchorLocal
            : _clampPointToLand(currentAnchorLocal, hexGap);
    final Offset proposedClamped = _clampPointToLand(proposedAnchorLocal, hexGap);
    final Offset delta = proposedAnchorLocal - currentInside;
    final double deltaLength = delta.distance;
    if (deltaLength < 1e-6) {
      return Offset(-currentInside.dx, anchorWorldY - currentInside.dy);
    }

    final Offset collisionNormal =
        _nearestBoundaryNormal(proposedAnchorLocal, hexGap) ?? Offset.zero;
    final double blockedDot =
        delta.dx * collisionNormal.dx + delta.dy * collisionNormal.dy;

    Offset finalLocal = proposedClamped;
    if (collisionNormal != Offset.zero && blockedDot > 0) {
      final Offset tangent = Offset(-collisionNormal.dy, collisionNormal.dx);
      final double tangentDot =
          delta.dx * tangent.dx + delta.dy * tangent.dy;
      final Offset tangentDir =
          tangentDot >= 0 ? tangent : Offset(-tangent.dx, -tangent.dy);
      final double tangentLength = tangentDot.abs();
      final Offset slidLocal = _binarySearchAlongLandBoundary(
        validPoint: proposedClamped,
        direction: tangentDir,
        maxDistance: tangentLength,
        hexGap: hexGap,
      );
      if ((slidLocal - proposedClamped).distanceSquared > 1e-6) {
        finalLocal = slidLocal;
      }
    }

    return Offset(-finalLocal.dx, anchorWorldY - finalLocal.dy);
  }

  static Offset _clampPointToLand(Offset point, double hexGap) {
    if (_isPointInsideLand(point, hexGap)) return point;

    Offset bestPoint = _baseLandTileCenters.first;
    double bestDistance2 = double.infinity;

    for (final Offset center in _baseLandTileCenters) {
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

  static Offset? _nearestBoundaryNormal(Offset point, double hexGap) {
    Offset? bestNormal;
    double bestDistance2 = double.infinity;

    for (final Offset center in _baseLandTileCenters) {
      final List<Offset> vertices = _hexVerticesForCenter(center);
      for (int i = 0; i < vertices.length; i++) {
        final Offset a = vertices[i];
        final Offset b = vertices[(i + 1) % vertices.length];
        final Offset nearest = _nearestPointOnSegment(point, a, b);
        final Offset diff = point - nearest;
        final double distance2 = diff.distanceSquared;
        if (distance2 < bestDistance2 && distance2 > 1e-10) {
          bestDistance2 = distance2;
          final double invLength = 1 / math.sqrt(distance2);
          bestNormal = Offset(diff.dx * invLength, diff.dy * invLength);
        }
      }
    }

    return bestNormal;
  }

  static Offset _binarySearchAlongLandBoundary({
    required Offset validPoint,
    required Offset direction,
    required double maxDistance,
    double hexGap = 0,
  }) {
    double low = 0;
    double high = maxDistance;
    for (int i = 0; i < 18; i++) {
      final double mid = (low + high) / 2;
      final Offset candidate = Offset(
        validPoint.dx + direction.dx * mid,
        validPoint.dy + direction.dy * mid,
      );
      if (_isPointInsideLand(candidate, hexGap)) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return Offset(
      validPoint.dx + direction.dx * low,
      validPoint.dy + direction.dy * low,
    );
  }

  static bool _isPointInsideLand(Offset point, double hexGap) {
    for (final Offset center in _baseLandTileCenters) {
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
    return oldDelegate.boardOffset != boardOffset ||
        oldDelegate.meshMode != meshMode ||
        oldDelegate.zoom != zoom ||
        oldDelegate.effectT != effectT ||
        oldDelegate.cellVisualStyle != cellVisualStyle ||
        oldDelegate.yellowSlimeFrames != yellowSlimeFrames ||
        oldDelegate.fireYellowFrames != fireYellowFrames ||
        oldDelegate.tornadoRedFrames != tornadoRedFrames ||
        oldDelegate.tornadoIceFrames != tornadoIceFrames ||
        oldDelegate.redSlimeFrames != redSlimeFrames ||
        oldDelegate.blueSlimeFrames != blueSlimeFrames ||
        oldDelegate.tigerLoseImage != tigerLoseImage ||
        oldDelegate.tigerWinImage != tigerWinImage ||
        oldDelegate.eagleLoseImage != eagleLoseImage ||
        oldDelegate.eagleWinImage != eagleWinImage ||
        oldDelegate.dragonLoseImage != dragonLoseImage ||
        oldDelegate.dragonWinImage != dragonWinImage ||
        oldDelegate.paintLayer != paintLayer;
  }

  static const double _landExtentX = _baseRadius * (1 + 1.5 * (_landSideHexes - 1));
  static final List<Offset> _baseLandTileCenters = _buildLandTileCenters();
  static final Map<_HexAxial, Offset> _baseLandCentersByAxial = <_HexAxial, Offset>{
    for (final Offset center in _baseLandTileCenters)
      _HexAxial(
        (center.dx / (_baseRadius * 1.5)).round(),
        ((center.dy / (_baseRadius * math.sqrt(3))) -
                (center.dx / (_baseRadius * 1.5)).round() / 2)
            .round(),
      ): center,
  };
  static const List<Offset> _hexLocalVertices = <Offset>[
    Offset(_baseRadius, 0),
    Offset(_baseRadius * 0.5, _hexHalfHeight),
    Offset(-_baseRadius * 0.5, _hexHalfHeight),
    Offset(-_baseRadius, 0),
    Offset(-_baseRadius * 0.5, -_hexHalfHeight),
    Offset(_baseRadius * 0.5, -_hexHalfHeight),
  ];

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
    required this.innerColor,
    required this.center,
    required this.outerRadius,
    required this.outerVertices,
    this.level = 1,
    this.localCenter,
    this.faction,
    this.isWarCell = false,
  });

  final Path path;
  final double strokeScale;
  final double depthT;
  final Color fillColor;
  final Color innerColor;
  final Offset center;
  /// Screen-space distance from [center] to a hex vertex (perspective-correct).
  final double outerRadius;
  /// Six screen-space outer hex vertices (same winding as [path]).
  final List<Offset> outerVertices;
  final int level;
  final Offset? localCenter;
  final SoldierDesignPalette? faction;
  final bool isWarCell;

  _ProjectedHexPolygon copyWith({
    Path? path,
    double? strokeScale,
    double? depthT,
    Color? fillColor,
    Color? innerColor,
    Offset? center,
    double? outerRadius,
    List<Offset>? outerVertices,
    int? level,
    Offset? localCenter,
    SoldierDesignPalette? faction,
    bool? isWarCell,
  }) {
    return _ProjectedHexPolygon(
      path: path ?? this.path,
      strokeScale: strokeScale ?? this.strokeScale,
      depthT: depthT ?? this.depthT,
      fillColor: fillColor ?? this.fillColor,
      innerColor: innerColor ?? this.innerColor,
      center: center ?? this.center,
      outerRadius: outerRadius ?? this.outerRadius,
      outerVertices: outerVertices ?? this.outerVertices,
      level: level ?? this.level,
      localCenter: localCenter ?? this.localCenter,
      faction: faction ?? this.faction,
      isWarCell: isWarCell ?? this.isWarCell,
    );
  }
}

class _HexAxial {
  const _HexAxial(this.q, this.r);

  final int q;
  final int r;

  @override
  bool operator ==(Object other) =>
      other is _HexAxial && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);
}
