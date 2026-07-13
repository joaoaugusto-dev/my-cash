import 'package:flutter/material.dart';

import '../../core/widgets/header_icon_button.dart';
import '../../core/widgets/picker_sheet_wrapper.dart';

class MonthPickerSheet extends StatelessWidget {
  const MonthPickerSheet({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    required this.onChanged,
    required this.onConfirm,
  });

  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return PickerSheetWrapper(
      child: _MonthWheel(
        initialYear: initialYear,
        initialMonth: initialMonth,
        onChanged: onChanged,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _MonthWheel extends StatefulWidget {
  const _MonthWheel({
    required this.initialYear,
    required this.initialMonth,
    required this.onChanged,
    required this.onConfirm,
  });

  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onChanged;
  final VoidCallback onConfirm;

  @override
  State<_MonthWheel> createState() => _MonthWheelState();
}

class _MonthWheelState extends State<_MonthWheel> {
  late int _year;
  late int _selectedMonth;
  late FixedExtentScrollController _scrollController;

  static const _months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _scrollController = FixedExtentScrollController(
      initialItem: widget.initialMonth - 1,
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Escolha o mês',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  setState(() => _year--);
                  widget.onChanged(_year, _selectedMonth);
                },
              ),
              const SizedBox(width: 8),
              Text(
                '$_year',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              HeaderIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  setState(() => _year++);
                  widget.onChanged(_year, _selectedMonth);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: ListWheelScrollView(
              controller: _scrollController,
              itemExtent: 52,
              diameterRatio: 1.3,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() => _selectedMonth = index + 1);
                widget.onChanged(_year, _selectedMonth);
              },
              children: List.generate(12, (index) {
                final month = index + 1;
                final isSelected = month == _selectedMonth;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _months[index],
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: isSelected ? 22 : 17,
                      ),
                    ),
                  ),
                );
              }),
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
                'Selecionar ${_months[_selectedMonth - 1]} de $_year',
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
