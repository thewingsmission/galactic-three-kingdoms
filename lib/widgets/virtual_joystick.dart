import 'package:flutter/material.dart';

Offset clampJoystickDelta(Offset delta, double maxTravel) {
  if (delta.distance > maxTravel && maxTravel > 0) {
    return delta * (maxTravel / delta.distance);
  }
  return delta;
}

class VirtualJoystickVisual extends StatelessWidget {
  const VirtualJoystickVisual({
    super.key,
    required this.outerRadius,
    required this.knobRadius,
    required this.knobOffset,
    this.baseColor = const Color(0x33FFFFFF),
    this.ringColor = const Color(0x88FFFFFF),
    this.knobColor = const Color(0xE6FFFFFF),
    this.knobOutlineColor = const Color(0x42000000),
    this.knobAssetPath,
    this.knobImageScale = 1,
    this.knobImageOffset = Offset.zero,
  });

  final double outerRadius;
  final double knobRadius;
  final Offset knobOffset;
  final Color baseColor;
  final Color ringColor;
  final Color knobColor;
  final Color knobOutlineColor;
  final String? knobAssetPath;
  final double knobImageScale;
  final Offset knobImageOffset;

  @override
  Widget build(BuildContext context) {
    final double s = outerRadius * 2;
    final Offset center = Offset(outerRadius, outerRadius);
    final Offset knobCenter = center + knobOffset;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          CustomPaint(
            painter: _JoystickBasePainter(
              outerRadius: outerRadius,
              baseColor: baseColor,
              ringColor: ringColor,
            ),
            size: Size(s, s),
          ),
          Positioned(
            left: knobCenter.dx - knobRadius,
            top: knobCenter.dy - knobRadius,
            child: Container(
              width: knobRadius * 2,
              height: knobRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: knobColor,
                border: Border.all(color: knobOutlineColor, width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: knobAssetPath == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: Transform.translate(
                          offset: knobImageOffset,
                          child: Transform.scale(
                            scale: knobImageScale,
                            child: Image.asset(
                              knobAssetPath!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular joystick: knob stays inside the outer ring. [onChanged] receives a vector whose
/// length is in `[0, 1]` (normalized by usable travel) and direction matches screen axes.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.outerRadius,
    required this.knobRadius,
    required this.onChanged,
    this.baseColor = const Color(0x33FFFFFF),
    this.ringColor = const Color(0x88FFFFFF),
    this.knobColor = const Color(0xE6FFFFFF),
    this.knobOutlineColor = const Color(0x42000000),
    this.knobAssetPath,
    this.knobImageScale = 1,
    this.knobImageOffset = Offset.zero,
  });

  final double outerRadius;
  final double knobRadius;
  final ValueChanged<Offset> onChanged;
  final Color baseColor;
  final Color ringColor;
  final Color knobColor;
  final Color knobOutlineColor;
  final String? knobAssetPath;
  final double knobImageScale;
  final Offset knobImageOffset;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;

  double get _maxTravel => widget.outerRadius;

  void _updateKnob(Offset localPosition) {
    final double maxT = _maxTravel;
    Offset d = localPosition - Offset(widget.outerRadius, widget.outerRadius);
    d = clampJoystickDelta(d, maxT);
    setState(() => _knob = d);
    _emit(d, maxT);
  }

  void _emit(Offset d, double maxT) {
    if (maxT <= 0) {
      widget.onChanged(Offset.zero);
      return;
    }
    widget.onChanged(Offset(d.dx / maxT, d.dy / maxT));
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.outerRadius * 2,
      height: widget.outerRadius * 2,
      child: GestureDetector(
        onPanDown: (DragDownDetails e) => _updateKnob(e.localPosition),
        onPanUpdate: (DragUpdateDetails e) => _updateKnob(e.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: VirtualJoystickVisual(
          outerRadius: widget.outerRadius,
          knobRadius: widget.knobRadius,
          knobOffset: _knob,
          baseColor: widget.baseColor,
          ringColor: widget.ringColor,
          knobColor: widget.knobColor,
          knobOutlineColor: widget.knobOutlineColor,
          knobAssetPath: widget.knobAssetPath,
          knobImageScale: widget.knobImageScale,
          knobImageOffset: widget.knobImageOffset,
        ),
      ),
    );
  }
}

class _JoystickBasePainter extends CustomPainter {
  _JoystickBasePainter({
    required this.outerRadius,
    required this.baseColor,
    required this.ringColor,
  });

  final double outerRadius;
  final Color baseColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(outerRadius, outerRadius);
    canvas.drawCircle(c, outerRadius, Paint()..color = baseColor);
    canvas.drawCircle(
      c,
      outerRadius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickBasePainter oldDelegate) {
    return oldDelegate.outerRadius != outerRadius ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.ringColor != ringColor;
  }
}
