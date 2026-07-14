import 'package:flutter/material.dart';

import 'package:my_cash/src/ui/core/theme/app_theme.dart';

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xs),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, color: colorScheme.onSurface, size: 22),
        ),
      ),
    );
  }
}
