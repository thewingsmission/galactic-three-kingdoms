import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

export '../models/level4_war_vfx.dart';

import '../models/cell_core_palette.dart';
import '../models/game_session_state.dart';
import '../models/hex_cell_preview_style.dart';
import '../models/level4_war_vfx.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_rarity.dart';
import '../models/soldier_faction_color_theme.dart';
import 'hex_cell_preview_layout.dart';
import 'hex_cell_styles_paint.dart';
import 'soldier_design_catalog.dart';
import 'virtual_joystick.dart';

class Pseudo3DScene extends StatefulWidget {
  const Pseudo3DScene({
    super.key,
    required this.session,
    this.meshMode = Pseudo3DMeshMode.solid,
    this.boardBottomInset = 0,
    this.viewportHeightFactor = 0.72,
    this.maxViewportHeight = 540,
    this.viewportWidthFactor = 0.94,
    this.maxViewportWidth = 980,
    this.spritesheetPivotX = _CenterSoldierSpritesheetMetrics.pivotX,
    this.spritesheetPivotY = _CenterSoldierSpritesheetMetrics.pivotY,
    this.onHudVisibilityChanged,
  });

  final GameSessionState session;
  final Pseudo3DMeshMode meshMode;
  final double boardBottomInset;
  final double viewportHeightFactor;
  final double maxViewportHeight;
  final double viewportWidthFactor;
  final double maxViewportWidth;
  final double spritesheetPivotX;
  final double spritesheetPivotY;
  final ValueChanged<bool>? onHudVisibilityChanged;

  @override
  State<Pseudo3DScene> createState() => _Pseudo3DSceneState();
}

enum Pseudo3DMeshMode { solid, outlineTransparent, outlineHalfTransparent }

class _CenterSoldierSpritesheetMetrics {
  _CenterSoldierSpritesheetMetrics._();

  static const double scale = 1.31;
  static const double pivotX = 0.53;
  static const double pivotY = 0.79;
  static const double animationSpeed = 1.89;
  static const double shadowBaseSizeFactor = 0.39;
  static const double shadowDiameterFactor = 1.05;

  static double shadowCenterOffsetFromMarkerCenter(double markerBoxSize) {
    final double shadowDiameter =
        markerBoxSize * shadowBaseSizeFactor * shadowDiameterFactor;
    return shadowDiameter / 6;
  }
}

enum _CenterSoldierFacing { front, left, back, right }

class _CenterSoldierFrameTuning {
  const _CenterSoldierFrameTuning({
    this.localX = 0,
    this.localY = 0,
    this.localScale = 1,
  });

  final double localX;
  final double localY;
  final double localScale;

  _CenterSoldierFrameTuning copyWith({
    double? localX,
    double? localY,
    double? localScale,
  }) {
    return _CenterSoldierFrameTuning(
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
      localScale: localScale ?? this.localScale,
    );
  }
}

