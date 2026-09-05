import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_cash/src/ui/core/theme/app_theme.dart';

String onboardingTourSeenKey(String userId) => 'onboarding_tour_seen_$userId';

/// The tour runs once per account on this device — a second account signing
/// in on the same phone still gets its own first run.
Future<bool> shouldShowOnboardingTour(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(onboardingTourSeenKey(userId)) ?? false);
}

Future<void> markOnboardingTourSeen(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(onboardingTourSeenKey(userId), true);
}

/// Keys the home screen hangs on the real widgets so the tour can spotlight
/// them one by one. Nothing here changes how those widgets render.
class OnboardingTargets {
  final GlobalKey identity = GlobalKey();
  final GlobalKey period = GlobalKey();
  final GlobalKey stats = GlobalKey();
  final GlobalKey bestCard = GlobalKey();
  final GlobalKey categories = GlobalKey();
  final GlobalKey recent = GlobalKey();
  final GlobalKey insight = GlobalKey();
  final GlobalKey createButton = GlobalKey();
  final List<GlobalKey> nav = List.generate(5, (_) => GlobalKey());
}

class _TourStep {
  const _TourStep({
    required this.page,
    required this.title,
    required this.body,
    this.target,
    this.hint,
    this.radius = AppRadii.lg,
    this.padding = 8,
  });

  /// Page the app moves to before this step — the tour drives the real
  /// bottom bar instead of describing it.
  final int page;

  /// Widget to cut out of the scrim. Null means "no spotlight": the card
  /// centers over a plain dim (used for the opening and closing steps).
  final GlobalKey? target;
  final String title;
  final String body;

  /// Shown with a touch icon when the highlighted element is worth trying
  /// right there — the cutout passes taps straight through to it.
  final String? hint;
  final double radius;
  final double padding;
}

/// First-run walkthrough. Dims everything except one element at a time and
/// leaves that element live: what is highlighted can be tapped, dragged and
/// tested for real, and the tour waits.
class OnboardingTour extends StatefulWidget {
  const OnboardingTour({
    super.key,
    required this.userId,
    required this.firstName,
    required this.targets,
    required this.onGoToPage,
    required this.onFinish,
  });

  final String userId;
  final String firstName;
  final OnboardingTargets targets;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onFinish;

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _entry,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  // Plays once per step change, gliding the spotlight from where it was to
  // the new target. It is a fixed-length leg started only on navigation —
  // never restarted mid-flight — so it can't turn into the frame-by-frame
  // chase that made the ring lag behind while scrolling. Once it finishes,
  // _syncHole's direct tracking takes back over for that step.
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Rect? _glideFrom;

  // ponytail: re-reads the target's rect every frame instead of listening to
  // scroll/page notifications the tour has no ancestor access to. Only calls
  // setState when the rect actually moved, so an idle step costs nothing —
  // and the spotlight tracks the user scrolling or swiping pages for free.
  late final Ticker _tracker = createTicker((_) => _syncHole());

