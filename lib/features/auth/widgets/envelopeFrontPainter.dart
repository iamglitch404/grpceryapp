import 'package:flutter/material.dart';

class EnvelopeFrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF266144)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final bottomPaint = Paint()
      ..color = const Color(0xFF1B4933)
      ..style = PaintingStyle.fill;

    final bottomPath = Path();
    bottomPath.moveTo(0, size.height);
    bottomPath.lineTo(size.width / 2, size.height * 0.4);
    bottomPath.lineTo(size.width, size.height);
    bottomPath.close();

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

