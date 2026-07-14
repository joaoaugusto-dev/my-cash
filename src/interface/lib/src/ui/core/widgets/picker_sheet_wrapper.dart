import 'package:flutter/material.dart';

import 'package:my_cash/src/ui/core/theme/app_theme.dart';

class PickerSheetWrapper extends StatelessWidget {
  const PickerSheetWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.96 : 0.98),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xxl),
        ),
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
