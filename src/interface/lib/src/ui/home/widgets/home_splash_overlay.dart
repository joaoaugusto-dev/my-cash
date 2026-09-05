import 'package:flutter/material.dart';

import '../../core/widgets/animated_logo_mark.dart';

const _appName = 'MyCash';
const _signature = 'joaoaugusto.dev';

// How long the name takes to type on — the signature's own entrance is
// timed off this so it appears right as the name finishes, without the two
// needing to share a controller across separate parts of the tree.
const _typeDuration = Duration(milliseconds: 65 * _appName.length);

/// Full-screen splash that sits on top of the home screen until [ready]
/// resolves. The mark plays its own out-animation (bars retract, stroke
/// un-draws) rather than just being faded — the backdrop only fades once
/// that finishes, clearing to reveal the already fully-loaded dashboard.
class HomeSplashOverlay extends StatefulWidget {
  const HomeSplashOverlay({super.key, required this.ready, this.onDismissed});

  final Future<void> ready;

  /// Fired once the overlay has cleared, so whatever comes next (the
  /// first-run tour) starts on a settled screen instead of over the splash.
  final VoidCallback? onDismissed;

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
    widget.onDismissed?.call();
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
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LogoLoadingMark(
                      size: 120,
                      exiting: _startExit,
                      onExitComplete: _handleMarkExitComplete,
                    ),
                    const SizedBox(height: 20),
                    _AppNameType(exiting: _startExit),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Center(child: _Signature(exiting: _startExit)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App name typed on letter by letter, right under the mark.
class _AppNameType extends StatefulWidget {
  const _AppNameType({required this.exiting});

  final bool exiting;

  @override
  State<_AppNameType> createState() => _AppNameTypeState();
}

class _AppNameTypeState extends State<_AppNameType>
    with TickerProviderStateMixin {
  late final AnimationController _type = AnimationController(
    vsync: this,
    duration: _typeDuration,
  )..forward();
  late final AnimationController _exitFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant _AppNameType oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _exitFade.forward();
  }

  @override
  void dispose() {
    _type.dispose();
    _exitFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_type, _exitFade]),
      builder: (context, _) {
        final shown = (_appName.length * _type.value).round();
        return Opacity(
          opacity: 1 - _exitFade.value,
          child: Text(
            _appName.substring(0, shown),
            style: textTheme.titleLarge?.copyWith(
              letterSpacing: 1.2,
              color: colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}

/// Discreet "By: joaoaugusto.dev" credit, pinned to the bottom of the
/// screen. Fades/slides in right as the app name finishes typing, with a
/// small purple accent dot — a touch more prominent than a footnote since
/// it sits on its own down there, but still well under the name and mark.
class _Signature extends StatefulWidget {
  const _Signature({required this.exiting});

  final bool exiting;

  @override
  State<_Signature> createState() => _SignatureState();
}

class _SignatureState extends State<_Signature> with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );
  late final AnimationController _exitFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(_typeDuration, () {
      if (mounted) _fade.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _Signature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _exitFade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    _exitFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _exitFade]),
      builder: (context, _) => Opacity(
        opacity: _t.value * (1 - _exitFade.value),
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.75 * _t.value),
                ),
              ),
              Text.rich(
                TextSpan(
                  style: textTheme.bodySmall?.copyWith(letterSpacing: 0.3),
                  children: [
                    TextSpan(
                      text: 'By: ',
                      style: TextStyle(
                        color: colorScheme.primary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: _signature,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