  Rect? _hole;
  int _index = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _tracker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _entry.value = 1;
      } else {
        _entry.forward();
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _tracker.dispose();
    _entry.dispose();
    _pulse.dispose();
    _glide.dispose();
    super.dispose();
  }

  String get _greeting {
    final name = widget.firstName.trim();
    // 'Conta' is the app-wide fallback for an account with no name on it —
    // greeting someone as "Conta" reads worse than using no name at all.
    return name.isEmpty || name == 'Conta' ? '' : ', $name';
  }

  List<_TourStep> get _steps {
    final t = widget.targets;
    return [
      _TourStep(
        page: 0,
        title: 'Oi$_greeting! Vou te mostrar o app.',
        body:
            'Uma parte de cada vez. O que estiver aceso você pode tocar e '
            'testar na hora — o tour espera, e nada aqui é obrigatório.',
      ),
      _TourStep(
        page: 0,
        target: t.identity,
        radius: AppRadii.pill,
        title: 'Sua conta',
        body: 'Foto, nome e o atalho para o seu perfil.',
        hint: 'Pode tocar para abrir.',
      ),
      _TourStep(
        page: 0,
        target: t.period,
        title: 'O período',
        body:
            'Toque no mês para escolher outro, use as setas para andar, ou '
            'troque para a visão do ano inteiro.',
        hint: 'Experimente trocar o mês.',
      ),
      _TourStep(
        page: 0,
        target: t.stats,
        title: 'Entradas, saídas e saldo',
        body: 'O resumo do período escolhido, em três cartões.',
        hint: 'Arraste para o lado para ver todos.',
      ),
      _TourStep(
        page: 0,
        target: t.bestCard,
        title: 'Melhor cartão para hoje',
        body:
            'Assim que você cadastrar seus cartões, calculamos qual rende '
            'mais prazo pela data de fechamento.',
      ),
      _TourStep(
        page: 0,
        target: t.categories,
        title: 'Para onde vai o dinheiro',
        body: 'Seus gastos do período separados por categoria.',
      ),
      _TourStep(
        page: 0,
        target: t.recent,
        title: 'Movimentações recentes',
        body: 'Os últimos lançamentos, com atalho para a lista completa.',
      ),
      _TourStep(
        page: 0,
        target: t.insight,
        title: 'Sua saúde financeira',
        body: 'Um resumo do que os números do período estão dizendo.',
      ),
      _TourStep(
        page: 1,
        target: t.nav[1],
        radius: AppRadii.md,
        padding: 4,
        title: 'Transações',
        body:
            'A lista completa: entradas, saídas, parcelas e assinaturas, com '
            'busca e filtros.',
      ),
      _TourStep(
        page: 1,
        target: t.createButton,
        radius: AppRadii.pill,
        padding: 6,
        title: 'Criar lançamento',
        body:
            'O + abre o formulário. Se quiser, crie o seu primeiro agora — dá '
            'para fechar sem salvar.',
        hint: 'Toque para testar.',
      ),
      _TourStep(
        page: 2,
        target: t.nav[2],
        radius: AppRadii.md,
        padding: 4,
        title: 'Cartões',
        body:
            'Cadastre limite, fechamento e vencimento de cada cartão e '
            'acompanhe a fatura.',
      ),
      _TourStep(
        page: 2,
        target: t.createButton,
        radius: AppRadii.pill,
        padding: 6,
        title: 'Novo cartão',
        body:
            'O + aqui cadastra um cartão. Se quiser, adicione o seu agora — '
            'dá para fechar sem salvar.',
        hint: 'Toque para testar.',
      ),
      _TourStep(
        page: 3,
        target: t.nav[3],
        radius: AppRadii.md,
        padding: 4,
        title: 'Chat IA',
        body:
            '"Gastei 30 no lanche no crédito" já vira lançamento. A IA mostra '
            'um preview antes de salvar — você aprova, edita ou cancela.',
      ),
      _TourStep(
        page: 4,
        target: t.nav[4],
        radius: AppRadii.md,
        padding: 4,
        title: 'Perfil',
        body: 'Tema, notificações e os dados da sua conta.',
      ),
      const _TourStep(
        page: 0,
        title: 'Pronto, o resto é seu.',
        body: 'Bom controle! Você já pode começar a usar.',
      ),
    ];
  }

  /// Keeps [_hole] on the current target wherever it goes — scrolling,
  /// page swipes, layout changes.
  void _syncHole() {
    if (!mounted || _closing) return;

    final step = _steps[_index];
    final self = context.findRenderObject() as RenderBox?;
    final targetContext = step.target?.currentContext;
    Rect? rect;

    if (self != null && self.hasSize && targetContext != null) {
      final box = targetContext.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        final topLeft = self.globalToLocal(box.localToGlobal(Offset.zero));
        rect = (topLeft & box.size)
            .inflate(step.padding)
            .intersect(Offset.zero & self.size);
        if (rect.isEmpty) rect = null;
      }
    }

    if (rect != _hole) setState(() => _hole = rect);
  }

  /// The rect actually painted this frame: mid-glide it's an interpolation
  /// from where the spotlight was to the live target; otherwise it's the
  /// target's current rect directly, with no easing to lag behind.
  Rect? get _displayedHole {
    if (_glide.isAnimating && _glideFrom != null) {
      return Rect.lerp(
        _glideFrom,
        _hole,
        Curves.easeOutCubic.transform(_glide.value),
      );
    }
    return _hole;
  }

  Future<void> _goTo(int index) async {
    _glideFrom = _displayedHole;
    if (MediaQuery.disableAnimationsOf(context)) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
    }
    setState(() => _index = index);
    final step = _steps[index];
    widget.onGoToPage(step.page);

    // Let the page transition land before asking the list to scroll — the
    // target may not even be built yet on the incoming page.
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted || _closing) return;

    final targetContext = step.target?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      _finish();
      return;
    }
    _goTo(_index + 1);
  }

  void _back() {
    if (_index == 0) return;
    _goTo(_index - 1);
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);

    await markOnboardingTourSeen(widget.userId);
    widget.onGoToPage(0);
    await _entry.reverse();
    if (!mounted) return;
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = _steps;
    final step = steps[_index];
    final isLast = _index == steps.length - 1;
    final accent = isLast ? colorScheme.tertiary : colorScheme.secondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return AnimatedBuilder(
          animation: Listenable.merge([_t, _glide]),
          builder: (context, _) {
            // A step with no target collapses the cutout to a point in the
            // middle of the screen — the scrim then covers everything.
            final hole =
                _displayedHole ??
                Rect.fromCenter(
                  center: size.center(Offset.zero),
                  width: 0,
                  height: 0,
                );
            final lit = hole.width > 4 && hole.height > 4;
            final t = _t.value;
            return Stack(
              children: [
                ..._scrimPieces(hole, size, t),
                if (lit)
                  Positioned.fromRect(
                    key: const Key('onboarding_ring'),
                    rect: hole.inflate(28),
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _SpotlightRingPainter(
                            radius: step.radius,
                            accent: accent,
                            scrim: _scrimColor(t),
                            pulse: _pulse.value,
                            opacity: t,
                          ),
                        ),
                      ),
                    ),
                  ),
                _positionCard(
                  hole: lit ? hole : null,
                  size: size,
                  child: Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 24),
                      child: _TourCard(
                        accent: accent,
                        counter: '${_index + 1} de ${steps.length}',
                        canGoBack: _index > 0,
                        isLast: isLast,
                        onBack: _back,
                        onSkip: _finish,
                        onNext: _next,
                        child: _StepBody(
                          key: ValueKey(_index),
                          step: step,
                          accent: accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _scrimColor(double t) => Colors.black.withValues(alpha: 0.62 * t);

  /// The scrim is four plain rectangles around the cutout rather than one
  /// painted layer with a hole: whatever sits inside the cutout keeps
  /// receiving taps and drags, with no hit-test tricks.
  List<Widget> _scrimPieces(Rect gap, Size size, double t) {
    final color = _scrimColor(t);

    Widget piece(double left, double top, double width, double height) {
      return Positioned(
        left: left,
        top: top,
        width: width.clamp(0.0, size.width),
        height: height.clamp(0.0, size.height),
        // Blocks the app everywhere except the cutout, and swallows the tap
        // instead of advancing — a misplaced tap should never skip a step.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(color: color),
        ),
      );
    }

    return [
      piece(0, 0, size.width, gap.top),
      piece(0, gap.bottom, size.width, size.height - gap.bottom),
      piece(0, gap.top, gap.left, gap.height),
      piece(gap.right, gap.top, size.width - gap.right, gap.height),
    ];
  }

  Widget _positionCard({
    required Rect? hole,
    required Size size,
    required Widget child,
  }) {
    final card = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: size.height * 0.55),
      child: child,
    );

    if (hole == null) {
      return Positioned(
        left: 18,
        right: 18,
        top: 0,
        bottom: 0,
        child: Center(child: card),
      );
    }

    // Sit on whichever side of the highlighted element has more room, so the
    // card never covers what it is pointing at.
    final below = hole.center.dy < size.height * 0.46;
    return Positioned(
      left: 18,
      right: 18,
      top: below ? (hole.bottom + 18).clamp(0.0, size.height) : null,
      bottom: below
          ? null
          : (size.height - hole.top + 18).clamp(0.0, size.height),
      child: card,
    );
  }
}

