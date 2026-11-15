import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 16点のギザギザ丸シールのパス
Path _starPath(Offset center, double outer, double inner, int points) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / points;
    final p = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// 赤地・白縁・影付きのギザギザ丸を描く
class SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final inner = outer * 0.84;

    // 影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(1.5, 2.5);
    canvas.drawPath(_starPath(c, outer * 0.97, inner * 0.97, 16), shadowPaint);
    canvas.restore();

    // 白縁
    canvas.drawPath(
      _starPath(c, outer * 0.99, inner * 1.02, 16),
      Paint()..color = Colors.white,
    );

    // 赤地
    canvas.drawPath(
      _starPath(c, outer * 0.90, inner * 0.90, 16),
      Paint()..color = const Color(0xFFD32F2F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 「最安」シール（-12度に傾ける）
class SaianSeal extends StatelessWidget {
  const SaianSeal({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -12 * math.pi / 180,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            CustomPaint(painter: SealPainter(), size: Size(size, size)),
            Center(
              child: Text(
                '最安',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.32,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
