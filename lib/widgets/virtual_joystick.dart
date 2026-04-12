import 'package:flutter/material.dart';

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
    if (d.distance > maxT && maxT > 0) {
      d = d * (maxT / d.distance);
    }
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
    final double s = widget.outerRadius * 2;
    final Offset center = Offset(widget.outerRadius, widget.outerRadius);
    final Offset knobCenter = center + _knob;
    return SizedBox(
      width: s,
      height: s,
      child: GestureDetector(
        onPanDown: (DragDownDetails e) => _updateKnob(e.localPosition),
        onPanUpdate: (DragUpdateDetails e) => _updateKnob(e.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            CustomPaint(
              painter: _JoystickBasePainter(
                outerRadius: widget.outerRadius,
                baseColor: widget.baseColor,
                ringColor: widget.ringColor,
              ),
              size: Size(s, s),
            ),
            Positioned(
              left: knobCenter.dx - widget.knobRadius,
              top: knobCenter.dy - widget.knobRadius,
              child: Container(
                width: widget.knobRadius * 2,
                height: widget.knobRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.knobColor,
                  border: Border.all(
                    color: Colors.black26,
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.knobAssetPath == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: Transform.translate(
                            offset: widget.knobImageOffset,
                            child: Transform.scale(
                              scale: widget.knobImageScale,
                              child: Image.asset(
                                widget.knobAssetPath!,
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
