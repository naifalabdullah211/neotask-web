import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A vector-based "mesh gradient" background: several soft, blurred radial
/// color blobs layered over a solid base, composited with a base linear
/// gradient. Produces a premium, abstract SaaS-style backdrop without any
/// photographic asset — so it scales perfectly to any viewport with zero
/// cropping and no aspect-ratio dependency.
class PremiumMeshBackground extends StatelessWidget {
  const PremiumMeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Stack(
        children: [
          _blob(
            alignment: const Alignment(-1.1, -1.0),
            color: AppColors.lightBlue.withValues(alpha: 0.35),
            size: 340,
          ),
          _blob(
            alignment: const Alignment(1.2, -0.6),
            color: AppColors.purple.withValues(alpha: 0.40),
            size: 380,
          ),
          _blob(
            alignment: const Alignment(1.1, 1.1),
            color: AppColors.green.withValues(alpha: 0.22),
            size: 320,
          ),
          _blob(
            alignment: const Alignment(-1.0, 1.2),
            color: AppColors.deepBlue.withValues(alpha: 0.30),
            size: 300,
          ),
        ],
      ),
    );
  }

  Widget _blob({
    required Alignment alignment,
    required Color color,
    required double size,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
