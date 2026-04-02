import 'package:flutter/material.dart';

import 'isosceles_triangle_vertices.dart';

/// Isosceles triangle: two long equal legs, short base on the bottom, apex up (−Y).
/// Yellow fill, black stroke. Drawn fixed in **soldier local space** (no motion vs soldier origin).
class TriangleSoldierPainter extends CustomPainter {
  TriangleSoldierPainter({
    this.side = 36,
  });

  final double side;

  static const Color _fill = Color(0xFFFFEB3B);
  static const Color _stroke = Colors.black;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final List<Offset> verts = isoscelesTriangleVerticesCentroid(legLength: side);

    final Path path = Path()
      ..moveTo(c.dx + verts[0].dx, c.dy + verts[0].dy)
      ..lineTo(c.dx + verts[1].dx, c.dy + verts[1].dy)
      ..lineTo(c.dx + verts[2].dx, c.dy + verts[2].dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant TriangleSoldierPainter oldDelegate) {
    return oldDelegate.side != side;
  }
}

/// Triangle preview for inventory; rotates with [angle], no motion vs soldier center.
class TriangleSoldier extends StatelessWidget {
  const TriangleSoldier({
    super.key,
    this.size = 48,
    this.side = 36,
    this.angle = 0,
  });

  final double size;
  final double side;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size(size, size),
        painter: TriangleSoldierPainter(side: side),
      ),
    );
  }
}
