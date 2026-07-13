import 'package:flutter/material.dart';

/// Shared wheel-scroll number picker (used for the year and installments
/// selectors) so every "pick a number" sheet in the app looks and behaves
/// the same way.
class WheelNumberPickerGrid extends StatefulWidget {
  const WheelNumberPickerGrid({
    super.key,
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.confirmLabel,
    required this.onChanged,
    required this.onConfirm,
  });

  final String title;
  final List<int> values;
  final int selectedValue;
  final String Function(int value) confirmLabel;
  final void Function(int value) onChanged;
  final VoidCallback onConfirm;

  @override
  State<WheelNumberPickerGrid> createState() => _WheelNumberPickerGridState();
}

class _WheelNumberPickerGridState extends State<WheelNumberPickerGrid> {
  late int _selectedValue;
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedValue;
    final initialIndex = widget.values.indexOf(widget.selectedValue);
    _scrollController = FixedExtentScrollController(
      initialItem: initialIndex.clamp(0, widget.values.length - 1),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: ListWheelScrollView(
              controller: _scrollController,
              itemExtent: 48,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                final value = widget.values[index];
                setState(() => _selectedValue = value);
                widget.onChanged(value);
              },
              children: [
                for (final value in widget.values)
                  Center(
                    child: Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: value == _selectedValue
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: value == _selectedValue
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: value == _selectedValue ? 24 : 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: widget.onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.confirmLabel(_selectedValue),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
