import 'dart:math' as math;

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
  });

  final double outerRadius;
  final double knobRadius;
  final ValueChanged<Offset> onChanged;
  final Color baseColor;
  final Color ringColor;
  final Color knobColor;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;

  double get _maxTravel => math.max(0, widget.outerRadius - widget.knobRadius);

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
    return SizedBox(
      width: s,
      height: s,
      child: GestureDetector(
        onPanDown: (DragDownDetails e) => _updateKnob(e.localPosition),
        onPanUpdate: (DragUpdateDetails e) => _updateKnob(e.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          painter: _JoystickPainter(
            knob: _knob,
            outerRadius: widget.outerRadius,
            knobRadius: widget.knobRadius,
            baseColor: widget.baseColor,
            ringColor: widget.ringColor,
            knobColor: widget.knobColor,
          ),
          size: Size(s, s),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.outerRadius,
    required this.knobRadius,
    required this.baseColor,
    required this.ringColor,
    required this.knobColor,
  });

  final Offset knob;
  final double outerRadius;
  final double knobRadius;
  final Color baseColor;
  final Color ringColor;
  final Color knobColor;

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
    final Offset k = c + knob;
    canvas.drawCircle(k, knobRadius, Paint()..color = knobColor);
    canvas.drawCircle(
      k,
      knobRadius,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.knob != knob ||
        oldDelegate.outerRadius != outerRadius ||
        oldDelegate.knobRadius != knobRadius;
  }
}
