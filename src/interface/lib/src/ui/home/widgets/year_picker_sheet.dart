import 'package:flutter/material.dart';

import '../../core/widgets/picker_sheet_wrapper.dart';
import '../../core/widgets/wheel_number_picker_grid.dart';

class YearPickerSheet extends StatelessWidget {
  const YearPickerSheet({
    super.key,
    required this.selectedYear,
    required this.onChanged,
    required this.onConfirm,
  });

  final int selectedYear;
  final void Function(int year) onChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return PickerSheetWrapper(
      child: WheelNumberPickerGrid(
        title: 'Escolha o ano',
        values: List.generate(101, (index) => 2000 + index),
        selectedValue: selectedYear,
        confirmLabel: (year) => 'Selecionar $year',
        onChanged: onChanged,
        onConfirm: onConfirm,
      ),
    );
  }
}
