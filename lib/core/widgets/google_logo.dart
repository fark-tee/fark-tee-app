import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The multicolor Google "G" mark, drawn as a ring of four arcs plus the
/// short arm that plugs into the gap - matches the real logo's construction
/// rather than an arbitrary path trace.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);
  static const _gapDeg = 35.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final ringRect = Rect.fromCircle(
      center: center,
      radius: outerRadius - strokeWidth / 2,
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    void arc(double startDeg, double endDeg, Color color) {
      canvas.drawArc(
        ringRect,
        startDeg * math.pi / 180,
        (endDeg - startDeg) * math.pi / 180,
        false,
        ringPaint..color = color,
      );
    }

    arc(_gapDeg, 125, _green);
    arc(125, 215, _yellow);
    arc(215, 305, _red);
    arc(305, 360 + _gapDeg, _blue);

    final armPaint = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - strokeWidth * 0.1,
        center.dy - strokeWidth / 2,
        center.dx + outerRadius,
        center.dy + strokeWidth / 2,
      ),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
