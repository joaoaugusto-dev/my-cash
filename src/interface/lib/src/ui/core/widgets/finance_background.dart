import 'package:flutter/material.dart';

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
              top: -90,
              left: -80,
              child: _RadialGlow(
                size: 250,
                color: const Color(
                  0xFF7C3AED,
                ).withValues(alpha: isDark ? 0.22 : 0.15),
              ),
            ),
            Positioned(
              top: 130,
              right: -110,
              child: _RadialGlow(
                size: 260,
                color: const Color(
                  0xFFB993FF,
                ).withValues(alpha: isDark ? 0.18 : 0.22),
              ),
            ),
            Positioned(
              bottom: -130,
              left: 20,
              child: _RadialGlow(
                size: 280,
                color: const Color(
                  0xFF22C55E,
                ).withValues(alpha: isDark ? 0.10 : 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
