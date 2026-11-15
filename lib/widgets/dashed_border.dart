import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 점선 테두리. 색약 모드에서 '끝난 일정'을 색 대신 모양으로 구분할 때 써요.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = const Color(0xFF6B6B6B),
    this.strokeWidth = 2.5,
    this.radius = 16,
    this.dash = 8,
    this.gap = 6,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        radius: radius,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final half = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      half,
      half,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap;
}
