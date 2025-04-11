import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class TripleRingLoaderPainter extends CustomPainter {
  final double pasosPercent;
  final double minutosPercent;
  final double kcalPercent;
  final bool trainedToday;

  const TripleRingLoaderPainter({
    required this.pasosPercent,
    required this.minutosPercent,
    required this.kcalPercent,
    required this.trainedToday,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width / 2 - 8;

    final radii = [
      maxRadius,
      maxRadius * 0.75,
      maxRadius * 0.5,
    ];

    final ringWidths = List.filled(3, maxRadius * 0.2);
    final percentages = [
      pasosPercent,
      minutosPercent,
      kcalPercent,
    ];
    final colors = [
      AppColors.accentColor,
      AppColors.mutedRed,
      AppColors.mutedAdvertencia,
    ];

    for (int i = 0; i < 3; i++) {
      final backgroundPaint = Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidths[i];

      final foregroundPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ringWidths[i];

      canvas.drawCircle(center, radii[i], backgroundPaint);

      double sweepAngle = 2 * 3.1416 * percentages[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radii[i]),
        -3.1416 / 2,
        sweepAngle,
        false,
        foregroundPaint,
      );
    }

    final iconPainter = TextPainter(
      text: TextSpan(
        text: trainedToday ? '🔥' : '😴',
        style: TextStyle(
          fontSize: 20,
          color: trainedToday ? AppColors.textColor : AppColors.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
