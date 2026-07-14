import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared backdrop for every top-level screen: a fixed directional gradient
/// in the app's purple, one restrained anchored glow, and a whisper of grain
/// so it reads as a designed surface rather than a flat gradient.
///
/// Deliberately *not* a cluster of floating blurred orbs — that pattern is
/// the single most overused "AI-generated app" background right now.
class FinanceBackground extends StatelessWidget {
  const FinanceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF110A22),
                    Color(0xFF1B1230),
                    Color(0xFF0D0B16),
                  ]
                : const [
                    Color(0xFFFBFAFF),
                    Color(0xFFF4F0FF),
                    Color(0xFFFFFFFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -160,
              right: -120,
              child: IgnorePointer(
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFF7C3AED,
                        ).withValues(alpha: isDark ? 0.20 : 0.12),
                        const Color(0xFF7C3AED).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: IgnorePointer(child: _Grain())),
          ],
        ),
      ),
    );
  }
}

class _Grain extends StatelessWidget {
  const _Grain();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speckColor = Theme.of(context).colorScheme.onSurface;

    return Opacity(
      opacity: isDark ? 0.05 : 0.035,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GrainPainter(speckColor),
      ),
    );
  }
}

/// Sparse, seeded static noise. Computed once per app run and reused, so the
/// per-frame cost is a single cheap paint of pre-placed dots.
class _GrainPainter extends CustomPainter {
  _GrainPainter(this.color);

  final Color color;

  static final List<Offset> _specks = List.generate(
    260,
    (_) => Offset(_random.nextDouble(), _random.nextDouble()),
  );
  static final math.Random _random = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final speck in _specks) {
      canvas.drawCircle(
        Offset(speck.dx * size.width, speck.dy * size.height),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
