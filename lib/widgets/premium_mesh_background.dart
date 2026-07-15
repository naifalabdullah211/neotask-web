import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium dark backdrop — replaces the previous "mesh gradient" (4
/// blurred rainbow-colored blobs on a purple/navy base), which is a
/// recognizable generic-AI-dashboard visual signature. This version uses:
///   1. A deep monochrome ink gradient (navy → slate → charcoal-teal),
///      no bright hues.
///   2. A single, subtle gold radial glow anchored at the top (restrained
///      "legendary" accent instead of scattered rainbow blobs).
///   3. A faint diagonal hairline pattern for tactile depth, instead of
///      soft blur circles — reads as a deliberately art-directed surface
///      rather than a generated gradient mesh.
class PremiumMeshBackground extends StatelessWidget {
  const PremiumMeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Stack(
        children: [
          // Single restrained gold glow, top-anchored — the ONLY warm
          // accent in the whole background, so it reads as intentional.
          Align(
            alignment: const Alignment(0.4, -1.15),
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.16),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Fine diagonal line texture — subtle, low-alpha, gives the
          // dark surface a woven/engraved quality instead of flat gradient.
          Positioned.fill(child: CustomPaint(painter: _HairlinePainter())),
          // Bottom vignette to deepen the lower edge (grounds content
          // placed near the bottom of the screen).
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HairlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const spacing = 26.0;
    // Diagonal lines from bottom-left to top-right across the full canvas.
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