class _Pseudo3DSceneState extends State<Pseudo3DScene>
    with SingleTickerProviderStateMixin {
  static const double _boardMoveSpeed = 220;
  static const double _soldierMotionCycleSeconds = 1.4;
  static const double _soldierAnchorScreenYOffsetFactor = 0.15;
  static const double _markerBoxSize = 84;
  static const double _dynamicJoystickBaseRadius = 72;
  static const double _dynamicJoystickKnobRadius = 28;
  static const double _minZoom = 0.7;
  static const double _maxZoom = 1.8;
  static const double _keyboardZoomStep = 0.08;
  static const double _scoreHudTopInset = 10;
  static const Duration _scorePanelRevealDelay = Duration(milliseconds: 500);

  late final Ticker _ticker;
  late final FocusNode _keyboardFocusNode;
  static const SoldierDesignPalette _playerFaction =
      SoldierDesignPalette.yellow;

  late final _BoardAggregateScores _boardAggregateScores;
  Duration? _lastElapsed;
  Offset _movementVector = Offset.zero;
  Offset _boardOffset = Offset.zero;
  Size _viewportSize = Size.zero;
  double _shadowAnchorWorldY = 0;
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
  final Set<_CenterSoldierFacing> _centerSoldierFramesLoadingStarted =
      <_CenterSoldierFacing>{};
  final Map<_CenterSoldierFacing, List<ui.Image>> _centerSoldierFramesByFacing =
      <_CenterSoldierFacing, List<ui.Image>>{
        for (final _CenterSoldierFacing facing in _CenterSoldierFacing.values)
          facing: <ui.Image>[],
      };
  static const Map<_CenterSoldierFacing, _CenterSoldierFrameTuning>
  _centerSoldierTuningsByFacing =
      <_CenterSoldierFacing, _CenterSoldierFrameTuning>{
        _CenterSoldierFacing.right: _CenterSoldierFrameTuning(
          localX: 5.77,
          localY: -3.24,
          localScale: 1.04,
        ),
        _CenterSoldierFacing.left: _CenterSoldierFrameTuning(
          localX: 2.52,
          localY: -3.60,
          localScale: 1.09,
        ),
        _CenterSoldierFacing.back: _CenterSoldierFrameTuning(
          localX: 3.24,
          localY: -3.96,
          localScale: 1.00,
        ),
        _CenterSoldierFacing.front: _CenterSoldierFrameTuning(
          localX: 2.88,
          localY: -3.96,
          localScale: 1.00,
        ),
      };
  _CenterSoldierFacing _centerSoldierFacing = _CenterSoldierFacing.front;
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
  Offset? _trackedShadowCellLocalCenter;
  Offset? _scorePanelCellLocalCenter;
  double _trackedShadowCellEnteredAtSec = 0;
  bool _showScorePanel = false;
  Offset? _dynamicJoystickBaseCenter;
  Offset? _dynamicJoystickKnobCenter;

  @override
  void initState() {
    super.initState();
    _boardAggregateScores = _StrategicBoardScoring.buildAggregateScores(
      widget.session,
      _playerFaction,
    );
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
    for (final _CenterSoldierFacing facing in _CenterSoldierFacing.values) {
      _ensureCenterSoldierFramesLoaded(facing);
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

  String _centerSoldierFacingFolderName(_CenterSoldierFacing facing) =>
      switch (facing) {
        _CenterSoldierFacing.front => 'front',
        _CenterSoldierFacing.left => 'left',
        _CenterSoldierFacing.back => 'back',
        _CenterSoldierFacing.right => 'right',
      };

  _CenterSoldierFacing _facingFromMovement(Offset movement) {
    final double angle = math.atan2(movement.dy, movement.dx);
    if (angle >= -math.pi / 4 && angle < math.pi / 4) {
      return _CenterSoldierFacing.right;
    }
    if (angle >= math.pi / 4 && angle < 3 * math.pi / 4) {
      return _CenterSoldierFacing.front;
    }
    if (angle >= -3 * math.pi / 4 && angle < -math.pi / 4) {
      return _CenterSoldierFacing.back;
    }
    return _CenterSoldierFacing.left;
  }

  void _ensureCenterSoldierFramesLoaded(_CenterSoldierFacing facing) {
    final List<ui.Image> frames = _centerSoldierFramesByFacing[facing]!;
    if (frames.isNotEmpty ||
        _centerSoldierFramesLoadingStarted.contains(facing)) {
      return;
    }
    _centerSoldierFramesLoadingStarted.add(facing);
    _loadCenterSoldierFramesForFacing(facing);
  }

  Future<void> _loadCenterSoldierFramesForFacing(
    _CenterSoldierFacing facing,
  ) async {
    final String facingName = _centerSoldierFacingFolderName(facing);
    final String folderName = 'player_yellow_${facingName}_sprite';
    final List<ui.Image> loaded = <ui.Image>[];
    for (int i = 1; i <= 28; i++) {
      final String assetPath =
          'image/player/$folderName/${folderName}_${i.toString().padLeft(2, '0')}.png';
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 256,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        loaded.add(frame.image);
      } catch (e, st) {
        for (final ui.Image image in loaded) {
          image.dispose();
        }
        _centerSoldierFramesLoadingStarted.remove(facing);
        if (kDebugMode) {
          debugPrint('Pseudo3DScene: failed loading $assetPath: $e');
          debugPrint('$st');
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
      _centerSoldierFramesByFacing[facing]!.addAll(loaded);
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

    if (_lastElapsed == null) {
      setState(() {
        _effectT = elapsedSeconds;
      });
      _lastElapsed = elapsed;
      return;
    }

    final double dt =
        (elapsed - _lastElapsed!).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    setState(() {
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

      _updateScorePanelTracking(elapsedSeconds);
    });
  }

  void _updateScorePanelTracking(double elapsedSeconds) {
    final bool wasVisible = _showScorePanel;
    final Offset? shadowCell = _currentShadowSteppedCellLocalCenter();
    if (!_sameLocalCenter(shadowCell, _trackedShadowCellLocalCenter)) {
      _trackedShadowCellLocalCenter = shadowCell;
      _trackedShadowCellEnteredAtSec = elapsedSeconds;
      _showScorePanel = false;
      _scorePanelCellLocalCenter = null;
    }

    if (_movementVector != Offset.zero || shadowCell == null) {
      _showScorePanel = false;
      _scorePanelCellLocalCenter = null;
      if (wasVisible != _showScorePanel) {
        widget.onHudVisibilityChanged?.call(_showScorePanel);
      }
      return;
    }

    final double revealDelaySeconds =
        _scorePanelRevealDelay.inMilliseconds / Duration.millisecondsPerSecond;
    if (elapsedSeconds - _trackedShadowCellEnteredAtSec >= revealDelaySeconds) {
      _showScorePanel = true;
      _scorePanelCellLocalCenter = shadowCell;
    } else {
      _showScorePanel = false;
      _scorePanelCellLocalCenter = null;
    }
    if (wasVisible != _showScorePanel) {
      widget.onHudVisibilityChanged?.call(_showScorePanel);
    }
  }

  Offset? _currentShadowSteppedCellLocalCenter() {
    if (_viewportSize == Size.zero) {
      return null;
    }
    return _Pseudo3DBoardPainter._localCenterUnderShadow(
      _boardOffset,
      _shadowAnchorWorldY,
    );
  }

  bool _sameLocalCenter(Offset? a, Offset? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return (a - b).distanceSquared < 1.0;
  }

  void _beginTouchHoldMovement(Offset localPosition) {
    _dynamicJoystickBaseCenter = localPosition;
    _dynamicJoystickKnobCenter = localPosition;
    _updateTouchHoldVector(localPosition);
  }

  void _updateTouchHoldMovement(Offset localPosition) {
    _updateTouchHoldVector(localPosition);
  }

  void _endTouchHoldMovement() {
    setState(() {
      _movementVector = Offset.zero;
      _dynamicJoystickBaseCenter = null;
      _dynamicJoystickKnobCenter = null;
    });
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
      _beginTouchHoldMovement(event.localPosition);
    } else {
      _endTouchHoldMovement();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointerCount == 1) {
      _updateTouchHoldMovement(event.localPosition);
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
            _CenterSoldierSpritesheetMetrics.shadowCenterOffsetFromMarkerCenter(
                  _markerBoxSize,
                ) *
                _zoom;
        final double viewportTop =
            (_latestBoardLayoutHeight - _viewportSize.height) / 2;
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

  void _updateTouchHoldVector(Offset localPosition) {
    final Offset baseCenter = _dynamicJoystickBaseCenter ?? localPosition;
    final double maxTravel = _dynamicJoystickBaseRadius;
    Offset delta = localPosition - baseCenter;
    delta = clampJoystickDelta(delta, maxTravel);
    final Offset knobCenter = baseCenter + delta;
    setState(() {
      _dynamicJoystickBaseCenter = baseCenter;
      _dynamicJoystickKnobCenter = knobCenter;
      _movementVector = Offset(delta.dx / maxTravel, delta.dy / maxTravel);
      if (_movementVector.distanceSquared > 1e-6) {
        _centerSoldierFacing = _facingFromMovement(_movementVector);
        _ensureCenterSoldierFramesLoaded(_centerSoldierFacing);
      }
    });
  }

  (int, int) _axialOfLocalCenter(Offset localCenter) {
    final int q = (localCenter.dx / (_Pseudo3DBoardPainter._baseRadius * 1.5))
        .round();
    final int r =
        ((localCenter.dy / (_Pseudo3DBoardPainter._baseRadius * math.sqrt(3))) -
                q / 2)
            .round();
    return (q, r);
  }

  Map<SoldierDesignPalette, int> _scoresForLocalCenter(Offset localCenter) {
    final (int q, int r) = _axialOfLocalCenter(localCenter);
    return widget.session.scoresForCell(q, r);
  }

  SoldierDesignPalette _ownerForLocalCenter(Offset localCenter) {
    final (int q, int r) = _axialOfLocalCenter(localCenter);
    return widget.session.ownerForCell(q, r);
  }

  List<_HudScorePanelModel> _buildHudPanels() {
    final Offset? localCenter = _scorePanelCellLocalCenter;
    if (localCenter == null) {
      return const <_HudScorePanelModel>[];
    }
    return <_HudScorePanelModel>[
      _buildCountryScorePanel(),
      _buildCellScorePanel(localCenter),
      _buildPersonalProfilePanel(),
      _buildPersonalArmyPanel(),
    ];
  }

  _HudScorePanelModel _buildCountryScorePanel() {
    final Map<SoldierDesignPalette, int> territorySize =
        _boardAggregateScores.countryCellCounts;
    final List<SoldierDesignPalette> order = _sortedFactionsByScores(
      territorySize,
    );
    return _HudScorePanelModel(
      kind: _HudPanelKind.kingdom,
      title: 'Kingdom Census',
      subtitle: 'Realm-wide land statistics',
      themeFaction: order.first,
      session: widget.session,
      rows: const <_HudScoreRowModel>[],
      kingdomSections: <_HudKingdomMetricSection>[
        _HudKingdomMetricSection(
          label: 'Territory Size',
          values: territorySize,
        ),
        _HudKingdomMetricSection(
          label: 'Land Power',
          values: _boardAggregateScores.landPowerByFaction,
        ),
        _HudKingdomMetricSection(
          label: 'Total Tribute',
          values: _boardAggregateScores.totalTributeByFaction,
        ),
      ],
      panelIcon: _HudPanelIconData(
        assetPath: _joystickKnobAssetPath(order.first),
        imageScale: _joystickKnobImageScale(order.first),
        imageOffset: _joystickKnobImageOffset(order.first),
      ),
    );
  }

  _HudScorePanelModel _buildCellScorePanel(Offset localCenter) {
    final Map<SoldierDesignPalette, int> cellScores = _scoresForLocalCenter(
      localCenter,
    );
    final SoldierDesignPalette owner = _ownerForLocalCenter(localCenter);
    final Map<SoldierDesignPalette, int> deltas = _buildCellTrendMap(
      localCenter,
      cellScores,
    );
    final List<SoldierDesignPalette> order = _sortedFactionsByScores(
      cellScores,
    );
    final List<_HudScoreRowModel> rows = order
        .map(
          (SoldierDesignPalette faction) => _HudScoreRowModel(
            faction: faction,
            label: _factionName(faction),
            value: cellScores[faction] ?? 0,
            delta: deltas[faction] ?? 0,
            emphasis: faction == owner,
          ),
        )
        .toList();
    return _HudScorePanelModel(
      kind: _HudPanelKind.land,
      title: 'Land Claim',
      subtitle: 'Owner: ${_factionName(owner)}',
      themeFaction: owner,
      rows: rows,
      panelIcon: _HudPanelIconData(
        assetPath: _joystickKnobAssetPath(owner),
        imageScale: _joystickKnobImageScale(owner),
        imageOffset: _joystickKnobImageOffset(owner),
      ),
    );
  }

  _HudScorePanelModel _buildPersonalProfilePanel() {
    return _HudScorePanelModel(
      kind: _HudPanelKind.heroProfile,
      title: 'Warlord Record',
      subtitle: 'Your kingdom champion',
      themeFaction: _playerFaction,
      rows: const <_HudScoreRowModel>[],
      heroStats: _HudHeroStats(
        level: _boardAggregateScores.personalLevel,
        currentExp: _boardAggregateScores.currentExp,
        expToNextLevel: _boardAggregateScores.expToNextLevel,
        distinctSoldiers: _boardAggregateScores.distinctSoldierCount,
        moneyCollected: _boardAggregateScores.moneyCollected,
        rarityCounts: _boardAggregateScores.rarityCounts,
        joystickAssetPath: _joystickKnobAssetPath(_playerFaction),
        joystickImageScale: _joystickKnobImageScale(_playerFaction),
        joystickImageOffset: _joystickKnobImageOffset(_playerFaction),
      ),
    );
  }

  _HudScorePanelModel _buildPersonalArmyPanel() {
    final Map<SoldierDesignPalette, int> enemyKills =
        _boardAggregateScores.enemyKillsByFaction;
    final List<SoldierDesignPalette> enemyOrder =
        SoldierDesignPalette.values
            .where((SoldierDesignPalette faction) => faction != _playerFaction)
            .toList()
          ..sort((SoldierDesignPalette a, SoldierDesignPalette b) {
            final int byScore = (enemyKills[b] ?? 0).compareTo(
              enemyKills[a] ?? 0,
            );
            if (byScore != 0) {
              return byScore;
            }
            return _factionName(a).compareTo(_factionName(b));
          });
    final List<_HudScoreRowModel> rows = <_HudScoreRowModel>[
      _HudScoreRowModel(
        faction: _playerFaction,
        label: '${_factionName(_playerFaction)} money',
        value: _boardAggregateScores.moneyCollected,
        emphasis: true,
        valuePrefix: '\$',
      ),
      ...enemyOrder.map(
        (SoldierDesignPalette faction) => _HudScoreRowModel(
          faction: faction,
          label: '${_factionName(faction)} KOs',
          value: enemyKills[faction] ?? 0,
        ),
      ),
    ];
    return _HudScorePanelModel(
      kind: _HudPanelKind.heroArmy,
      title: 'Warband Ledger',
      subtitle: 'Roster and enemy tally',
      themeFaction: _playerFaction,
      rows: rows,
      heroStats: _HudHeroStats(
        level: _boardAggregateScores.personalLevel,
        currentExp: _boardAggregateScores.currentExp,
        expToNextLevel: _boardAggregateScores.expToNextLevel,
        distinctSoldiers: _boardAggregateScores.distinctSoldierCount,
        moneyCollected: _boardAggregateScores.moneyCollected,
        rarityCounts: _boardAggregateScores.rarityCounts,
        joystickAssetPath: _joystickKnobAssetPath(_playerFaction),
        joystickImageScale: _joystickKnobImageScale(_playerFaction),
        joystickImageOffset: _joystickKnobImageOffset(_playerFaction),
      ),
    );
  }

  Map<SoldierDesignPalette, int> _buildCellTrendMap(
    Offset localCenter,
    Map<SoldierDesignPalette, int> scores,
  ) {
    final int q = (localCenter.dx / (_Pseudo3DBoardPainter._baseRadius * 1.5))
        .round();
    final int r =
        ((localCenter.dy / (_Pseudo3DBoardPainter._baseRadius * math.sqrt(3))) -
                q / 2)
            .round();
    return <SoldierDesignPalette, int>{
      for (final SoldierDesignPalette faction in SoldierDesignPalette.values)
        faction: math.max(
          1,
          math.min(
            scores[faction] ?? 0,
            4 + (((q + 31) * (r + 17) * (faction.index + 2)).abs() % 13),
          ),
        ),
    };
  }

  List<SoldierDesignPalette> _sortedFactionsByScores(
    Map<SoldierDesignPalette, int> scores,
  ) {
    final List<SoldierDesignPalette> ordered = SoldierDesignPalette.values
        .toList();
    ordered.sort((SoldierDesignPalette a, SoldierDesignPalette b) {
      final int byScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
      if (byScore != 0) {
        return byScore;
      }
      return _factionName(a).compareTo(_factionName(b));
    });
    return ordered;
  }

  String _factionName(SoldierDesignPalette faction) => switch (faction) {
    SoldierDesignPalette.red => 'Red',
    SoldierDesignPalette.yellow => 'Yellow',
    SoldierDesignPalette.blue => 'Blue',
  };

  String _joystickKnobAssetPath(SoldierDesignPalette faction) =>
      switch (faction) {
        SoldierDesignPalette.red => 'image/head_red_eagle.png',
        SoldierDesignPalette.yellow => 'image/head_yellow_tiger.png',
        SoldierDesignPalette.blue => 'image/head_blue_dragon.png',
      };

  double _joystickKnobImageScale(SoldierDesignPalette faction) =>
      switch (faction) {
        SoldierDesignPalette.red => 1.2,
        SoldierDesignPalette.yellow => 1.0,
        SoldierDesignPalette.blue => 1.1,
      };

  Offset _joystickKnobImageOffset(SoldierDesignPalette faction) =>
      switch (faction) {
        SoldierDesignPalette.red => const Offset(0, 4.48),
        SoldierDesignPalette.yellow => Offset.zero,
        SoldierDesignPalette.blue => const Offset(0, 2.8),
      };

  Widget _buildScoreHud() {
    final List<_HudScorePanelModel> panels = _buildHudPanels();
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 520),
        offset: _showScorePanel ? Offset.zero : const Offset(0, -0.22),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 520),
          opacity: _showScorePanel ? 1 : 0,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, _scoreHudTopInset, 12, 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < panels.length; i++) ...<Widget>[
                    Expanded(child: _HudScorePanelCard(model: panels[i])),
                    if (i != panels.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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
    for (final List<ui.Image> frames in _centerSoldierFramesByFacing.values) {
      for (final ui.Image image in frames) {
        image.dispose();
      }
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
              _CenterSoldierSpritesheetMetrics.shadowCenterOffsetFromMarkerCenter(
                    _markerBoxSize,
                  ) *
                  _zoom;
          final double viewportTop = (boardLayoutHeight - viewportHeight) / 2;
          final double shadowCenterViewportY =
              shadowCenterScreenY - viewportTop;
          final double spritesheetFrameProgress =
              ((_effectT * _CenterSoldierSpritesheetMetrics.animationSpeed) /
                  _soldierMotionCycleSeconds) %
              1.0;
          final bool isSoldierMoving = _movementVector.distanceSquared > 1e-6;
          final List<Color> joystickTier = factionTierList(_playerFaction);
          _ensureCenterSoldierFramesLoaded(_centerSoldierFacing);
          final _CenterSoldierFrameTuning currentTuning =
              _centerSoldierTuningsByFacing[_centerSoldierFacing]!;
          final List<ui.Image> centerSoldierFrames =
              _centerSoldierFramesByFacing[_centerSoldierFacing] ??
              const <ui.Image>[];
          final ui.Image? spritesheetFrame = centerSoldierFrames.isEmpty
              ? null
              : isSoldierMoving
              ? centerSoldierFrames[(spritesheetFrameProgress *
                            centerSoldierFrames.length)
                        .floor() %
                    centerSoldierFrames.length]
              : centerSoldierFrames.first;

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
          final Offset clampedOffset =
              _Pseudo3DBoardPainter.clampOffsetForLocalAnchor(
                currentOffset: _didInitializeBoardOffset
                    ? _boardOffset
                    : initialOffset,
                proposedOffset: _didInitializeBoardOffset
                    ? _boardOffset
                    : initialOffset,
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
                        session: widget.session,
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        shadowAnchorWorldY: _shadowAnchorWorldY,
                        soldierScreenY: shadowCenterViewportY,
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
                        constraints.maxHeight *
                            _soldierAnchorScreenYOffsetFactor,
                      ),
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _markerBoxSize,
                          height: _markerBoxSize,
                          child: const _CenterSoldierShadow(),
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
                        session: widget.session,
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        shadowAnchorWorldY: _shadowAnchorWorldY,
                        soldierScreenY: shadowCenterViewportY,
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
                        paintLayer: _BoardPaintLayer.shadowHighlight,
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
                        session: widget.session,
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        shadowAnchorWorldY: _shadowAnchorWorldY,
                        soldierScreenY: shadowCenterViewportY,
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
                        paintLayer: _BoardPaintLayer.warEffectsBehindSoldier,
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
                        constraints.maxHeight *
                            _soldierAnchorScreenYOffsetFactor,
                      ),
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _markerBoxSize,
                          height: _markerBoxSize,
                          child: spritesheetFrame == null
                              ? const SizedBox.shrink()
                              : _CenterSoldierSpritesheetBody(
                                  frame: spritesheetFrame,
                                  pivotXFactor: widget.spritesheetPivotX,
                                  pivotYFactor: widget.spritesheetPivotY,
                                  localX: currentTuning.localX,
                                  localY: currentTuning.localY,
                                  localScale: currentTuning.localScale,
                                ),
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
                        session: widget.session,
                        boardOffset: clampedOffset,
                        meshMode: widget.meshMode,
                        zoom: _zoom,
                        effectT: _effectT,
                        shadowAnchorWorldY: _shadowAnchorWorldY,
                        soldierScreenY: shadowCenterViewportY,
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
                        paintLayer: _BoardPaintLayer.warEffectsInFrontOfSoldier,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _DynamicJoystickOverlay(
                    baseCenter: _dynamicJoystickBaseCenter,
                    knobCenter: _dynamicJoystickKnobCenter,
                    baseRadius: _dynamicJoystickBaseRadius,
                    knobRadius: _dynamicJoystickKnobRadius,
                    baseColor: joystickTier[2].withValues(alpha: 0.5),
                    ringColor: joystickTier[1].withValues(alpha: 0.9),
                    knobColor: joystickTier[4].withValues(alpha: 0.98),
                    knobOutlineColor: joystickTier[1],
                    knobAssetPath: _joystickKnobAssetPath(_playerFaction),
                    knobImageScale: _joystickKnobImageScale(_playerFaction),
                    knobImageOffset: _joystickKnobImageOffset(_playerFaction),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, top: 0, child: _buildScoreHud()),
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

class _CenterSoldierShadow extends StatelessWidget {
  const _CenterSoldierShadow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size =
            math.min(constraints.maxWidth, constraints.maxHeight) *
            _CenterSoldierSpritesheetMetrics.shadowBaseSizeFactor;
        final double shadowDiameter =
            size * _CenterSoldierSpritesheetMetrics.shadowDiameterFactor;
        final Offset shadowOffsetFromCenter = Offset(0, shadowDiameter / 6);

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

class _DynamicJoystickOverlay extends StatelessWidget {
  const _DynamicJoystickOverlay({
    required this.baseCenter,
    required this.knobCenter,
    required this.baseRadius,
    required this.knobRadius,
    required this.baseColor,
    required this.ringColor,
    required this.knobColor,
    required this.knobOutlineColor,
    required this.knobAssetPath,
    required this.knobImageScale,
    required this.knobImageOffset,
  });

  final Offset? baseCenter;
  final Offset? knobCenter;
  final double baseRadius;
  final double knobRadius;
  final Color baseColor;
  final Color ringColor;
  final Color knobColor;
  final Color knobOutlineColor;
  final String? knobAssetPath;
  final double knobImageScale;
  final Offset knobImageOffset;

  @override
  Widget build(BuildContext context) {
    if (baseCenter == null || knobCenter == null) {
      return const SizedBox.shrink();
    }

    final Offset knobOffset = knobCenter! - baseCenter!;
    return Stack(
      children: <Widget>[
        Positioned(
          left: baseCenter!.dx - baseRadius,
          top: baseCenter!.dy - baseRadius,
          child: VirtualJoystickVisual(
            outerRadius: baseRadius,
            knobRadius: knobRadius,
            knobOffset: knobOffset,
            baseColor: baseColor,
            ringColor: ringColor,
            knobColor: knobColor,
            knobOutlineColor: knobOutlineColor,
            knobAssetPath: knobAssetPath,
            knobImageScale: knobImageScale,
            knobImageOffset: knobImageOffset,
          ),
        ),
      ],
    );
  }
}

class _CenterSoldierSpritesheetBody extends StatelessWidget {
  const _CenterSoldierSpritesheetBody({
    required this.frame,
    required this.pivotXFactor,
    required this.pivotYFactor,
    required this.localX,
    required this.localY,
    required this.localScale,
  });

  final ui.Image frame;
  final double pivotXFactor;
  final double pivotYFactor;
  final double localX;
  final double localY;
  final double localScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double markerSize = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final double frameWidth = frame.width.toDouble();
        final double frameHeight = frame.height.toDouble();
        final double renderedWidth =
            markerSize *
            _CenterSoldierSpritesheetMetrics.scale *
            localScale.clamp(0.1, 10.0);
        final double renderedHeight =
            renderedWidth * frameHeight / math.max(frameWidth, 1);
        final double pivotX = renderedWidth * pivotXFactor;
        final double pivotY = renderedHeight * pivotYFactor;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: markerSize / 2 - pivotX + localX,
              top: markerSize / 2 - pivotY + localY,
              width: renderedWidth,
              height: renderedHeight,
              child: IgnorePointer(
                child: RawImage(
                  image: frame,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hex fills vs shadow rim vs war VFX composite in separate layers: mesh first,
/// then shadow footprint, then war effects behind the soldier, then the soldier,
/// then war effects in front of the soldier.
enum _BoardPaintLayer {
  hexMesh,
  shadowHighlight,
  warEffectsBehindSoldier,
  warEffectsInFrontOfSoldier,
}

class _Pseudo3DBoardPainter extends CustomPainter {
  _Pseudo3DBoardPainter({
    required this.session,
    required this.boardOffset,
    required this.meshMode,
    required this.zoom,
    required this.effectT,
    required this.shadowAnchorWorldY,
    required this.soldierScreenY,
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

  final GameSessionState session;
  final Offset boardOffset;
  final Pseudo3DMeshMode meshMode;
  final double zoom;
  final double effectT;
  final double soldierScreenY;

  /// World Y solved so the soldier shadow sits on the map; used to find the stepped-on hex.
  final double shadowAnchorWorldY;
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
      final double u = (tInActive / _level4ScaleInDurationSec).clamp(0.0, 1.0);
      return Curves.easeOut.transform(u);
    }
    if (tInActive > activeDuration - _level4ScaleOutDurationSec) {
      final double u =
          ((activeDuration - tInActive) / _level4ScaleOutDurationSec).clamp(
            0.0,
            1.0,
          );
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
  static const double _hexMeshCullMargin = 56;
  static const double _shadowHighlightCullMargin = 72;
  static const double _warEffectsCullMargin = 180;
  static final double landExtentY =
      math.sqrt(3) * _baseRadius * (_landSideHexes - 0.5);

  /// Rounds fractional axial coords (same grid as [_baseLandTileCenters]) to a hex cell.
  static _HexAxial _axialRoundFractional(double fq, double fr) {
    final double x = fq;
    final double z = fr;
    final double y = -fq - fr;
    int rx = x.round();
    int ry = y.round();
    int rz = z.round();
    final double xDiff = (rx - x).abs();
    final double yDiff = (ry - y).abs();
    final double zDiff = (rz - z).abs();
    if (xDiff > yDiff && xDiff > zDiff) {
      rx = -ry - rz;
    } else if (yDiff > zDiff) {
      ry = -rx - rz;
    } else {
      rz = -rx - ry;
    }
    return _HexAxial(rx, rz);
  }

  /// Land local center of the hex under the soldier shadow (viewport anchor), if on the map.
  static Offset? _localCenterUnderShadow(
    Offset boardOffset,
    double shadowAnchorWorldY,
  ) {
    final Offset anchorLocal = Offset(
      -boardOffset.dx,
      shadowAnchorWorldY - boardOffset.dy,
    );
    final double fq = anchorLocal.dx / (_baseRadius * 1.5);
    final double fr = anchorLocal.dy / (_baseRadius * math.sqrt(3)) - fq / 2;
    final _HexAxial axial = _axialRoundFractional(fq, fr);
    return _baseLandCentersByAxial[axial];
  }

  Rect _expandedViewportCullRect(Size size) {
    final double margin = switch (paintLayer) {
      _BoardPaintLayer.hexMesh => _hexMeshCullMargin,
      _BoardPaintLayer.shadowHighlight => _shadowHighlightCullMargin,
      _BoardPaintLayer.warEffectsBehindSoldier => _warEffectsCullMargin,
      _BoardPaintLayer.warEffectsInFrontOfSoldier => _warEffectsCullMargin,
    };
    return Rect.fromLTWH(0, 0, size.width, size.height).inflate(margin);
  }

  static Rect _roughProjectedHexBoundsStatic(
    Offset worldCenter,
    Size size, {
    required double zoom,
  }) {
    final List<Offset> samplePoints = <Offset>[
      _projectPointStatic(
        worldCenter.dx,
        worldCenter.dy,
        size,
        zoom: zoom,
      ).screen,
      for (final Offset local in _hexLocalVertices)
        _projectPointStatic(
          worldCenter.dx + local.dx,
          worldCenter.dy + local.dy,
          size,
          zoom: zoom,
        ).screen,
    ];
    double minX = samplePoints.first.dx;
    double maxX = minX;
    double minY = samplePoints.first.dy;
    double maxY = minY;
    for (final Offset point in samplePoints.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(18);
  }

  Rect _roughProjectedHexBounds(Offset worldCenter, Size size) {
    return _roughProjectedHexBoundsStatic(worldCenter, size, zoom: zoom);
  }

  Rect _finalProjectedCullBounds(_ProjectedHexPolygon polygon) {
    final double extra = switch (paintLayer) {
      _BoardPaintLayer.hexMesh => math.max(20.0, polygon.strokeScale * 18.0),
      _BoardPaintLayer.shadowHighlight => math.max(
        40.0,
        polygon.strokeScale * 28.0,
      ),
      _BoardPaintLayer.warEffectsBehindSoldier => math.max(
        96.0,
        polygon.outerRadius * 0.9,
      ),
      _BoardPaintLayer.warEffectsInFrontOfSoldier => math.max(
        96.0,
        polygon.outerRadius * 0.9,
      ),
    };
    return polygon.path.getBounds().inflate(extra);
  }

  /// Electric buzz on the hex outline + rim glow (shadow footprint). Uses [effectT] for motion.
  void _paintShadowFootprintGlow(
    Canvas canvas,
    Path outlinePath,
    double strokeScale,
    SoldierDesignPalette faction,
  ) {
    final c = faction.shadowFootprintElectricColors;
    final double s = math.max(0.85, strokeScale);
    final double buzzT = effectT;

    for (final ui.PathMetric metric in outlinePath.computeMetrics()) {
      final double len = metric.length;
      if (len < 1e-6) {
        continue;
      }
      final int steps = (len / 3.8).clamp(40, 100).round();
      Offset? prev;
      for (int i = 0; i <= steps; i++) {
        final double dist = len * i / steps;
        final ui.Tangent? tan = metric.getTangentForOffset(dist);
        if (tan == null) {
          continue;
        }
        final Offset p = tan.position;
        final Offset tv = tan.vector;
        final double td = tv.distance;
        if (td < 1e-8) {
          continue;
        }
        final Offset tang = Offset(tv.dx / td, tv.dy / td);
        final Offset norm = Offset(-tang.dy, tang.dx);

        final double phase = buzzT * 36 + dist * 0.18;
        final double buzz =
            math.sin(phase) * math.cos(phase * 2.1 + dist * 0.03);
        final double crackle =
            math.sin(buzzT * 52 + dist * 0.22) * math.cos(buzzT * 23 + i * 0.4);
        final double amp =
            (3.4 + 5.8 * (0.5 + 0.5 * math.sin(buzzT * 41 + i * 0.73))) * s;

        final Offset sparkEnd = p + norm * (buzz * amp);
        final Paint spark = Paint()
          ..strokeWidth = math.max(0.85, 1.55 * s)
          ..color = c.spark.withValues(alpha: 0.58 + 0.38 * buzz.abs())
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, sparkEnd, spark);

        final Paint sparkCore = Paint()
          ..strokeWidth = math.max(0.45, 0.72 * s)
          ..color = c.sparkCore.withValues(alpha: 0.72 + 0.26 * crackle.abs())
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, p + norm * (buzz * amp * 0.55), sparkCore);

        if (prev != null && i > 0) {
          final double midBuzz = math.sin(buzzT * 31 + dist * 0.14);
          final Offset mid = Offset(
            (prev.dx + p.dx) * 0.5 + norm.dx * midBuzz * 2.4 * s,
            (prev.dy + p.dy) * 0.5 + norm.dy * midBuzz * 2.4 * s,
          );
          final Paint zig = Paint()
            ..strokeWidth = math.max(0.55, 1.05 * s)
            ..color = c.zig.withValues(alpha: 0.42 + 0.38 * midBuzz.abs())
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.15 * s);
          canvas.drawLine(prev, mid, zig);
          canvas.drawLine(mid, p, zig);
        }
        prev = p;
      }
    }

    final Paint halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(10.0, 26.0 * s)
      ..color = c.halo.withValues(alpha: 0.58)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 13.0 * s);
    canvas.drawPath(outlinePath, halo);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(6.0, 15.0 * s)
      ..color = c.glow.withValues(alpha: 0.88)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7.0 * s);
    canvas.drawPath(outlinePath, glow);

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 4.0 * s)
      ..color = c.rim.withValues(alpha: 1.0)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * s);
    canvas.drawPath(outlinePath, rim);
  }

  /// Bright chrome stroke on top of [HexCellPreviewLayout.paintUnifiedHexOutline] — same path, wider
  /// than the black rim so the edge reads shiny and masks the dark line.
  void _paintShadowChromeOutline(
    Canvas canvas,
    Path outlinePath,
    double strokeScale,
    SoldierDesignPalette faction,
  ) {
    final c = faction.shadowFootprintElectricColors;
    final double s = math.max(0.85, strokeScale);
    final double w = HexCellPreviewLayout.unifiedOutlineStrokeWidth(
      strokeScale,
    );

    final Paint outerBloom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 2.4
      ..color = c.chromeBloom.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * s);
    canvas.drawPath(outlinePath, outerBloom);

    final Paint midSheen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 1.42
      ..color = c.chromeMid.withValues(alpha: 0.92)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.1 * s);
    canvas.drawPath(outlinePath, midSheen);

    final Paint hotCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 1.12
      ..color = c.chromeHot.withValues(alpha: 0.98);
    canvas.drawPath(outlinePath, hotCore);

    final double shimmer = 0.5 + 0.5 * math.sin(effectT * 6.2);
    final Paint specular = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, w * 0.55)
      ..color = Color.lerp(
        const Color(0xFFFFFFFF),
        c.chromeSpecularTint,
        0.35 + 0.25 * shimmer,
      )!.withValues(alpha: 0.85 + 0.12 * shimmer);
    canvas.drawPath(outlinePath, specular);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset worldOrigin = Offset(boardOffset.dx, boardOffset.dy);
    final List<_ProjectedHexPolygon> projected = <_ProjectedHexPolygon>[];
    final Offset? shadowHighlightLocal = _localCenterUnderShadow(
      boardOffset,
      shadowAnchorWorldY,
    );
    final Rect cullRect = _expandedViewportCullRect(size);

    if (paintLayer == _BoardPaintLayer.shadowHighlight) {
      if (shadowHighlightLocal == null) {
        return;
      }
      final Offset worldCenter = shadowHighlightLocal + worldOrigin;
      if (!_roughProjectedHexBounds(worldCenter, size).overlaps(cullRect)) {
        return;
      }
      final _ProjectedHexPolygon? shadowPolygon = _projectHex(
        worldCenter,
        size,
      );
      if (shadowPolygon == null ||
          !_finalProjectedCullBounds(shadowPolygon).overlaps(cullRect)) {
        return;
      }
      final SoldierDesignPalette glowFaction = _territoryFaction(
        shadowHighlightLocal,
      );
      _paintShadowFootprintGlow(
        canvas,
        shadowPolygon.path,
        shadowPolygon.strokeScale,
        glowFaction,
      );
      HexCellPreviewLayout.paintUnifiedHexOutline(
        canvas,
        shadowPolygon.path,
        shadowPolygon.strokeScale,
      );
      _paintShadowChromeOutline(
        canvas,
        shadowPolygon.path,
        shadowPolygon.strokeScale,
        glowFaction,
      );
      return;
    }

    for (final Offset localCenter in _baseLandTileCenters) {
      final Offset worldCenter = localCenter + worldOrigin;
      if (!_roughProjectedHexBounds(worldCenter, size).overlaps(cullRect)) {
        continue;
      }
      final _ProjectedHexPolygon? polygon = _projectHex(worldCenter, size);
      if (polygon == null) continue;
      if (!_finalProjectedCullBounds(polygon).overlaps(cullRect)) {
        continue;
      }
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
      final bool isShadowStepCell =
          shadowHighlightLocal != null &&
          polygon.localCenter != null &&
          (polygon.localCenter! - shadowHighlightLocal).distanceSquared < 1.0;

      if (paintLayer == _BoardPaintLayer.hexMesh) {
        final HexCellPreviewStyle cellStyle = hexCellStyleForStrengthLevel(
          polygon.level,
        );
        final Path innerPath = _buildScaledInnerPath(
          polygon.path,
          polygon.center,
          _fixedInnerScale,
        );
        final Path fillPath = switch (meshMode) {
          Pseudo3DMeshMode.outlineTransparent => Path.combine(
            PathOperation.difference,
            polygon.path,
            innerPath,
          ),
          Pseudo3DMeshMode.outlineHalfTransparent => Path.combine(
            PathOperation.difference,
            polygon.path,
            innerPath,
          ),
          _ => polygon.path,
        };

        if (cellStyle.usesVariantPaint && meshMode != Pseudo3DMeshMode.solid) {
          final SoldierDesignPalette faction =
              polygon.faction ?? SoldierDesignPalette.red;
          final CellCorePalette palette = CellCorePalette.fromTerritoryField(
            faction: faction,
            strengthLevel: polygon.level,
          );
          HexCellStylesPaint.paintProjectedCell(
            canvas,
            style: cellStyle,
            palette: palette,
            center: polygon.center,
            outerVertices: polygon.outerVertices,
            outerRadius: polygon.outerRadius,
            strokeScale: polygon.strokeScale,
            boardEffectTimeSec: effectT,
            boardFaction: faction,
          );
          if (!isShadowStepCell) {
            HexCellPreviewLayout.paintUnifiedHexOutline(
              canvas,
              polygon.path,
              polygon.strokeScale,
            );
          }
        } else {
          final SoldierDesignPalette faction =
              polygon.faction ?? SoldierDesignPalette.red;
          final CellCorePalette pal = CellCorePalette.fromTerritoryField(
            faction: faction,
            strengthLevel: polygon.level,
          );
          Color fillColor = polygon.fillColor;
          if (cellStyle == HexCellPreviewStyle.l1) {
            fillColor = pal.componentIndex1;
          }
          canvas.drawPath(fillPath, Paint()..color = fillColor);
          if (meshMode == Pseudo3DMeshMode.outlineHalfTransparent) {
            canvas.drawPath(innerPath, Paint()..color = pal.innerHexHolePaint);
          }
          if (!isShadowStepCell) {
            HexCellPreviewLayout.paintUnifiedHexOutline(
              canvas,
              polygon.path,
              polygon.strokeScale,
            );
          }
        }
      } else if ((paintLayer == _BoardPaintLayer.warEffectsBehindSoldier ||
              paintLayer == _BoardPaintLayer.warEffectsInFrontOfSoldier) &&
          polygon.isWarCell &&
          _shouldShowBoundaryWarVfx(polygon)) {
        final bool effectBehindSoldier = polygon.center.dy <= soldierScreenY;
        if (paintLayer == _BoardPaintLayer.warEffectsBehindSoldier &&
            effectBehindSoldier) {
          _paintSlimeLose(canvas, polygon);
        } else if (paintLayer == _BoardPaintLayer.warEffectsInFrontOfSoldier &&
            !effectBehindSoldier) {
          _paintSlimeLose(canvas, polygon);
        }
      }
    }
  }

  void _paintSlimeLose(Canvas canvas, _ProjectedHexPolygon polygon) {
    final Offset? local = polygon.localCenter;
    if (local == null) {
      return;
    }
    final int q = (local.dx / (_baseRadius * 1.5)).round();
    final int r = ((local.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
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
    final double activeDuration = _level4SyncedSteps * _level4FrameDurationSec;
    final double cycleDuration = activeDuration + _level4PauseSec;
    final double tInCycle = effectT % cycleDuration;
    if (tInCycle >= activeDuration) {
      return;
    }
    final double visibilityScale = _level4VisibilityScale(
      tInCycle,
      activeDuration,
    );
    if (visibilityScale < 1e-5) {
      return;
    }
    final int step = (tInCycle / _level4FrameDurationSec).floor().clamp(
      0,
      _level4SyncedSteps - 1,
    );
    final int frameIndex = _isWinBattleEffect(design) ? step % 6 : step % 9;
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
      final double left = pivotTarget.dx - tune.mascotPivotX * overlayWidth;
      final double top = pivotTarget.dy - tune.mascotPivotY * overlayHeight;
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
    final _ProjectedPoint center = _projectPointStatic(
      worldCenter.dx,
      worldCenter.dy,
      size,
      zoom: zoom,
    );
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

    final double outerRadius = (projectedVertices[0] - center.screen).distance;

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

  Path _buildScaledInnerPath(Path outerPath, Offset center, double innerScale) {
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
    Size size, {
    required double zoom,
  }) {
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
        5 => 1,
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
    final (int q, int r) = _StrategicBoardScoring._axialOf(center);
    return session.ownerForCell(q, r);
  }

  int _strengthLevel(Offset localCenter) {
    final (int q, int r) = _StrategicBoardScoring._axialOf(localCenter);
    return session.levelForCell(q, r);
  }

  bool _isWarCell(Offset localCenter, SoldierDesignPalette faction) {
    final int q = (localCenter.dx / (_baseRadius * 1.5)).round();
    final int r = ((localCenter.dy / (_baseRadius * math.sqrt(3))) - q / 2)
        .round();
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
    final int r = ((local.dy / (_baseRadius * math.sqrt(3))) - q / 2).round();
    return _isBoundaryWarVfxSlot(q, r);
  }

  bool _isMagicCell(Offset localCenter) {
    final int q = (localCenter.dx / (_baseRadius * 1.5)).round();
    final int r = ((localCenter.dy / (_baseRadius * math.sqrt(3))) - q / 2)
        .round();
    final int hash =
        ((q * 73856093) ^ (r * 19349663) ^ 0x1BADC0DE) & 0x7fffffff;
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
    final Offset currentAnchorLocal = Offset(
      -currentOffset.dx,
      anchorWorldY - currentOffset.dy,
    );
    final Offset proposedAnchorLocal = Offset(
      -proposedOffset.dx,
      anchorWorldY - proposedOffset.dy,
    );

    if (_isPointInsideLand(proposedAnchorLocal, hexGap)) {
      return proposedOffset;
    }

    final Offset currentInside = _isPointInsideLand(currentAnchorLocal, hexGap)
        ? currentAnchorLocal
        : _clampPointToLand(currentAnchorLocal, hexGap);
    final Offset proposedClamped = _clampPointToLand(
      proposedAnchorLocal,
      hexGap,
    );
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
      final double tangentDot = delta.dx * tangent.dx + delta.dy * tangent.dy;
      final Offset tangentDir = tangentDot >= 0
          ? tangent
          : Offset(-tangent.dx, -tangent.dy);
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

    final double t =
        (((p.dx - a.dx) * ab.dx) + ((p.dy - a.dy) * ab.dy)) / length2;
    final double clampedT = t.clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * clampedT, a.dy + ab.dy * clampedT);
  }

  @override
  bool shouldRepaint(covariant _Pseudo3DBoardPainter oldDelegate) {
    return oldDelegate.session != session ||
        oldDelegate.boardOffset != boardOffset ||
        oldDelegate.meshMode != meshMode ||
        oldDelegate.zoom != zoom ||
        oldDelegate.effectT != effectT ||
        oldDelegate.soldierScreenY != soldierScreenY ||
        oldDelegate.shadowAnchorWorldY != shadowAnchorWorldY ||
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

  static const double _landExtentX =
      _baseRadius * (1 + 1.5 * (_landSideHexes - 1));
  static final List<Offset> _baseLandTileCenters = _buildLandTileCenters();
  static final Map<_HexAxial, Offset> _baseLandCentersByAxial =
      <_HexAxial, Offset>{
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

class _StrategicBoardScoring {
  static _BoardAggregateScores buildAggregateScores(
    GameSessionState session,
    SoldierDesignPalette playerFaction,
  ) {
    final Map<SoldierDesignPalette, int> countryCellCounts = session
        .ownedCellCounts();
    final Map<SoldierDesignPalette, int> landPowerByFaction =
        <SoldierDesignPalette, int>{
          for (final SoldierDesignPalette faction
              in SoldierDesignPalette.values)
            faction: 0,
        };
    final Map<SoldierDesignPalette, int> totalTributeByFaction =
        <SoldierDesignPalette, int>{
          for (final SoldierDesignPalette faction
              in SoldierDesignPalette.values)
            faction: 0,
        };
    final Map<SoldierDesignPalette, int> enemyKillsByFaction =
        <SoldierDesignPalette, int>{
          for (final SoldierDesignPalette faction
              in SoldierDesignPalette.values)
            faction: 0,
        };
    final Map<SoldierRarity, int> rarityCounts = <SoldierRarity, int>{
      for (final SoldierRarity rarity in SoldierRarity.values) rarity: 0,
    };
    int moneyCollected = 0;

    for (final Offset localCenter
        in _Pseudo3DBoardPainter._baseLandTileCenters) {
      final (int q, int r) = _axialOf(localCenter);
      final SoldierDesignPalette faction = session.ownerForCell(q, r);
      final int level = session.levelForCell(q, r);
      final Map<SoldierDesignPalette, int> cellScores = session.scoresForCell(
        q,
        r,
      );

      landPowerByFaction[faction] = (landPowerByFaction[faction] ?? 0) + level;
      for (final SoldierDesignPalette tributeFaction
          in SoldierDesignPalette.values) {
        totalTributeByFaction[tributeFaction] =
            (totalTributeByFaction[tributeFaction] ?? 0) +
            (cellScores[tributeFaction] ?? 0);
      }

      if (faction != playerFaction) {
        continue;
      }

      moneyCollected += 12 + level * 5;

      if (!_Pseudo3DBoardPainter._isBoundaryWarVfxSlot(q, r)) {
        continue;
      }

      for (final SoldierDesignPalette enemy in _enemyNeighborsOf(
        session,
        localCenter,
        faction,
      )) {
        enemyKillsByFaction[enemy] =
            (enemyKillsByFaction[enemy] ?? 0) + (1 + level);
      }
    }

    for (final SoldierDesign design in kProductionSoldierDesignCatalog) {
      rarityCounts[design.rarity] = (rarityCounts[design.rarity] ?? 0) + 1;
    }

    final int totalEnemyKills = enemyKillsByFaction.entries
        .where(
          (MapEntry<SoldierDesignPalette, int> e) => e.key != playerFaction,
        )
        .fold<int>(
          0,
          (int sum, MapEntry<SoldierDesignPalette, int> e) => sum + e.value,
        );
    final int totalExp = moneyCollected + totalEnemyKills * 18;
    int level = 1;
    int expToNextLevel = 140;
    int currentExp = totalExp;
    while (currentExp >= expToNextLevel) {
      currentExp -= expToNextLevel;
      level += 1;
      expToNextLevel = 140 + (level - 1) * 35;
    }

    return _BoardAggregateScores(
      countryCellCounts: countryCellCounts,
      landPowerByFaction: landPowerByFaction,
      totalTributeByFaction: totalTributeByFaction,
      enemyKillsByFaction: enemyKillsByFaction,
      moneyCollected: moneyCollected,
      personalLevel: level,
      currentExp: currentExp,
      expToNextLevel: expToNextLevel,
      distinctSoldierCount: kProductionSoldierDesignCatalog.length,
      rarityCounts: rarityCounts,
    );
  }

  static Set<SoldierDesignPalette> _enemyNeighborsOf(
    GameSessionState session,
    Offset localCenter,
    SoldierDesignPalette faction,
  ) {
    final (int q, int r) = _axialOf(localCenter);
    const List<(int, int)> neighbors = <(int, int)>[
      (1, 0),
      (1, -1),
      (0, -1),
      (-1, 0),
      (-1, 1),
      (0, 1),
    ];
    final Set<SoldierDesignPalette> enemies = <SoldierDesignPalette>{};
    for (final (int dq, int dr) in neighbors) {
      final Offset? neighborCenter = _Pseudo3DBoardPainter
          ._baseLandCentersByAxial[_HexAxial(q + dq, r + dr)];
      if (neighborCenter == null) {
        continue;
      }
      final (int nq, int nr) = _axialOf(neighborCenter);
      final SoldierDesignPalette neighborFaction = session.ownerForCell(nq, nr);
      if (neighborFaction != faction) {
        enemies.add(neighborFaction);
      }
    }
    return enemies;
  }

  static (int, int) _axialOf(Offset localCenter) {
    final int q = (localCenter.dx / (_Pseudo3DBoardPainter._baseRadius * 1.5))
        .round();
    final int r =
        ((localCenter.dy / (_Pseudo3DBoardPainter._baseRadius * math.sqrt(3))) -
                q / 2)
            .round();
    return (q, r);
  }
}

class _BoardAggregateScores {
  const _BoardAggregateScores({
    required this.countryCellCounts,
    required this.landPowerByFaction,
    required this.totalTributeByFaction,
    required this.enemyKillsByFaction,
    required this.moneyCollected,
    required this.personalLevel,
    required this.currentExp,
    required this.expToNextLevel,
    required this.distinctSoldierCount,
    required this.rarityCounts,
  });

  final Map<SoldierDesignPalette, int> countryCellCounts;
  final Map<SoldierDesignPalette, int> landPowerByFaction;
  final Map<SoldierDesignPalette, int> totalTributeByFaction;
  final Map<SoldierDesignPalette, int> enemyKillsByFaction;
  final int moneyCollected;
  final int personalLevel;
  final int currentExp;
  final int expToNextLevel;
  final int distinctSoldierCount;
  final Map<SoldierRarity, int> rarityCounts;
}

enum _HudPanelKind { kingdom, land, heroProfile, heroArmy }

class _HudScorePanelModel {
  const _HudScorePanelModel({
    required this.kind,
    required this.title,
    required this.themeFaction,
    required this.rows,
    this.subtitle,
    this.heroStats,
    this.panelIcon,
    this.session,
    this.kingdomSections,
  });

  final _HudPanelKind kind;
  final String title;
  final String? subtitle;
  final SoldierDesignPalette themeFaction;
  final List<_HudScoreRowModel> rows;
  final _HudHeroStats? heroStats;
  final _HudPanelIconData? panelIcon;
  final GameSessionState? session;
  final List<_HudKingdomMetricSection>? kingdomSections;
}

class _HudPanelIconData {
  const _HudPanelIconData({
    required this.assetPath,
    required this.imageScale,
    required this.imageOffset,
  });

  final String assetPath;
  final double imageScale;
  final Offset imageOffset;
}

class _HudHeroStats {
  const _HudHeroStats({
    required this.level,
    required this.currentExp,
    required this.expToNextLevel,
    required this.distinctSoldiers,
    required this.moneyCollected,
    required this.rarityCounts,
    required this.joystickAssetPath,
    required this.joystickImageScale,
    required this.joystickImageOffset,
  });

  final int level;
  final int currentExp;
  final int expToNextLevel;
  final int distinctSoldiers;
  final int moneyCollected;
  final Map<SoldierRarity, int> rarityCounts;
  final String joystickAssetPath;
  final double joystickImageScale;
  final Offset joystickImageOffset;
}

class _HudScoreRowModel {
  const _HudScoreRowModel({
    required this.faction,
    required this.label,
    required this.value,
    this.delta = 0,
    this.emphasis = false,
    this.valuePrefix = '',
  });

  final SoldierDesignPalette faction;
  final String label;
  final int value;
  final int delta;
  final bool emphasis;
  final String valuePrefix;
}

class _HudKingdomMetricSection {
  const _HudKingdomMetricSection({required this.label, required this.values});

  final String label;
  final Map<SoldierDesignPalette, int> values;
}

class _HudScorePanelCard extends StatelessWidget {
  const _HudScorePanelCard({required this.model});

  final _HudScorePanelModel model;

  @override
  Widget build(BuildContext context) {
    final List<Color> theme = factionTierList(model.themeFaction);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme[0].withValues(alpha: 0.12),
          const Color(0xE20B1020),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme[2].withValues(alpha: 0.62), width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme[1].withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
        child: switch (model.kind) {
          _HudPanelKind.kingdom => _HudKingdomPanelBody(model: model),
          _HudPanelKind.land => _HudLandPanelBody(model: model),
          _HudPanelKind.heroProfile => _HudHeroProfilePanelBody(model: model),
          _HudPanelKind.heroArmy => _HudHeroArmyPanelBody(model: model),
        },
      ),
    );
  }
}

class _HudKingdomPanelBody extends StatelessWidget {
  const _HudKingdomPanelBody({required this.model});

  final _HudScorePanelModel model;

  @override
  Widget build(BuildContext context) {
    final List<Color> theme = factionTierList(model.themeFaction);
    final _HudPanelIconData icon = model.panelIcon!;
    final List<_HudKingdomMetricSection> sections =
        model.kingdomSections ?? const <_HudKingdomMetricSection>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _HudPanelHeader(model: model, accent: theme[2]),
            ),
            SizedBox(
              width: 27,
              height: 27,
              child: _HudFactionAvatar(
                assetPath: icon.assetPath,
                imageScale: icon.imageScale,
                imageOffset: icon.imageOffset,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 43,
              height: 41,
              child: CustomPaint(
                painter: _HudKingdomMinimapPainter(
                  session: model.session!,
                  themeFaction: model.themeFaction,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < sections.length; i++) ...<Widget>[
                    _HudKingdomMetricSectionView(section: sections[i]),
                    if (i != sections.length - 1) const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HudLandPanelBody extends StatelessWidget {
  const _HudLandPanelBody({required this.model});

  final _HudScorePanelModel model;

  @override
  Widget build(BuildContext context) {
    final List<Color> theme = factionTierList(model.themeFaction);
    final _HudPanelIconData icon = model.panelIcon!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _HudPanelHeader(model: model, accent: theme[2]),
            ),
            SizedBox(
              width: 27,
              height: 27,
              child: _HudFactionAvatar(
                assetPath: icon.assetPath,
                imageScale: icon.imageScale,
                imageOffset: icon.imageOffset,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (int i = 0; i < model.rows.length; i++) ...<Widget>[
          _HudFactionScoreRow(model: model.rows[i]),
          if (i != model.rows.length - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }
}

class _HudKingdomMetricSectionView extends StatelessWidget {
  const _HudKingdomMetricSectionView({required this.section});

  final _HudKingdomMetricSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          section.label,
          style: const TextStyle(
            color: Color(0xCCF7FBFF),
            fontSize: 8.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: SoldierDesignPalette.values
              .map(
                (SoldierDesignPalette faction) => Expanded(
                  child: _HudFactionDotValue(
                    faction: faction,
                    value: section.values[faction] ?? 0,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _HudHeroProfilePanelBody extends StatelessWidget {
  const _HudHeroProfilePanelBody({required this.model});

  final _HudScorePanelModel model;

  @override
  Widget build(BuildContext context) {
    final _HudHeroStats stats = model.heroStats!;
    final List<Color> theme = factionTierList(model.themeFaction);
    final double progress = stats.expToNextLevel <= 0
        ? 0
        : stats.currentExp / stats.expToNextLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _HudPanelHeader(model: model, accent: theme[2]),
            ),
            SizedBox(
              width: 27,
              height: 27,
              child: _HudFactionAvatar(
                assetPath: stats.joystickAssetPath,
                imageScale: stats.joystickImageScale,
                imageOffset: stats.joystickImageOffset,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            _HudHeroMetricPill(
              label: 'Lvl',
              value: stats.level.toString(),
              color: theme[2],
            ),
            const SizedBox(width: 4),
            _HudHeroMetricPill(
              label: 'Gold',
              value: '\$${_formatCompactInt(stats.moneyCollected)}',
              color: theme[3],
            ),
            const SizedBox(width: 4),
            _HudHeroMetricPill(
              label: 'Owned',
              value: stats.distinctSoldiers.toString(),
              color: theme[4],
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(theme[2]),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'EXP ${stats.currentExp}/${stats.expToNextLevel}',
          style: const TextStyle(
            color: Color(0xFFF7FBFF),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HudHeroArmyPanelBody extends StatelessWidget {
  const _HudHeroArmyPanelBody({required this.model});

  final _HudScorePanelModel model;

  @override
  Widget build(BuildContext context) {
    final _HudHeroStats stats = model.heroStats!;
    final List<Color> theme = factionTierList(model.themeFaction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HudPanelHeader(model: model, accent: theme[2]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: SoldierRarity.values
              .map(
                (SoldierRarity rarity) => _HudRarityChip(
                  rarity: rarity,
                  count: stats.rarityCounts[rarity] ?? 0,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 5),
        for (int i = 0; i < model.rows.length; i++) ...<Widget>[
          _HudFactionScoreRow(model: model.rows[i], compact: true),
          if (i != model.rows.length - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }
}

class _HudPanelHeader extends StatelessWidget {
  const _HudPanelHeader({required this.model, required this.accent});

  final _HudScorePanelModel model;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          model.title,
          style: TextStyle(
            color: accent.withValues(alpha: 0.98),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.15,
          ),
        ),
        if (model.subtitle != null)
          Text(
            model.subtitle!,
            style: const TextStyle(
              color: Color(0xFFF7FBFF),
              fontSize: 8.0,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _HudFactionScoreRow extends StatelessWidget {
  const _HudFactionScoreRow({required this.model, this.compact = false});

  final _HudScoreRowModel model;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = factionTierColor(
      model.faction,
      model.emphasis ? 2 : 3,
    );
    final String valueText =
        '${model.valuePrefix}${_formatCompactInt(model.value)}';
    final double labelSize = compact ? 8.4 : 8.9;
    final double valueSize = compact ? 8.9 : 9.6;
    return Row(
      children: <Widget>[
        Container(
          width: compact ? 5 : 6,
          height: compact ? 5 : 6,
          decoration: BoxDecoration(
            color: chipColor,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: chipColor.withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 0.4,
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 4 : 5),
        Expanded(
          child: Text(
            model.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelSize,
              fontWeight: model.emphasis ? FontWeight.w900 : FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          valueText,
          style: TextStyle(
            color: chipColor.withValues(alpha: 0.98),
            fontSize: valueSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HudFactionDotValue extends StatelessWidget {
  const _HudFactionDotValue({required this.faction, required this.value});

  final SoldierDesignPalette faction;
  final int value;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = factionTierColor(faction, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: chipColor,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: chipColor.withValues(alpha: 0.4),
                blurRadius: 5,
                spreadRadius: 0.3,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _formatCompactInt(value),
            style: TextStyle(
              color: chipColor.withValues(alpha: 0.98),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HudFactionAvatar extends StatelessWidget {
  const _HudFactionAvatar({
    required this.assetPath,
    required this.imageScale,
    required this.imageOffset,
    required this.theme,
  });

  final String assetPath;
  final double imageScale;
  final Offset imageOffset;
  final List<Color> theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme[1].withValues(alpha: 0.14),
        border: Border.all(color: theme[2].withValues(alpha: 0.58)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme[1].withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: Transform.translate(
            offset: imageOffset,
            child: Transform.scale(
              scale: imageScale,
              child: Image.asset(assetPath, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudHeroMetricPill extends StatelessWidget {
  const _HudHeroMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF7FBFF),
                  fontSize: 7.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 0.5),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudRarityChip extends StatelessWidget {
  const _HudRarityChip({required this.rarity, required this.count});

  final SoldierRarity rarity;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rarity.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: rarity.accentColor.withValues(alpha: 0.52)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '${rarity.label} $count',
          style: TextStyle(
            color: rarity.accentColor,
            fontSize: 7.6,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HudKingdomMinimapPainter extends CustomPainter {
  _HudKingdomMinimapPainter({
    required this.session,
    required this.themeFaction,
  });

  final GameSessionState session;
  final SoldierDesignPalette themeFaction;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0x90060A14));

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = factionTierColor(themeFaction, 2).withValues(alpha: 0.62);
    canvas.drawRRect(frame, border);

    final double minX = -_Pseudo3DBoardPainter._landExtentX;
    final double maxX = _Pseudo3DBoardPainter._landExtentX;
    final double minY = -_Pseudo3DBoardPainter.landExtentY;
    final double maxY = _Pseudo3DBoardPainter.landExtentY;
    final double width = maxX - minX;
    final double height = maxY - minY;
    final double usableW = size.width - 8;
    final double usableH = size.height - 8;

    for (final Offset localCenter
        in _Pseudo3DBoardPainter._baseLandTileCenters) {
      final (int q, int r) = _StrategicBoardScoring._axialOf(localCenter);
      final SoldierDesignPalette faction = session.ownerForCell(q, r);
      final int level = session.levelForCell(q, r);
      final int tier = switch (level) {
        5 => 1,
        4 => 1,
        3 => 2,
        2 => 3,
        _ => 4,
      };
      final double nx = (localCenter.dx - minX) / width;
      final double ny = (localCenter.dy - minY) / height;
      final Offset p = Offset(4 + nx * usableW, 4 + (1 - ny) * usableH);
      canvas.drawCircle(
        p,
        1.25,
        Paint()..color = factionTierColor(faction, tier),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HudKingdomMinimapPainter oldDelegate) {
    return oldDelegate.themeFaction != themeFaction ||
        oldDelegate.session != session;
  }
}

String _formatCompactInt(int value) {
  if (value >= 10000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toString();
}
