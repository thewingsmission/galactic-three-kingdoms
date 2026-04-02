import 'package:flutter/material.dart';

/// Pale red disk with black outline; drawn in soldier local space, centroid at canvas center.
class SoldierContactPainter extends CustomPainter {
  SoldierContactPainter({
    required this.radius,
    this.strokeWidth = 2,
  });

  final double radius;
  final double strokeWidth;

  static const Color _fillOpaque = Color(0xFFFFCDD2);
  static const Color _stroke = Colors.black;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint fill = Paint()
      ..color = _fillOpaque.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(c, radius, fill);
    canvas.drawCircle(c, radius, stroke);
  }

  @override
  bool shouldRepaint(covariant SoldierContactPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
  }
}