/// Paints the accent ring around the cutout. Also fills the cutout's square
/// corners with the scrim colour, so the lit area reads as a rounded shape.
class _SpotlightRingPainter extends CustomPainter {
  const _SpotlightRingPainter({
    required this.radius,
    required this.accent,
    required this.scrim,
    required this.pulse,
    required this.opacity,
  });

  final double radius;
  final Color accent;
  final Color scrim;
  final double pulse;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // The painter is laid out inflated by 28px around the cutout so the
    // pulsing ring has room to breathe outside it.
    final inner = (Offset.zero & size).deflate(28);
    if (inner.isEmpty) return;

    final rrect = RRect.fromRectAndRadius(
      inner,
      Radius.circular(radius.clamp(0, inner.shortestSide / 2)),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(inner),
        Path()..addRRect(rrect),
      ),
      Paint()..color = scrim,
    );

    canvas.drawRRect(
      rrect.inflate(6 + 3 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: (0.55 - 0.35 * pulse) * opacity),
    );
    canvas.drawRRect(
      rrect.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = accent.withValues(alpha: 0.95 * opacity),
    );
  }

  @override
  bool shouldRepaint(_SpotlightRingPainter old) =>
      old.radius != radius ||
      old.accent != accent ||
      old.scrim != scrim ||
      old.pulse != pulse ||
      old.opacity != opacity;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.accent,
    required this.counter,
    required this.canGoBack,
    required this.isLast,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.child,
  });

  final Color accent;
  final String counter;
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('onboarding_card'),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: isDark ? 0.97 : 0.99),
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.2),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        // The border lives here rather than in `decoration` above:
        // Container derives implicit child padding from a border on
        // `decoration` (border.dimensions), which insets the child by 1px
        // on every side. `foregroundDecoration` paints over the child
        // instead, with no effect on layout.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: SingleChildScrollView(child: child)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (canGoBack)
                          IconButton(
                            onPressed: onBack,
                            tooltip: 'Voltar',
                            visualDensity: VisualDensity.compact,
                            color: colorScheme.onSurfaceVariant,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Pular'),
                        ),
                        const Spacer(),
                        Text(
                          counter,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(isLast ? 'Começar' : 'Continuar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({super.key, required this.step, required this.accent});

  final _TourStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          step.body,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.42,
          ),
        ),
        if (step.hint != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.hint!,
                  style: textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
