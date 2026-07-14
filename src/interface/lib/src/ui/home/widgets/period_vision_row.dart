import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/spring_curve.dart';

class PeriodAndVisionRow extends StatelessWidget {
  const PeriodAndVisionRow({
    super.key,
    required this.label,
    required this.isYearly,
    required this.onToggleVision,
    required this.onPrevious,
    required this.onNext,
    required this.onTapPeriod,
    this.showTodayButton = false,
    this.onTapToday,
  });

  final String label;
  final bool isYearly;
  final VoidCallback onToggleVision;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTapPeriod;

  /// Shows a "Voltar para hoje" button once the user has strayed from the
  /// current period — otherwise it's easy to get lost after a few taps.
  final bool showTodayButton;
  final VoidCallback? onTapToday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final periodSelector = _PeriodSelector(
          label: label,
          isYearly: isYearly,
          onPrevious: onPrevious,
          onNext: onNext,
          onTap: onTapPeriod,
        );
        final visionToggle = _VisionToggle(
          isYearly: isYearly,
          onChanged: onToggleVision,
        );

        final row = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  periodSelector,
                  const SizedBox(height: 12),
                  visionToggle,
                ],
              )
            : Row(
                children: [
                  Expanded(child: periodSelector),
                  const SizedBox(width: 14),
                  SizedBox(width: 240, child: visionToggle),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: showTodayButton
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: isNarrow
                          ? _TodayButton(onTap: onTapToday, expand: true)
                          : Align(
                              alignment: Alignment.centerRight,
                              child: _TodayButton(onTap: onTapToday),
                            ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap, this.expand = false});

  final VoidCallback? onTap;

  /// Stretches to the full width of the row above (mobile), instead of
  /// wrapping tight and floating to the right (wide layouts).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.replay_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Voltar para o período atual',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatefulWidget {
  const _PeriodSelector({
    required this.label,
    required this.isYearly,
    required this.onPrevious,
    required this.onNext,
    this.onTap,
  });

  final String label;
  final bool isYearly;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  @override
  State<_PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<_PeriodSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  String _previousLabel = '';

  @override
  void initState() {
    super.initState();
    _previousLabel = widget.label;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(_PeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _previousLabel = oldWidget.label;
      _flipController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF8B2CEB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B21B6).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(AppRadii.lg)),
              onTap: widget.onPrevious,
              child: SizedBox(
                width: 52,
                height: 60,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final isFirstHalf = _flipAnimation.value < 0.5;
                    final progress = _flipAnimation.value;
                    final scaleY = isFirstHalf
                        ? 1.0 - progress * 2.0
                        : (progress - 0.5) * 2.0;
                    final opacity = isFirstHalf
                        ? 1.0 - progress * 2.0
                        : (progress - 0.5) * 2.0;
                    final clampedScale = scaleY.clamp(0.0, 1.0);
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1.0, clampedScale, 1.0)
                        ..setEntry(3, 2, 0.001),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: _buildContent(
                          isFirstHalf ? _previousLabel : widget.label,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadii.lg)),
              onTap: widget.onNext,
              child: SizedBox(
                width: 52,
                height: 60,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String currentLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return RotationTransition(turns: animation, child: child);
          },
          child: Icon(
            widget.isYearly
                ? Icons.event_note_rounded
                : Icons.calendar_month_rounded,
            key: ValueKey('icon-${widget.isYearly}'),
            color: Colors.white.withValues(alpha: 0.9),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            currentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisionToggle extends StatefulWidget {
  const _VisionToggle({required this.isYearly, required this.onChanged});

  final bool isYearly;
  final VoidCallback onChanged;

  @override
  State<_VisionToggle> createState() => _VisionToggleState();
}

class _VisionToggleState extends State<_VisionToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _springAnimation = CurvedAnimation(
      parent: _springController,
      curve: const SpringCurve(),
    );
  }

  @override
  void didUpdateWidget(_VisionToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isYearly != widget.isYearly) {
      _springController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onChanged,
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.55),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pillWidth = (constraints.maxWidth - 0) / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  left: widget.isYearly ? pillWidth : 0,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF7C3AED).withValues(alpha: 0.6),
                                const Color(0xFF6D28D9).withValues(alpha: 0.6),
                              ]
                            : [
                                const Color(0xFF6D28D9),
                                const Color(0xFF8B2CEB),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF5B21B6,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleLabel(
                        isActive: !widget.isYearly,
                        label: 'Mensal',
                        springValue: widget.isYearly
                            ? _springAnimation.value
                            : 1.0 - _springAnimation.value * 0.5,
                      ),
                    ),
                    Expanded(
                      child: _ToggleLabel(
                        isActive: widget.isYearly,
                        label: 'Anual',
                        springValue: widget.isYearly
                            ? 1.0 - _springAnimation.value * 0.5
                            : _springAnimation.value,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel({
    required this.isActive,
    required this.label,
    this.springValue = 0.0,
  });

  final bool isActive;
  final String label;
  final double springValue;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      alignment: Alignment.center,
      child: Transform.scale(
        scale: 1.0 + springValue * 0.08,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: isActive
                ? Colors.white
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.56),
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
