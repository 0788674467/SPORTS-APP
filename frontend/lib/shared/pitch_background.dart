import 'package:flutter/material.dart';

/// Glowing dark-purple football pitch background used by Coach & Referee dashboards.
class PitchBackground extends StatelessWidget {
  final Widget child;
  const PitchBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Dark purple gradient base
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color(0xFF12012A), Color(0xFF0A0F1E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
      ),
      // Pitch lines painter with green glow
      CustomPaint(painter: _GlowingPitchPainter()),
      // Radial glow center
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x221B5E20), Color(0x00000000)],
              center: Alignment.center, radius: 0.9,
            ),
          ),
        ),
      ),
      child,
    ]);
  }
}

class _GlowingPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    // Alternating grass strips
    final stripPaint = Paint()..color = const Color(0xFF1A1A2E);
    for (int i = 0; i < 8; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(0, i * h / 8, w, h / 8), stripPaint);
      }
    }
    final line = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final glowLine = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    void drawLine(Offset a, Offset b) {
      canvas.drawLine(a, b, glowLine);
      canvas.drawLine(a, b, line);
    }

    void drawRect(Rect r) {
      canvas.drawRect(r, glowLine);
      canvas.drawRect(r, line);
    }

    void drawCircle(Offset c, double r) {
      canvas.drawCircle(c, r, glowLine);
      canvas.drawCircle(c, r, line);
    }

    // Outer border
    drawRect(Rect.fromLTWH(w * 0.04, h * 0.02, w * 0.92, h * 0.96));
    // Center line
    drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.96, h * 0.5));
    // Center circle
    drawCircle(Offset(w * 0.5, h * 0.5), w * 0.14);
    // Center spot
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 3, Paint()..color = const Color(0xFF4CAF50).withOpacity(0.4));
    // Top penalty box
    drawRect(Rect.fromLTWH(w * 0.22, h * 0.02, w * 0.56, h * 0.17));
    // Top small box
    drawRect(Rect.fromLTWH(w * 0.36, h * 0.02, w * 0.28, h * 0.08));
    // Top goal
    canvas.drawRect(Rect.fromLTWH(w * 0.42, 0, w * 0.16, h * 0.025),
        line..color = const Color(0xFF4CAF50).withOpacity(0.25));
    // Bottom penalty box
    drawRect(Rect.fromLTWH(w * 0.22, h * 0.81, w * 0.56, h * 0.17));
    // Bottom small box
    drawRect(Rect.fromLTWH(w * 0.36, h * 0.90, w * 0.28, h * 0.08));
    // Bottom goal
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.975, w * 0.16, h * 0.025),
        line..color = const Color(0xFF4CAF50).withOpacity(0.25));
    // Corner arcs
    final cornerPaint = Paint()..color = const Color(0xFF4CAF50).withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.04, h * 0.02), radius: w * 0.04), 0, 1.57, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.96, h * 0.02), radius: w * 0.04), 1.57, 1.57, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.04, h * 0.98), radius: w * 0.04), -1.57, 1.57, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.96, h * 0.98), radius: w * 0.04), 1.57, 1.57, false, cornerPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
