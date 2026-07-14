import 'package:flutter/material.dart';

import 'package:my_cash/src/ui/core/theme/app_theme.dart';

class FloatingCreateButton extends StatelessWidget {
  const FloatingCreateButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Novo lançamento',
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B2CEB), Color(0xFF4C1D95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C1D95).withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}

class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.pageController,
    required this.selectedIndex,
    required this.onSelected,
  });

  final PageController pageController;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isVeryNarrow = width < 370;
    final barHeight = isVeryNarrow ? 72.0 : 78.0;
    final horizontalPadding = isVeryNarrow ? 5.0 : 8.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RepaintBoundary(
          child: Container(
            height: barHeight,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              5,
              horizontalPadding,
              5,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.92 : 0.94,
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(
                color: colorScheme.outline.withValues(
                  alpha: isDark ? 0.42 : 0.62,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.09),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: pageController,
              builder: (context, _) {
                final page = pageController.hasClients
                    ? pageController.page ?? selectedIndex.toDouble()
                    : selectedIndex.toDouble();

                return SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment(-1.0 + (page * 0.5), 0),
                          child: FractionallySizedBox(
                            widthFactor: 1 / 5,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                              ),
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: isVeryNarrow ? 30 : 36,
                                height: 3,
                                margin: EdgeInsets.only(
                                  top: isVeryNarrow ? 3 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _BottomNavItem(
                            index: 0,
                            selectedIndex: selectedIndex,
                            icon: Icons.home_rounded,
                            label: 'Início',
                            compactLabel: 'Início',
                            dense: isVeryNarrow,
                            onSelected: onSelected,
                          ),
                          _BottomNavItem(
                            index: 1,
                            selectedIndex: selectedIndex,
                            icon: Icons.list_alt_rounded,
                            label: 'Transações',
                            compactLabel: 'Trans.',
                            dense: isVeryNarrow,
                            onSelected: onSelected,
                          ),
                          _BottomNavItem(
                            index: 2,
                            selectedIndex: selectedIndex,
                            icon: Icons.credit_card_rounded,
                            label: 'Cartões',
                            compactLabel: 'Cards',
                            dense: isVeryNarrow,
                            onSelected: onSelected,
                          ),
                          _BottomNavItem(
                            index: 3,
                            selectedIndex: selectedIndex,
                            icon: Icons.auto_awesome_rounded,
                            label: 'Chat IA',
                            compactLabel: 'IA',
                            dense: isVeryNarrow,
                            onSelected: onSelected,
                          ),
                          _BottomNavItem(
                            index: 4,
                            selectedIndex: selectedIndex,
                            icon: Icons.person_outline_rounded,
                            label: 'Perfil',
                            compactLabel: 'Perfil',
                            dense: isVeryNarrow,
                            onSelected: onSelected,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.compactLabel,
    required this.dense,
    required this.onSelected,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final String compactLabel;
  final bool dense;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = index == selectedIndex;
    final itemLabel = dense ? compactLabel : label;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => onSelected(index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: dense ? 4 : 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: dense ? 8 : 9),
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.55),
                size: dense ? 23 : 25,
              ),
              SizedBox(height: dense ? 2 : 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    itemLabel,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.62),
                      fontSize: dense ? 10 : 11,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
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
