import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_cash/src/ui/core/widgets/spring_curve.dart';

/// Procedural recreation of the MyCash mark (a rising "M" chart line
/// followed by three growing bars), traced from the app icon's own vertices
/// so it draws itself on instead of just fading in as a static image.
///
/// Plays once (M draws on, bars pop up with a spring bounce), then loops a
/// gentle equalizer-style bounce on the bars until [exiting] flips to true —
/// at which point it un-animates itself (bars retract, then the stroke
/// un-draws tip-to-base) and calls [onExitComplete], instead of just being
/// faded out by a parent.
class LogoLoadingMark extends StatefulWidget {
  const LogoLoadingMark({
    super.key,
    this.size = 96,
    this.exiting = false,
    this.onExitComplete,
  });

  final double size;
  final bool exiting;
  final VoidCallback? onExitComplete;

  @override
  State<LogoLoadingMark> createState() => _LogoLoadingMarkState();
}

class _LogoLoadingMarkState extends State<LogoLoadingMark>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final Animation<double> _stroke = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _bars = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.4, 1.0, curve: Curves.linear),
  );

  // Bars retract first, then the stroke un-draws from the tip backward —
  // a real reverse of the entry, not just a fade.
  late final Animation<double> _barsExit = CurvedAnimation(
    parent: _exit,
    curve: const Interval(0.0, 0.55, curve: Curves.easeInCubic),
  );
  late final Animation<double> _strokeExit = CurvedAnimation(
    parent: _exit,
    curve: const Interval(0.4, 1.0, curve: Curves.easeInCubic),
  );

  @override
  void initState() {
    super.initState();
    _entry.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      // If `exiting` arrived before the draw-on finished (e.g. data loaded
      // faster than the entry animation), don't skip straight to the exit —
      // let the in-animation land first, then reverse it.
      if (widget.exiting) {
        _startExit();
      } else {
        _loop.repeat();
      }
    });
    _entry.forward();
  }

  @override
  void didUpdateWidget(covariant LogoLoadingMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting && _entry.isCompleted) {
      _startExit();
    }
  }

  void _startExit() {
    _loop.stop();
    _exit.forward(from: 0).whenComplete(() => widget.onExitComplete?.call());
  }

  @override
  void dispose() {
    _entry.dispose();
    _loop.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entry, _loop, _exit]),
        builder: (context, _) => CustomPaint(
          painter: _LogoMarkPainter(
            strokeProgress: _stroke.value * (1 - _strokeExit.value),
            barsProgress: _bars.value * (1 - _barsExit.value),
            pulsePhase: _loop.value,
          ),
        ),
      ),
    );
  }
}

class _BarSpec {
  const _BarSpec({
    required this.cx,
    required this.width,
    required this.top,
    required this.delay,
  });

  final double cx;
  final double width;
  final double top;
  final double delay;
}

class _LogoMarkPainter extends CustomPainter {
  _LogoMarkPainter({
    required this.strokeProgress,
    required this.barsProgress,
    required this.pulsePhase,
  });

  final double strokeProgress;
  final double barsProgress;

  /// 0..1, repeating. Drives the idle equalizer bounce once the entry
  /// animation has finished growing the bars.
  final double pulsePhase;

  // Flat colors matching the source mark exactly — no gradient.
  static const _strokeColor = Color(0xFF8B3FFC);
  static const _barColor = Color(0xFF34C77B);

  // Normalized (0..1) vertices traced from assets/logo_foreground.png.
  static const _legBottom = Offset(0.047, 1.0);
  static const _leftPeak = Offset(0.047, 0.202);
  static const _valley = Offset(0.420, 0.553);
  static const _rightPeak = Offset(0.954, 0.0);

  static const _bars = [
    _BarSpec(cx: 0.392, width: 0.096, top: 0.764, delay: 0.0),
    _BarSpec(cx: 0.591, width: 0.096, top: 0.636, delay: 0.16),
    _BarSpec(cx: 0.785, width: 0.097, top: 0.393, delay: 0.32),
  ];

  static const _bounce = SpringCurve();

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

    final path = Path()
      ..moveTo(p(_legBottom).dx, p(_legBottom).dy)
      ..lineTo(p(_leftPeak).dx, p(_leftPeak).dy)
      ..lineTo(p(_valley).dx, p(_valley).dy)
      ..lineTo(p(_rightPeak).dx, p(_rightPeak).dy);

    if (strokeProgress > 0) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.088
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _strokeColor;

      final drawn = Path();
      for (final metric in path.computeMetrics()) {
        drawn.addPath(
          metric.extractPath(0, metric.length * strokeProgress.clamp(0, 1)),
          Offset.zero,
        );
      }
      canvas.drawPath(drawn, strokePaint);
    }

    final barPaint = Paint()..color = _barColor;

    for (var i = 0; i < _bars.length; i++) {
      final bar = _bars[i];
      final t = ((barsProgress - bar.delay) / (1 - bar.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final growT = _bounce.transform(t).clamp(0.0, 1.2);
      // Idle bounce only kicks in once this bar has fully grown in.
      final idle = t >= 1
          ? 1 + 0.07 * math.sin(2 * math.pi * (pulsePhase - i * 0.18))
          : 1.0;
      final grownT = growT * idle;

      final fullTop = bar.top * size.height;
      final bottom = size.height;
      final top = (bottom - (bottom - fullTop) * grownT).clamp(0.0, bottom);

      final rect = Rect.fromLTRB(
        (bar.cx - bar.width / 2) * size.width,
        top,
        (bar.cx + bar.width / 2) * size.width,
        bottom,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(bar.width * size.width / 2),
      );
      canvas.drawRRect(rrect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoMarkPainter oldDelegate) =>
      oldDelegate.strokeProgress != strokeProgress ||
      oldDelegate.barsProgress != barsProgress ||
      oldDelegate.pulsePhase != pulsePhase;
}
