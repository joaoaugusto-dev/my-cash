import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared building blocks for the app's bottom-sheet "composer" forms
/// (new transaction, new card, ...), kept in one place so every composer
/// looks and behaves the same way.

class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    required this.icon,
    this.leading,
  });

  final T value;
  final String label;
  final IconData icon;
  final Widget? leading;
}

Future<SheetOption<T>?> showComposerOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<SheetOption<T>> options,
  required T? selectedValue,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<SheetOption<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(
                  alpha: isDark ? 0.92 : 0.9,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final option = options[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              leading:
                                  option.leading ??
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      option.icon,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                              title: Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              trailing: option.value == selectedValue
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(option),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ComposerPanel extends StatelessWidget {
  const ComposerPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}

class ComposerSelectorField extends StatelessWidget {
  const ComposerSelectorField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.trailingIcon = Icons.keyboard_arrow_down_rounded,
    this.validator,
    this.iconWidget,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  /// Overrides [icon] with a custom widget (e.g. a selected brand's logo).
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      maxLines: 1,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: iconWidget ?? Icon(icon, color: colorScheme.primary),
        suffixIcon: Icon(trailingIcon),
      ),
    );
  }
}

class ComposerSwitchTile extends StatelessWidget {
  const ComposerSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor ?? colorScheme.tertiary,
          activeTrackColor: (activeColor ?? colorScheme.tertiary).withValues(
            alpha: 0.45,
          ),
        ),
      ],
    );
  }
}

class ComposerCloseButton extends StatelessWidget {
  const ComposerCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Fechar',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(Icons.close_rounded, color: colorScheme.primary),
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final value = int.parse(digits);
    final cents = (value % 100).toString().padLeft(2, '0');
    final whole = (value ~/ 100).toString();
    final groups = <String>[];
    for (var i = whole.length; i > 0; i -= 3) {
      final start = math.max(0, i - 3);
      groups.insert(0, whole.substring(start, i));
    }
    final formatted = '${groups.join('.')},$cents';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Common chrome for bottom-sheet forms: blurred rounded sheet, drag handle,
/// title/subtitle header with a close button, and a scrollable [Form] body.
class ComposerSheetShell extends StatefulWidget {
  const ComposerSheetShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.formKey,
    required this.children,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  State<ComposerSheetShell> createState() => _ComposerSheetShellState();
}

class _ComposerSheetShellState extends State<ComposerSheetShell> {
  // The handle/header sit outside the scrollable body specifically so a
  // downward drag never gets swallowed by the Form's SingleChildScrollView
  // (the scroll view claims vertical drags before the sheet's own
  // drag-to-dismiss can see them).
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.86 : 0.82,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) =>
                        _dragDistance += details.delta.dy,
                    onVerticalDragEnd: (details) {
                      final shouldClose =
                          _dragDistance > 40 ||
                          (details.primaryVelocity ?? 0) > 300;
                      _dragDistance = 0;
                      if (shouldClose) widget.onClose();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.subtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.62),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              ComposerCloseButton(onPressed: widget.onClose),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                      child: Form(
                        key: widget.formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: widget.children,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses a value typed with [CurrencyInputFormatter] back into a double (in reais).
double parseCurrencyInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return 0;
  }
  return int.parse(digits) / 100;
}
