import 'package:flutter/material.dart';

import '../../core/widgets/animated_logo_mark.dart';

/// Full-screen splash that sits on top of the home screen until [ready]
/// resolves. The mark plays its own out-animation (bars retract, stroke
/// un-draws) rather than just being faded — the backdrop only fades once
/// that finishes, clearing to reveal the already fully-loaded dashboard.
class HomeSplashOverlay extends StatefulWidget {
  const HomeSplashOverlay({super.key, required this.ready});

  final Future<void> ready;

  @override
  State<HomeSplashOverlay> createState() => _HomeSplashOverlayState();
}

class _HomeSplashOverlayState extends State<HomeSplashOverlay>
    with SingleTickerProviderStateMixin {
  // Floor so the sequence always reads as in -> loop -> out: the mark's
  // draw-on alone takes ~950ms, so this leaves it a beat of visible idle
  // loop even when data comes back instantly, instead of racing straight
  // into the exit the moment the draw-on lands.
  static const _minEntryDuration = Duration(milliseconds: 1500);

  late final AnimationController _backdropFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _backdropT = CurvedAnimation(
    parent: _backdropFade,
    curve: Curves.easeIn,
  );

  bool _startExit = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.wait([widget.ready, Future.delayed(_minEntryDuration)]);
    if (!mounted) return;
    setState(() => _startExit = true);
  }

  Future<void> _handleMarkExitComplete() async {
    await _backdropFade.forward();
    if (!mounted) return;
    setState(() => _removed = true);
  }

  @override
  void dispose() {
    _backdropFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _backdropFade,
        builder: (context, child) =>
            Opacity(opacity: 1 - _backdropT.value, child: child),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: LogoLoadingMark(
              size: 120,
              exiting: _startExit,
              onExitComplete: _handleMarkExitComplete,
            ),
          ),
        ),
      ),
    );
  }
}
